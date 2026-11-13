from flask import Blueprint, jsonify, request

from app.db import query_all, query_one, execute

admin_bp = Blueprint("admin", __name__)

# NOTE: For simplicity/demo purposes this admin API does not require a
# separate admin auth flow. In a production system these routes must be
# protected by an admin-only role check on top of login_required.


@admin_bp.get("/farmers")
def list_farmers():
    rows = query_all("SELECT id, full_name, email, mobile, location, state, district, created_at FROM users ORDER BY created_at DESC")
    return jsonify({"success": True, "data": rows})


@admin_bp.get("/crops")
def list_crops():
    rows = query_all(
        """SELECT fc.id, u.full_name AS farmer_name, c.name AS crop_name, fc.growth_stage, fc.is_active
           FROM farmer_crops fc
           JOIN users u ON u.id = fc.user_id
           JOIN crops c ON c.id = fc.crop_id
           ORDER BY fc.created_at DESC"""
    )
    return jsonify({"success": True, "data": rows})


@admin_bp.get("/crop-catalog")
def crop_catalog():
    return jsonify({"success": True, "data": query_all("SELECT * FROM crops ORDER BY name")})


@admin_bp.post("/crop-catalog")
def add_crop_type():
    data = request.get_json(silent=True) or {}
    name = (data.get("name") or "").strip()
    if not name:
        return jsonify({"success": False, "error": "name is required"}), 400
    crop_id = execute(
        """INSERT INTO crops (name, category, typical_duration_days, ideal_soil_moisture_min,
                               ideal_soil_moisture_max, ideal_temp_min, ideal_temp_max)
           VALUES (%s, %s, %s, %s, %s, %s, %s)""",
        (
            name,
            data.get("category"),
            data.get("typical_duration_days"),
            data.get("ideal_soil_moisture_min"),
            data.get("ideal_soil_moisture_max"),
            data.get("ideal_temp_min"),
            data.get("ideal_temp_max"),
        ),
    )
    return jsonify({"success": True, "crop_id": crop_id}), 201


@admin_bp.get("/pests")
def list_pests():
    return jsonify({"success": True, "data": query_all("SELECT * FROM pests ORDER BY name")})


@admin_bp.get("/diseases")
def list_diseases():
    return jsonify({"success": True, "data": query_all("SELECT * FROM diseases ORDER BY name")})


@admin_bp.get("/alerts")
def list_all_alerts():
    return jsonify({"success": True, "data": query_all("SELECT * FROM alerts ORDER BY created_at DESC LIMIT 100")})


@admin_bp.get("/stats")
def stats():
    farmers = query_one("SELECT COUNT(*) AS n FROM users")["n"]
    crops = query_one("SELECT COUNT(*) AS n FROM farmer_crops")["n"]
    alerts = query_one("SELECT COUNT(*) AS n FROM alerts")["n"]
    disease_checks = query_one("SELECT COUNT(*) AS n FROM disease_predictions")["n"]
    return jsonify(
        {
            "success": True,
            "data": {
                "total_farmers": farmers,
                "total_crop_records": crops,
                "total_alerts": alerts,
                "total_disease_checks": disease_checks,
            },
        }
    )
