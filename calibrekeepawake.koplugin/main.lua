--[[--
Calibre keep awake

Keeps the device awake only while the calibre wireless connection is active,
and restores the previous behavior as soon as the connection ends.
It wraps three CalibreWireless methods from the stock calibre plugin:

  * initCalibreMQ  -> the socket is being opened: keep awake
  * disconnect     -> the socket was closed: restore
  * connect        -> when the whole connect routine ends (failure, cancel,
                      timeout) and no socket is left: restore as well

Per platform:

  * Android: android.timeout.set(-1) (same mechanism as KOReader's own
    "screen timeout" setting); the previous timeout is restored afterwards.
  * Kindle:  the same approach as KOReader's built-in "Keep alive" plugin:
    `lipc-set-prop com.lab126.powerd preventScreenSaver 1`, plus
    PluginShare.keepalive / pause_auto_suspend so KOReader's AutoSuspend
    neither suspends the device nor fights powerd. The previous values are
    restored afterwards and AutoSuspend's Kindle timer is restarted.
  * Others (Kobo, etc.): PluginShare.pause_auto_suspend + preventStandby.

Nothing else in KOReader is changed.
--]]--

local Device = require("device")
local PluginShare = require("pluginshare")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local logger = require("logger")

local KEEP_SCREEN_ON = -1 -- C.AKEEP_SCREEN_ON_ENABLED

-- Module-level state, shared by every plugin instance (FileManager/Reader).
local state = {
    patched = false,
    active = false,
    ui = nil,          -- latest FileManager/ReaderUI, to reach AutoSuspend
    saved = {},        -- whatever we changed, to put it back
}

local function getAndroid()
    if not Device:isAndroid() then return nil end
    local ok, android = pcall(require, "android")
    if ok and android and android.timeout then
        return android
    end
    return nil
end

local function kindleGetPreventScreenSaver()
    local f = io.popen("lipc-get-prop -i com.lab126.powerd preventScreenSaver 2>/dev/null")
    if not f then return nil end
    local out = f:read("*a")
    f:close()
    return tonumber(out and out:match("%-?%d+"))
end

local function kindleSetPreventScreenSaver(value)
    os.execute("lipc-set-prop com.lab126.powerd preventScreenSaver " .. tostring(value))
end

local function restartKindleAutoSuspendTimer()
    local autosuspend = state.ui and state.ui.autosuspend
    if autosuspend and autosuspend._unschedule_kindle and autosuspend._start_kindle then
        pcall(function()
            autosuspend:_unschedule_kindle()
            autosuspend:_start_kindle()
        end)
    end
end

local function keepAwake()
    if state.active then return end
    state.active = true
    local saved = {}
    state.saved = saved

    local android = getAndroid()
    if android then
        saved.android_timeout = android.timeout.get()
        android.timeout.set(KEEP_SCREEN_ON)
        logger.info("calibrekeepawake: screen kept on (previous timeout:", saved.android_timeout, ")")
        return
    end

    saved.pause_auto_suspend = PluginShare.pause_auto_suspend
    PluginShare.pause_auto_suspend = true

    if Device:isKindle() then
        saved.keepalive = PluginShare.keepalive
        saved.prevent_screensaver = kindleGetPreventScreenSaver()
        PluginShare.keepalive = true
        kindleSetPreventScreenSaver(1)
        logger.info("calibrekeepawake: kindle screensaver prevented (previous:", saved.prevent_screensaver, ")")
    end

    UIManager:preventStandby()
    saved.standby_prevented = true
    logger.info("calibrekeepawake: auto suspend paused, standby prevented")
end

local function restore()
    if not state.active then return end
    state.active = false
    local saved = state.saved or {}
    state.saved = {}

    local android = getAndroid()
    if android then
        local timeout = saved.android_timeout or 0 -- 0 = system default
        android.timeout.set(timeout)
        logger.info("calibrekeepawake: screen timeout restored to", timeout)
        return
    end

    if saved.standby_prevented then
        UIManager:allowStandby()
    end
    PluginShare.pause_auto_suspend = saved.pause_auto_suspend

    if Device:isKindle() then
        PluginShare.keepalive = saved.keepalive
        local value = saved.prevent_screensaver
        if value == nil then
            value = PluginShare.keepalive and 1 or 0
        end
        kindleSetPreventScreenSaver(value)
        restartKindleAutoSuspendTimer()
        logger.info("calibrekeepawake: kindle screensaver prevention restored to", value)
    end
    logger.info("calibrekeepawake: auto suspend / standby restored")
end

local function patchCalibreWireless()
    if state.patched then return true end

    local CW = package.loaded["wireless"]
    if not CW then
        local ok, mod = pcall(require, "wireless")
        if ok then CW = mod end
    end
    if type(CW) ~= "table" or type(CW.initCalibreMQ) ~= "function"
        or type(CW.disconnect) ~= "function" or type(CW.connect) ~= "function" then
        logger.warn("calibrekeepawake: calibre plugin not found, nothing patched")
        return false
    end

    local orig_init = CW.initCalibreMQ
    CW.initCalibreMQ = function(self, ...)
        keepAwake()
        return orig_init(self, ...)
    end

    local orig_disconnect = CW.disconnect
    CW.disconnect = function(self, ...)
        local ok, err = pcall(orig_disconnect, self, ...)
        if self.calibre_socket == nil then
            restore()
        end
        if not ok then error(err, 0) end
    end

    local orig_connect = CW.connect
    CW.connect = function(self, ...)
        orig_connect(self, ...)
        -- connect() returns either immediately (already connected / it
        -- re-wrapped itself in a coroutine) or when the session is over.
        -- Only restore if there is no live socket.
        if self.calibre_socket == nil then
            restore()
        end
    end

    state.patched = true
    logger.info("calibrekeepawake: calibre wireless patched")
    return true
end

local CalibreKeepAwake = WidgetContainer:extend{
    name = "calibrekeepawake",
    is_doc_only = false,
}

function CalibreKeepAwake:init()
    state.ui = self.ui
    -- Run after all plugins (including calibre) are initialized.
    UIManager:nextTick(patchCalibreWireless)
end

-- Safety net: never leave the device forced awake when KOReader exits.
function CalibreKeepAwake:onExit()
    restore()
end

return CalibreKeepAwake
