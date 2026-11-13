"""
Crop disease identification service.

IMPORTANT / HONEST LIMITATION:
This development environment has no trained TensorFlow/Keras model and no
labeled disease-image dataset available. Rather than pretending an
untrained or fabricated model is accurate, this module implements the full
architecture (image intake -> preprocessing -> classifier -> result) with
a clearly-labeled DEMONSTRATION classifier: a deterministic image-hash
based selector over the `diseases` table, tagged `is_demo_model: true` in
every response.

To go to production:
  1. Collect/label a real image dataset (e.g. PlantVillage) per crop.
  2. Train a CNN (e.g. MobileNetV2 transfer learning) with Keras.
  3. Save as disease_model.h5 and load it in `classify_image()` below,
     replacing the demo branch only — routes/disease.py does not change.
"""
import hashlib
import os

from app.db import query_all, query_one

MODEL_PATH = os.getenv("DISEASE_MODEL_PATH", "")


def _demo_classify(image_bytes: bytes, crop_id: int):
    """Deterministic (not random) placeholder: same image -> same result."""
    diseases = query_all("SELECT * FROM diseases WHERE crop_id = %s", (crop_id,))
    if not diseases:
        return None

    digest = hashlib.sha256(image_bytes).hexdigest()
    index = int(digest, 16) % len(diseases)
    chosen = diseases[index]
    # Deterministic pseudo-confidence in a realistic band, derived from the hash
    confidence = 55 + (int(digest[:4], 16) % 35)  # 55-89%

    return {
        "disease_id": chosen["id"],
        "disease_name": chosen["name"],
        "description": chosen["description"],
        "treatment": chosen["treatment"],
        "confidence_pct": confidence,
        "is_demo_model": True,
        "model_note": (
            "No trained model is deployed in this environment. This result comes from a "
            "deterministic demonstration classifier and should not be used for real "
            "treatment decisions until a properly trained/evaluated model is integrated."
        ),
    }


def classify_image(image_bytes: bytes, crop_id: int):
    if MODEL_PATH and os.path.exists(MODEL_PATH):
        # Placeholder hook for a real trained model. Kept isolated so swapping
        # in a real TF/Keras model doesn't require touching the routes layer.
        raise NotImplementedError("Trained model loading not configured in this environment")
    return _demo_classify(image_bytes, crop_id)
