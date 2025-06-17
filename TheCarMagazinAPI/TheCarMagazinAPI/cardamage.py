import sys
import json
import logging
import base64
from ultralytics import YOLO
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import io
import contextlib

# Configure logging to stderr
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[logging.StreamHandler(sys.stderr)]
)
logger = logging.getLogger(__name__)

# Hungarian translations for labels
LABEL_TRANSLATIONS = {
    "01-minor": "Kis kár",
    "02-moderate": "Közepes kár",
    "03-severe": "Súlyos kár"
}

def annotate_image(image_path, label, confidence):
    try:
        img = Image.open(image_path).convert("RGB")
        draw = ImageDraw.Draw(img)
        try:
            font = ImageFont.truetype("arial.ttf", 30)
        except IOError:
            logger.warning("Arial font not found, using default font")
            font = ImageFont.load_default()

        # Use Hungarian translation if available
        display_label = LABEL_TRANSLATIONS.get(label, label)
        text = f"{display_label}: {confidence:.1f}%"
        text_bbox = draw.textbbox((10, 10), text, font=font)
        draw.rectangle(text_bbox, fill="black")
        draw.text((10, 10), text, fill="white", font=font)

        buffer = io.BytesIO()
        img.save(buffer, format="JPEG")
        buffer.seek(0)
        return base64.b64encode(buffer.getvalue()).decode("utf-8")
    except Exception as e:
        logger.error(f"Error annotating image: {str(e)}", exc_info=True)
        return ""

def predict_image(image_path):
    try:
        logger.info("Loading YOLO model: car-damage.pt")
        model = YOLO("car-damage.pt")
        logger.info("Model loaded successfully")
        logger.info(f"Processing image: {image_path}")

        # Suppress YOLO output
        with contextlib.redirect_stdout(io.StringIO()):
            results = model(image_path, verbose=False)

        result = results[0]  # Single image
        predictions = []
        top_label = None
        top_confidence = 0.0

        # Handle classification
        if result.probs is not None:
            probs = result.probs.data.cpu().numpy()
            for idx, prob in enumerate(probs):
                label = result.names[idx]
                confidence = float(prob)
                predictions.append({
                    "label": label,
                    "confidence": confidence
                })
                if confidence > top_confidence:
                    top_label = label
                    top_confidence = confidence * 100

        # Handle object detection (if model changes in future)
        elif result.boxes is not None:
            for box in result.boxes:
                label = result.names[int(box.cls)]
                confidence = float(box.conf)
                predictions.append({
                    "label": label,
                    "confidence": confidence
                })
                if confidence > top_confidence:
                    top_label = label
                    top_confidence = confidence * 100

        else:
            logger.warning("No predictions found")
            return json.dumps({
                "predictions": [{"label": "No detections", "confidence": 0.0}],
                "annotated_image": ""
            })

        # Sort predictions by confidence (descending)
        predictions.sort(key=lambda x: x["confidence"], reverse=True)

        # Annotate image with top prediction
        img_base64 = annotate_image(image_path, top_label, top_confidence) if top_label else ""

        response = {
            "predictions": predictions,
            "annotated_image": img_base64
        }
        logger.info(f"Prediction results: {json.dumps(predictions)}")
        return json.dumps(response, ensure_ascii=False)

    except Exception as e:
        logger.error(f"Error in predict_image: {str(e)}", exc_info=True)
        return json.dumps({
            "predictions": [{"label": f"Error: {str(e)}", "confidence": 0.0}],
            "annotated_image": ""
        })

if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            logger.error(f"Invalid arguments: {sys.argv}")
            print(json.dumps({
                "predictions": [{"label": "Invalid arguments: expected image path", "confidence": 0.0}],
                "annotated_image": ""
            }), file=sys.stderr)
            sys.exit(1)

        image_path = sys.argv[1]
        if not Path(image_path).is_file():
            logger.error(f"Image not found: {image_path}")
            print(json.dumps({
                "predictions": [{"label": "Image not found", "confidence": 0.0}],
                "annotated_image": ""
            }), file=sys.stderr)
            sys.exit(1)

        logger.info(f"Starting prediction for image: {image_path}")
        output = predict_image(image_path)
        print(output)
        sys.exit(0)

    except Exception as e:
        logger.error(f"Unexpected error: {str(e)}", exc_info=True)
        print(json.dumps({
            "predictions": [{"label": f"Unexpected error: {str(e)}", "confidence": 0.0}],
            "annotated_image": ""
        }), file=sys.stderr)
        sys.exit(1)