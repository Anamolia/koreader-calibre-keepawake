# Calibre Keep Awake: a KOReader plugin

Keeps your e-reader or tablet awake **only while KOReader is connected to the calibre wireless server**. When the connection ends, the device goes back to KOReader's normal sleep behavior.

It fixes a common problem with large wireless transfers from calibre: the device dozes off in the middle of the transfer, Wi-Fi goes down and calibre loses the connection.

## ✅ Tested devices

| Device | OS / firmware | KOReader | Stays awake while connected | Back to normal after disconnect |
|---|---|---|---|---|
| **Amazon Kindle Colorsoft** | Kindle firmware (jailbroken) | v2026.07.2 | ✅ Verified | ✅ Verified |
| **Samsung Galaxy Tab S10 FE** (SM-X520) | Android 16 | v2026.07.1 | ✅ Verified | ✅ Verified |

*"Verified" means the device log and system state were checked during a real calibre wireless session in November 2026.*

Other Kindles and Android devices running a recent KOReader should behave the same way, because the plugin uses the same mechanisms on every model. Kobo and other platforms have a generic fallback that has **not** been tested.

## What it does

The plugin hooks into the start and end of the calibre connection in KOReader's built-in calibre plugin. It does not change calibre's code or any other part of KOReader.

| Platform | While connected to calibre | After disconnecting |
|---|---|---|
| **Android** | Keeps the screen on (`android.timeout.set(-1)`), the same mechanism as KOReader's own *Screen timeout* setting | Puts back the screen timeout that was active before |
| **Kindle** | Blocks the Kindle screensaver (`lipc-set-prop com.lab126.powerd preventScreenSaver 1`), the same command as KOReader's built-in *Keep alive* plugin, and pauses KOReader's auto suspend | Puts back the previous screensaver value and auto suspend setting, and restarts the auto suspend timer |
| **Others** (Kobo, etc. — untested) | Pauses KOReader's auto suspend and prevents standby | Restores both |

- **When the connection ends:** settings come back whether you disconnect, calibre closes the connection, the connection times out or it fails to start.
- **If you already use *Keep alive*:** it stays on after you disconnect from calibre.
- **If KOReader exits during a connection:** the plugin restores everything first.
- **If a future KOReader update changes the calibre plugin:** this plugin does nothing and writes a warning to the log. It never crashes KOReader.

## Installation

1. Download this repository (**Code → Download ZIP**) or clone it.
2. Copy the `calibrekeepawake.koplugin` folder into KOReader's `plugins` folder:
   - **Android:** `/sdcard/koreader/plugins/`
   - **Kindle:** `/mnt/us/koreader/plugins/` (the `koreader/plugins` folder over USB or MTP)
3. Restart KOReader.

You will see **Calibre keep awake** under *Tools → More tools → Plugin management*. There is nothing to configure: connect to calibre as usual.

To confirm it loaded, look for this line in the log (`crash.log` on Kindle, `adb logcat` on Android):

```
calibrekeepawake: calibre wireless patched
```

## Português

Plugin para o KOReader que mantém o aparelho acordado **somente enquanto ele está conectado ao calibre sem fio**. Ao desconectar, volta o comportamento normal de descanso. Testado no **Kindle Colorsoft** (KOReader v2026.07.2): fica acordado durante a conexão e volta ao normal ao desconectar, as duas coisas verificadas. Também testado no **Samsung Galaxy Tab S10 FE** (Android 16, KOReader v2026.07.1), com os mesmos resultados. Para instalar, copie a pasta `calibrekeepawake.koplugin` para `koreader/plugins/` e reinicie o KOReader.

## License

[AGPL-3.0](LICENSE), the same license as KOReader.
