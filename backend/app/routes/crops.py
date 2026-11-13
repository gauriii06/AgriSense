from flask import Blueprint, jsonify, request, g

from app.db import query_all, query_one, execute
from app.auth_utils import login_required

crops_bp = Blueprint("crops", __name__)


@crops_bp.get("/catalog")
def crop_catalog():
    """Master list of crops the app knows about (for dropdowns etc.)."""
    crops = query_all("SELECT * FROM crops ORDER BY name")
    return jsonify({"success": True, "data": crops})


@crops_bp.get("")
@login_required
def list_my_crops():
    rows = query_all(
        """SELECT fc.*, c.name AS crop_name, c.category
           FROM farmer_crops fc
           JOIN crops c ON c.id = fc.crop_id
           WHERE fc.user_id = %s
           ORDER BY fc.is_active DESC, fc.created_at DESC""",
        (g.user_id,),
    )
    return jsonify({"success": True, "data": rows})


@crops_bp.post("")
@login_required
def add_crop():
    data = request.get_json(silent=True) or {}
    farm_id = data.get("farm_id")
    crop_name = (data.get("crop_name") or "").strip()

    if not farm_id or not crop_name:
        return jsonify({"success": False, "error": "farm_id and crop_name are required"}), 400

    crop = query_one("SELECT id FROM crops WHERE name = %s", (crop_name,))
    if not crop:
        return jsonify({"success": False, "error": f"Unknown crop '{crop_name}'. Check /api/crops/catalog."}), 400

    farm = query_one("SELECT id FROM farms WHERE id = %s AND user_id = %s", (farm_id, g.user_id))
    if not farm:
        return jsonify({"success": False, "error": "Farm not found"}), 404

    farmer_crop_id = execute(
        """INSERT INTO farmer_crops (user_id, farm_id, crop_id, variety, sowing_date, farm_size_acres, growth_stage)
           VALUES (%s, %s, %s, %s, %s, %s, %s)""",
        (
            g.user_id,
            farm_id,
            crop["id"],
            data.get("variety"),
            data.get("sowing_date"),
            data.get("farm_size_acres"),
            data.get("growth_stage", "sowing"),
        ),
    )
    return jsonify({"success": True, "farmer_crop_id": farmer_crop_id}), 201


@crops_bp.get("/<int:farmer_crop_id>")
@login_required
def get_crop(farmer_crop_id):
    row = query_one(
        """SELECT fc.*, c.name AS crop_name, c.category
           FROM farmer_crops fc JOIN crops c ON c.id = fc.crop_id
           WHERE fc.id = %s AND fc.user_id = %s""",
        (farmer_crop_id, g.user_id),
    )
    if not row:
        return jsonify({"success": False, "error": "Crop not found"}), 404
    return jsonify({"success": True, "data": row})


@crops_bp.put("/<int:farmer_crop_id>")
@login_required
def update_crop(farmer_crop_id):
    data = request.get_json(silent=True) or {}
    allowed = ["variety", "sowing_date", "farm_size_acres", "growth_stage", "weather_scenario"]
    fields, values = [], []
    for key in allowed:
        if key in data:
            fields.append(f"{key} = %s")
            values.append(data[key])
    if not fields:
        return jsonify({"success": False, "error": "No valid fields to update"}), 400

    values.extend([farmer_crop_id, g.user_id])
    execute(f"UPDATE farmer_crops SET {', '.join(fields)} WHERE id = %s AND user_id = %s", tuple(values))
    return jsonify({"success": True, "message": "Crop updated"})


@crops_bp.post("/<int:farmer_crop_id>/activate")
@login_required
def set_active_crop(farmer_crop_id):
    """Mark this crop as the active crop for dashboard/analysis. Deactivates others."""
    owned = query_one("SELECT id FROM farmer_crops WHERE id = %s AND user_id = %s", (farmer_crop_id, g.user_id))
    if not owned:
        return jsonify({"success": False, "error": "Crop not found"}), 404

    execute("UPDATE farmer_crops SET is_active = FALSE WHERE user_id = %s", (g.user_id,))
    execute("UPDATE farmer_crops SET is_active = TRUE WHERE id = %s", (farmer_crop_id,))
    return jsonify({"success": True, "message": "Active crop updated"})
