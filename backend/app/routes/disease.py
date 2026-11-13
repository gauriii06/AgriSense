import os
import uuid

from flask import Blueprint, jsonify, request, g

from app.db import query_one, execute
from app.auth_utils import login_required
from app.services.disease_service import classify_image

disease_bp = Blueprint("disease", __name__)

UPLOAD_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), "uploads", "disease_images")
os.makedirs(UPLOAD_DIR, exist_ok=True)

ALLOWED_EXTENSIONS = {"jpg", "jpeg", "png"}


@disease_bp.post("/predict")
@login_required
def predict():
    farmer_crop_id = request.form.get("farmer_crop_id", type=int)
    if not farmer_crop_id:
        return jsonify({"success": False, "error": "farmer_crop_id is required"}), 400

    crop = query_one(
        "SELECT fc.*, c.id AS crop_ref_id FROM farmer_crops fc JOIN crops c ON c.id = fc.crop_id WHERE fc.id = %s AND fc.user_id = %s",
        (farmer_crop_id, g.user_id),
    )
    if not crop:
        return jsonify({"success": False, "error": "Crop not found"}), 404

    if "image" not in request.files:
        return jsonify({"success": False, "error": "No image file provided"}), 400

    file = request.files["image"]
    ext = file.filename.rsplit(".", 1)[-1].lower() if "." in file.filename else ""
    if ext not in ALLOWED_EXTENSIONS:
        return jsonify({"success": False, "error": "Invalid image format. Use jpg or png."}), 400

    image_bytes = file.read()
    if not image_bytes:
        return jsonify({"success": False, "error": "Empty image file"}), 400

    filename = f"{uuid.uuid4().hex}.{ext}"
    filepath = os.path.join(UPLOAD_DIR, filename)
    with open(filepath, "wb") as f:
        f.write(image_bytes)

    result = classify_image(image_bytes, crop["crop_ref_id"])
    if not result:
        return jsonify({"success": False, "error": "No disease information available for this crop yet"}), 404

    execute(
        """INSERT INTO disease_predictions (farmer_crop_id, disease_id, image_path, confidence_pct)
           VALUES (%s, %s, %s, %s)""",
        (farmer_crop_id, result["disease_id"], filename, result["confidence_pct"]),
    )

    return jsonify({"success": True, "data": result})
