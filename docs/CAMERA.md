# ESP32-CAM MJPEG source
The camera channel connects to `http://192.168.4.1:81/stream` and extracts JPEG
frames in memory. Inference is throttled to at most 18 FPS; frames larger than 4 MiB
are discarded, and the HTTP connection retries with capped exponential backoff.
Android cleartext HTTP is permitted only for the ESP32-CAM host.

## Runtime behavior
`MjpegStreamHandler` is the default camera adapter. It binds the HTTP request to the
connected Wi-Fi network, parses JPEG SOI/EOI markers without disk I/O, drops frames
above 4 MiB, and caps inference at about 18 FPS on a dedicated executor. Connection
retries back off to 30 seconds. The method channel reports ready only after the model
loads and the HTTP endpoint responds successfully.

No live preview or motion-based battery saver is implemented. Inference uses the CPU;
performance, device thermals, and sustained frame rate have not been measured.

Model: add a verified `yolov8n.tflite` (preferred) or `best_float32.tflite` to the
assets directory. Input must be square NHWC RGB at 320 or 640; FP32 uses [0,1]
normalization, quantized tensors use their affine scale/zero-point. Letterbox fill is
114. Accepted raw output layouts are [1,4+C,N] or [1,N,4+C]; for the 15 placeholder
classes this is [1,19,N] or [1,N,19]. xywh coordinates must be in input-pixel units.
Verify tensor contents, class order and export settings, not just the filename.
No embedded NMS/objectness/sigmoid guessing is performed. Outputs with normalized
xywh, segmentation masks or end-to-end NMS need a different decoder.
Class-aware NMS threshold .45 and score threshold .5. The currently exported standard
COCO model uses 80 class names; `labels_en.txt` and `labels_ar.txt` share this order,
and the app selects the active map from its persisted language preference. Most Arabic
COCO names are translated, with unmapped names intentionally retained in English.
This checkpoint does not detect custom classes such as stairs unless separately
trained for them.
