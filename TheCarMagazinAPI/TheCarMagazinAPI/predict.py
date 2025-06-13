# predict.py
import sys
import numpy as np
import logging
from tensorflow.keras.preprocessing.image import load_img, img_to_array
from tensorflow.keras.models import load_model
import json

# Logolás beállítása
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

# Osztálynevek betöltése
class_labels = sorted([
    'air compressor', 'alternator', 'battery', 'brake caliper', 'brake pad', 'brake rotor', 'camshaft',
    'carburetor', 'clutch plate', 'coil spring', 'crankshaft', 'cylinder head', 'distributor', 'engine block',
    'engine valve', 'fuel injector', 'fuse box', 'gas cap', 'headlights', 'idler arm', 'ignition coil',
    'instrument cluster', 'leaf spring', 'lower control arm', 'muffler', 'oil filter', 'oil pan',
    'oil pressure sensor', 'overflow tank', 'oxygen sensor', 'piston', 'pressure plate', 'radiator',
    'radiator fan', 'radiator hose', 'radio', 'rim', 'shift knob', 'side mirror', 'spark plug', 'spoiler',
    'starter', 'taillights', 'thermostat', 'torque converter', 'transmission', 'vacuum brake booster',
    'valve lifter', 'water pump', 'window regulator'
])

# Modell betöltése
try:
    model = load_model('maxpoolingModel.keras')
    logging.info("Modell betöltve: maxpoolingModel.keras")
except Exception as e:
    logging.error(f"Hiba a modell betöltésénél: {e}")
    sys.exit(1)

def predict_image(image_path):
    try:
        img = load_img(image_path, target_size=(224, 224))
        img_array = img_to_array(img)
        img_array = (img_array / 255.0 - np.array([0.485, 0.456, 0.406])) / np.array([0.229, 0.224, 0.225])
        img_array = np.expand_dims(img_array, axis=0)
    except Exception as e:
        logging.error(f"Hiba a kép betöltésénél: {e}")
        return json.dumps({"error": f"Image loading failed: {e}"})

    try:
        predictions = model.predict(img_array, verbose=0)[0]
        results = [{"label": label, "confidence": float(prob)} for label, prob in zip(class_labels, predictions)]
        logging.info("Predikció sikeres.")
        return json.dumps(results)
    except Exception as e:
        logging.error(f"Hiba a predikció során: {e}")
        return json.dumps({"error": f"Prediction failed: {e}"})

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(json.dumps({"error": "No image path provided"}))
        sys.exit(1)
    image_path = sys.argv[1]
    print(predict_image(image_path))