# STM32 ↔ Android protocol
HC-05 Classic Bluetooth RFCOMM UUID: 00001101-0000-1000-8000-00805F9B34FB.
Pair in Android system settings before choosing a bonded device in the app.
ASCII, newline-delimited, optional CR before LF. Maximum incoming line: 128 characters.
The native reader handles split and coalesced packets. Writes are serialized.

| Direction | Line (without LF) | Meaning |
|---|---|---|
| Android→STM32 | VIBRATE_ON | Continuous vibration |
| Android→STM32 | VIBRATE_OFF | Stop vibration |
| Android→STM32 | VIBRATE_PATTERN:1 | Single pulse |
| Android→STM32 | VIBRATE_PATTERN:2 | Double pulse |
| Android→STM32 | VIBRATE_PATTERN:3 | Triple pulse |
| Android→STM32 | raw byte `S` | Strong/continuous critical alert; no newline |
| Android→STM32 | raw byte `W` | Pulsed proximity warning; no newline |
| Android→STM32 | raw byte `C` | Clear/stop vibration; no newline |
| Android→STM32 | PING | Heartbeat every 5 seconds |
| STM32→Android | PONG | Reply to every PING |
| STM32→Android | DIST:35 | Distance in cm; invalid/zero/NaN rejected |
| STM32→Android | BATT:75 | Battery percentage 0–100 |

Heartbeats time out after 15 seconds without PONG (three periods).
Reconnection starts at 1 second and backs off to 30 seconds; connect timeout 12 s.
Test duplicate reconnect scheduling and connect/disconnect races on hardware before deployment.
Firmware must explicitly accept raw `S`, `W`, and `C` bytes alongside
newline-delimited commands; the app does not append LF to these haptic commands.
Suggested sensor emission 10–20 Hz. Do not encode 'no echo' as zero distance.
Pattern 3 has no direction bits: voice carries direction. Intensity has no wire command
in the supplied protocol; the UI preference cannot change firmware intensity yet.

## Firmware safety contract (not implemented in this app scaffold)
Use a motor driver, not a motor attached directly to an MCU GPIO. Handle HC-SR04
5 V echo safely with appropriate level shifting for the STM32 input. Have a qualified
hardware reviewer verify wiring. For a true immediate <40 cm override, implement the
threshold locally in STM32; the Android round trip and Bluetooth scheduling are not deterministic.
Specify a disconnect watchdog and a user-recognizable fault pattern in firmware.
