# YOLO TFLite Export

Use Python 3.12; TensorFlow 2.19 does not support this project's Python 3.14 runtime.
Install the exporter dependencies from the repository root:

```sh
python3 -m pip install -r scripts/requirements-yolo-export.txt
```

If import fails with `libGL.so.1` on a headless Linux machine, replace the GUI
OpenCV wheel with its headless build:

```sh
python3 -m pip uninstall -y opencv-python
python3 -m pip install opencv-python-headless==4.12.0.88
```

Export the default `yolov8n.pt` checkpoint to a 640-pixel FP16 TFLite model:

```sh
python3 scripts/export_yolov8_tflite.py --weights yolov8n.pt --quantization fp16
```

Use `--quantization fp32` for full precision. INT8 export requires a representative
calibration dataset YAML and uses that dataset during calibration:

```sh
python3 scripts/export_yolov8_tflite.py --weights yolov8n.pt --quantization int8 --data path/to/calibration.yaml
```

The script copies `yolov8n.tflite` into Android assets and writes `labels.txt`,
`labels_en.txt`, and `labels_ar.txt` in the exact class order exposed by the loaded
model. Arabic translations are provided for common COCO classes; unlisted class names
remain in English rather than receiving an invented translation. Review all labels
against the trained model before use.

The default Ultralytics checkpoint may be downloaded by Ultralytics when it is not
present locally and therefore requires network access. A generic COCO model does not
detect custom classes such as stairs unless those classes were part of training. INT8
calibration data is not included; provide your own representative dataset YAML.