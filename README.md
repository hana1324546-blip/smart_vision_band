# Smart Vision Band — Flutter/Android development scaffold

**Status: source scaffold, not a completed or validated assistive device.**
The project includes real application structure and selected implementations, but
hardware integration and release validation are unfinished. Do not rely on it to
navigate or replace a cane, guide dog or professional mobility instruction.

## Included
- Flutter/Dart Material 3 dark, high-contrast UI with six screens reachable from a
  labelled drawer; large primary controls and a live-region hazard heading.
- Riverpod controller; deterministic fusion function; timestamp freshness checks;
  ultrasonic-only decisions even when vision is absent; emergency voice/phone vibration.
- Native Classic Bluetooth SPP: bonded devices, async RFCOMM, line framing, TX
  serialization, heartbeat, backoff reconnect, rolling Dart debug buffer, saved MAC.
- Native platform channel registration for camera/Bluetooth/audio/service.
- CPU TFLite detector with explicit input/output validation, RGB letterbox,
  normalization, raw-head decoding and class-aware NMS. Not tested against a model.
- flutter_tts English (US), identical-message 800 ms cooldown and urgent stop/speak.
- sqflite events/sessions schema, event logging on decision changes, age/count
  retention, recent-event dashboard and CSV share. Sessions are schema-only for now.
- Synthetic Demo Mode cycles 450/300/150/35 cm every four seconds. **No hardware
  haptic commands are sent in demo mode.** Spoken alerts are real; FPS remains zero.
- Gradle KTS, minSdk 26, targetSdk 34, compileSdk 35, release minification and optional
  release-signing configuration; unit-test sources; hardware integration documents.

## Explicitly incomplete
- No best_float32.tflite: supply your trained 15-class model. No empty fake binary.
- UVCAndroid adapter is not implemented or dependency-pinned. Camera start returns
  `UVC_ADAPTER_REQUIRED`, not a false success. Native preview is also not included.
- No verified signed APK, runtime screenshots, 30-second demo video or benchmark data.
- No GPU delegate, adaptive resolution, motion-driven FPS throttling or real firmware
  intensity control. Battery-saver and intensity controls are preferences only.
- Audio status detects an available Bluetooth output, **not proof of active TTS
  routing**. Select earbuds in Android's media output selector. Media A2DP routing
  is controlled by the OS; forcing SCO is not an appropriate blanket solution for
  media TTS. The UI wording is provisional and must be corrected after route verification.
- Foreground service is notification/wakelock scaffolding, not a service-owned engine.
  Screen-off continuity, notification-tap stop, ultrasonic-only UI start mode and
  reconnect races still require implementation and validation.
- Sessions, 20 MB physical DB cap, persistent preferences other than saved MAC,
  Firebase sync and complete accessibility audits are pending. Firebase is absent
  and OFF; there is no INTERNET permission in the app manifest.
- Package versions are starting constraints, not a tested compatibility matrix.
  No lockfile is fabricated. Resolve and commit a lockfile after successful testing.

## Build setup
Use a Flutter 3.x stable toolchain with Dart >=3.4, JDK 17 and an Android SDK with
platform 35. The exact SDK/plugin combination is unverified. The app keeps targetSdk
34 as requested; assess current store submission requirements separately.

```bash
bash scripts/bootstrap.sh
flutter analyze
flutter test
flutter build apk --debug
```
The bootstrap script copies only platform-generated Gradle launchers/wrapper JAR and
local SDK paths from a temporary Flutter project. It preserves this project's source
and Gradle configuration. It requires network access for initial dependency setup;
**offline runtime after installation is a separate requirement**. If your Flutter
version cannot use the included AGP/Kotlin versions, update the toolchain deliberately
and record tested versions rather than blindly overwriting the host project.

For a physical-device simulated walkthrough: open Debug Console, turn Demo Mode ON,
open Device Hub, tap Start Navigation. Use STOP to stop. No camera/model is needed
for synthetic mode. Do not interpret synthetic timing as measured performance.

## Add your model
1. Copy the real model to `android/app/src/main/assets/best_float32.tflite`.
2. Replace `labels.txt` in that directory with **the exact training class order**.
   The supplied 15 names follow the brief, not verified training metadata.
3. Confirm FP32 `[1,640,640,3]` input and raw `[1,19,N]` or `[1,N,19]` output with
   pixel-space xywh. Quantized, normalized-coordinate or NMS-embedded models need
   decoder changes. Verify with golden image/output tests before enabling real mode.
4. Implement and install CameraAdapter using a verified UVCAndroid dependency.
5. Follow `docs/CAMERA.md`, then rebuild with `flutter build apk --debug`.

## Signed release
Create and securely retain your own keystore. Never upload private signing keys here.
Copy `android/key.properties.example` to `android/key.properties`, set local values,
then run `flutter build apk --release`. The build script only attaches a production
signing config when these properties exist. A scaffold or unsigned build is not the
signed deliverable requested in the original brief.

## Fusion specification resolutions
The brief says 'no detection → SAFE' but also requires an ultrasonic-only hard override.
This scaffold chooses a more conservative, explicit precedence:
1. Fresh distance <100 cm → DANGER regardless of vision (covers <40 and <50 overrides).
2. Fresh curb/stairs → SPECIAL unless DANGER already applies; voice supplies direction.
3. 100–<200 cm → WARNING; 200–400 cm inclusive → CAUTION; >400 cm → SAFE.
4. Missing/stale distance → UNKNOWN with a fault double-pulse, **not SAFE**.
Vision expires after 1 second, ultrasonic after 1.5 seconds. These are development
assumptions requiring tuning. The ultrasonic range is one beam, not a depth estimate
for every detection. Bounding boxes do not provide calibrated object distances.
There is no hysteresis yet. Pattern repeats use 1.5 seconds; voices play on transitions
with the TTS identical-message minimum cooldown. A local STM32 hard override is needed
for deterministic immediate feedback; no Android latency guarantee is claimed.

## Project map
- `lib/app.dart`: six-screen UI (feature directories are reserved for later extraction).
- `lib/providers/`: application controller; `lib/models/`: wire/domain models.
- `lib/services/`: fusion, channels, speech, SQLite.
- `android/app/src/main/kotlin/com/smartvisionband/`: native modules.
- `docs/CHANNELS.md`, `docs/PROTOCOL.md`: channel names and line protocol.
- `docs/CAMERA.md`: UVC integration and supported model contract.
- `docs/VALIDATION.md`: checks performed, missing acceptance tests and release gates.
- `test/`, `android/app/src/test/`: test source; not executed in generation environment.

## Known safety/engineering limits
Dart fusion currently shares scheduling with speech and database work; a long await
can delay subsequent ticks and overrides. Before live use, separate highest-priority
haptic actuation from logging/TTS, add monotonic timing and cancellation, and implement
firmware-local override/watchdog. Stop/disconnect and reconnect lifecycle races need
stress tests. No firmware source is supplied. No health, safety or accessibility
certification is claimed. Review this scaffold as development code, not a finished product.
