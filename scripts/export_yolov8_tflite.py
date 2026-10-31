#!/usr/bin/env python3
"""Export a YOLO model to Android assets with matching class-label files."""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "android" / "app" / "src" / "main" / "assets"

ARABIC_LABELS = {
    "person": "شخص",
    "bicycle": "دراجة",
    "car": "سيارة",
    "motorcycle": "دراجة نارية",
    "airplane": "طائرة",
    "bus": "حافلة",
    "train": "قطار",
    "truck": "شاحنة",
    "boat": "قارب",
    "traffic light": "إشارة مرور",
    "fire hydrant": "صنبور إطفاء",
    "stop sign": "إشارة توقف",
    "parking meter": "عداد مواقف",
    "bench": "مقعد",
    "bird": "طائر",
    "cat": "قطة",
    "dog": "كلب",
    "horse": "حصان",
    "sheep": "خروف",
    "cow": "بقرة",
    "elephant": "فيل",
    "bear": "دب",
    "zebra": "حمار وحشي",
    "giraffe": "زرافة",
    "backpack": "حقيبة ظهر",
    "umbrella": "مظلة",
    "handbag": "حقيبة يد",
    "tie": "ربطة عنق",
    "suitcase": "حقيبة سفر",
    "frisbee": "قرص طائر",
    "skis": "زلاجات",
    "snowboard": "لوح تزلج",
    "sports ball": "كرة",
    "kite": "طائرة ورقية",
    "baseball bat": "مضرب بيسبول",
    "baseball glove": "قفاز بيسبول",
    "skateboard": "لوح تزلج بعجلات",
    "surfboard": "لوح ركوب الأمواج",
    "tennis racket": "مضرب تنس",
    "bottle": "زجاجة",
    "wine glass": "كأس",
    "cup": "كوب",
    "fork": "شوكة",
    "knife": "سكين",
    "spoon": "ملعقة",
    "bowl": "وعاء",
    "banana": "موزة",
    "apple": "تفاحة",
    "sandwich": "شطيرة",
    "orange": "برتقالة",
    "broccoli": "بروكلي",
    "carrot": "جزرة",
    "hot dog": "نقانق",
    "pizza": "بيتزا",
    "donut": "دونات",
    "cake": "كعكة",
    "chair": "كرسي",
    "couch": "أريكة",
    "potted plant": "نبات أصيص",
    "bed": "سرير",
    "dining table": "طاولة طعام",
    "toilet": "مرحاض",
    "tv": "تلفاز",
    "laptop": "حاسوب محمول",
    "mouse": "فأرة حاسوب",
    "remote": "جهاز تحكم",
    "keyboard": "لوحة مفاتيح",
    "cell phone": "هاتف محمول",
    "microwave": "ميكروويف",
    "oven": "فرن",
    "toaster": "محمصة خبز",
    "sink": "مغسلة",
    "refrigerator": "ثلاجة",
    "book": "كتاب",
    "clock": "ساعة",
    "vase": "مزهرية",
    "scissors": "مقص",
    "teddy bear": "دب محشو",
    "hair drier": "مجفف شعر",
    "toothbrush": "فرشاة أسنان",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--weights", type=Path, default=Path("yolov8n.pt"),
                        help="Ultralytics checkpoint or model path (default: yolov8n.pt)")
    parser.add_argument("--quantization", choices=("fp32", "fp16", "int8"), default="fp16")
    parser.add_argument("--data", type=Path,
                        help="Calibration dataset YAML, required for INT8 export")
    parser.add_argument("--imgsz", type=int, choices=(320, 640), default=640)
    return parser.parse_args()


def model_names(model: object) -> list[str]:
    names = getattr(model, "names", None)
    if isinstance(names, dict):
        return [str(names[index]) for index in sorted(names)]
    if isinstance(names, (list, tuple)):
        return [str(name) for name in names]
    raise RuntimeError("The loaded model does not expose an ordered class-name list")


def locate_tflite(export_result: object) -> Path:
    result = Path(str(export_result)).expanduser()
    if result.is_file() and result.suffix.lower() == ".tflite":
        return result.resolve()
    if result.is_dir():
        candidates = sorted(result.rglob("*.tflite"))
    else:
        candidates = sorted(result.parent.rglob("*.tflite")) if result.parent.exists() else []
    if len(candidates) != 1:
        raise RuntimeError(f"Expected one exported .tflite file, found {len(candidates)} near {result}")
    return candidates[0].resolve()


def write_labels(names: list[str], destination: Path) -> None:
    english = [name.strip() for name in names]
    arabic = [ARABIC_LABELS.get(name.casefold(), name) for name in english]
    destination.mkdir(parents=True, exist_ok=True)
    (destination / "labels.txt").write_text("\n".join(english) + "\n", encoding="utf-8")
    (destination / "labels_en.txt").write_text("\n".join(english) + "\n", encoding="utf-8")
    (destination / "labels_ar.txt").write_text("\n".join(arabic) + "\n", encoding="utf-8")


def main() -> int:
    args = parse_args()
    if args.quantization == "int8" and (args.data is None or not args.data.is_file()):
        print("INT8 export requires an existing --data calibration YAML.", file=sys.stderr)
        return 2

    try:
        from ultralytics import YOLO
    except ImportError as error:
        print("Ultralytics is required. Install scripts/requirements-yolo-export.txt.", file=sys.stderr)
        print(error, file=sys.stderr)
        return 2

    model = YOLO(str(args.weights))
    names = model_names(model)
    export_options = {
        "format": "tflite",
        "imgsz": args.imgsz,
        "int8": args.quantization == "int8",
        "half": args.quantization == "fp16",
    }
    if args.quantization == "int8":
        export_options["data"] = str(args.data.resolve())

    exported = locate_tflite(model.export(**export_options))
    ASSETS.mkdir(parents=True, exist_ok=True)
    target = ASSETS / "yolov8n.tflite"
    if exported != target.resolve():
        shutil.copy2(exported, target)
    write_labels(names, ASSETS)
    print(f"Installed {target} ({target.stat().st_size} bytes)")
    print(f"Installed bilingual label files with {len(names)} model classes in {ASSETS}")
    print("Arabic names without an explicit translation retain their model class name.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())