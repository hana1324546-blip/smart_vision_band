# Validation record and release gates
## Current validation status
- Editor diagnostics report no errors in the changed Kotlin and Dart files.
- Flutter tests could not run because `flutter` and `dart` are not installed.
- Android compilation could not start because neither `android/local.properties` nor
   `FLUTTER_ROOT` is configured, and this checkout has no Gradle wrapper script.
- `yolov8n.tflite` was exported from the standard COCO checkpoint. Tensor inspection
   confirmed FP32 input `[1,640,640,3]` and FP32 raw output `[1,84,8400]`; custom
   obstacle classes and on-device inference are not validated.
- No phone, ESP32-CAM, HC-05, or STM32 hardware was available for end-to-end checks.

These are static diagnostics only, not compilation or runtime validation. No APK or
measured performance/latency result is available.

## Required before calling this functional
1. Bootstrap wrapper, resolve packages, lock versions, run `flutter analyze` and
   `flutter test`; correct any toolchain/API problems before development proceeds.
2. Build debug APK on a physical Android 8+ and Android 14+ phone; test runtime grants
   and denial, TalkBack, font scaling, microphone recognition, and simultaneous A2DP/SPP.
3. Add a verified compatible model; validate its input/output tensors, class order,
   letterbox inversion, output decoding, and NMS against known labelled frames.
4. Build an instrumented end-to-end harness: inject fragmented `DIST`/`BATT` lines at
   the native byte stream and assert distances below 30 cm produce raw `S`, 30–60 cm
   produce raw `W`, and above 60 cm produce raw `C`, each without a newline.
5. Test 29/30/60/61 cm boundaries, invalid/out-of-range and stale data, fragmented MJPEG,
   covered camera, loss/replug, heartbeat misses, reconnect cancellation, confidence
   thresholds, telemetry freshness, Arabic command recognition, snapshot inference,
   voice interruption, and haptic cooldown.
6. Verify offline Arabic and English TTS voices and Arabic speech-recognition availability.
   Airplane mode disables Bluetooth on many
   phones: re-enable Bluetooth while keeping Wi-Fi/mobile data off, then test.
7. Verify the retained FlutterEngine and sticky foreground-service recovery on devices.
   Test screen-off, Activity recreation, service/process restart, Doze, battery
   optimization, rotation, and explicit navigation stop. Android may still terminate
   a process under severe resource pressure; do not treat a foreground service as an
   absolute process-survival guarantee.
8. Add DB byte-budget enforcement (20 MB including journals), maintenance/VACUUM,
   session start/end/counters, settings persistence, monotonic timestamp alignment,
   priority scheduling, alert cooldown/repetition policy, export privacy controls.
9. Measure frame→firmware vibration with synchronized instrumentation over ≥20 trials.
   Report median/p95/max; do not infer physical latency from inference time alone.
10. Measure memory, thermal throttling, one-hour battery drain, cold start, offline
    behavior and crash-free sessions. All numbers in the brief remain unverified targets.
11. Security/privacy review, firmware watchdog, user testing with qualified accessibility
    and assistive-technology experts. Do not use this scaffold as the sole navigation aid.
12. Capture six real screenshots, supply a licensed 30-second camera-free demo asset,
    provision a release keystore and produce a signed APK only after the above gates.
