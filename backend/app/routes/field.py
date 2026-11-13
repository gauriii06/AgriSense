from flask import Blueprint, jsonify, request, g
from datetime import datetime

from app.db import query_all, query_one, execute
from app.auth_utils import login_required

field_bp = Blueprint("field", __name__)


def _serialize_datetime(value):
    if isinstance(value, datetime):
        return value.isoformat()
    return value


def _status(value, low, high):
    if value is None:
        return "Unknown"
    if value < low:
        return "Low"
    if value > high:
        return "High"
    return "Normal"


def _owned_crop(farmer_crop_id, user_id):
    return query_one(
        "SELECT * FROM farmer_crops WHERE id = %s AND user_id = %s",
        (farmer_crop_id, user_id),
    )


@field_bp.get("/readings")
@login_required
def latest_reading():
    farmer_crop_id = request.args.get("farmer_crop_id", type=int)

    if not farmer_crop_id or not _owned_crop(farmer_crop_id, g.user_id):
        return jsonify({
            "success": False,
            "error": "Valid farmer_crop_id is required"
        }), 400

    reading = query_one(
        "SELECT * FROM field_readings "
        "WHERE farmer_crop_id = %s "
        "ORDER BY recorded_at DESC LIMIT 1",
        (farmer_crop_id,),
    )

    if not reading:
        return jsonify({
            "success": True,
            "data": None,
            "message": "No field readings recorded yet"
        })

    # Convert MySQL datetime to ISO format for Flutter
    reading["recorded_at"] = _serialize_datetime(reading["recorded_at"])

    reading["soil_moisture_status"] = _status(
        float(reading["soil_moisture_pct"] or 0), 40, 70
    )
    reading["temperature_status"] = _status(
        float(reading["air_temperature_c"] or 0), 18, 32
    )
    reading["humidity_status"] = _status(
        float(reading["humidity_pct"] or 0), 40, 75
    )

    return jsonify({
        "success": True,
        "data": reading
    })


@field_bp.get("/history")
@login_required
def history():
    farmer_crop_id = request.args.get("farmer_crop_id", type=int)

    if not farmer_crop_id or not _owned_crop(farmer_crop_id, g.user_id):
        return jsonify({
            "success": False,
            "error": "Valid farmer_crop_id is required"
        }), 400

    rows = query_all(
        """SELECT soil_moisture_pct, air_temperature_c, humidity_pct,
                  rainfall_mm, recorded_at
           FROM field_readings
           WHERE farmer_crop_id = %s
           ORDER BY recorded_at DESC
           LIMIT 30""",
        (farmer_crop_id,),
    )

    rows = list(reversed(rows))

    # Convert MySQL datetimes to ISO format for Flutter
    for row in rows:
        row["recorded_at"] = _serialize_datetime(row["recorded_at"])

    return jsonify({
        "success": True,
        "data": rows
    })


@field_bp.post("/readings")
@login_required
def add_reading():
    """Manually log a field reading (stand-in for a real sensor feed)."""
    data = request.get_json(silent=True) or {}

    farmer_crop_id = data.get("farmer_crop_id")

    if not farmer_crop_id or not _owned_crop(farmer_crop_id, g.user_id):
        return jsonify({
            "success": False,
            "error": "Valid farmer_crop_id is required"
        }), 400

    reading_id = execute(
        """INSERT INTO field_readings
           (farmer_crop_id, soil_moisture_pct, soil_temperature_c,
            air_temperature_c, humidity_pct, rainfall_mm,
            light_intensity_lux, source)
           VALUES (%s, %s, %s, %s, %s, %s, %s, %s)""",
        (
            farmer_crop_id,
            data.get("soil_moisture_pct"),
            data.get("soil_temperature_c"),
            data.get("air_temperature_c"),
            data.get("humidity_pct"),
            data.get("rainfall_mm"),
            data.get("light_intensity_lux"),
            data.get("source", "manual"),
        ),
    )

    return jsonify({
        "success": True,
        "reading_id": reading_id
    }), 201