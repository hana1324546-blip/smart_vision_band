`yolov8n.tflite` is generated from the standard Ultralytics COCO `yolov8n.pt`
checkpoint. It is not trained for custom classes such as stairs or curbs and is not
validated as a navigation aid. Replace it only with a real, compatible trained model;
do not rename an empty file or unrelated model to satisfy the asset name. Verify the
class order against both `labels_en.txt` and `labels_ar.txt`, and confirm the raw
output layout after every model change.

See `docs/MODEL_EXPORT.md` for the Ultralytics export command. The app logs a
missing-model warning and continues in ultrasonic-only mode if neither
`yolov8n.tflite` nor legacy `best_float32.tflite` is present.
