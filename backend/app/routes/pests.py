from flask import Blueprint, jsonify, request, g
import json

from app.db import query_one, execute
from app.auth_utils import login_required
from app.services import weather_service
from app.services.pest_engine import predict_pest_risk

pests_bp = Blueprint("pests", __name__)


@pests_bp.get("/risk")
@login_required
def pest_risk():
    farmer_crop_id = request.args.get("farmer_crop_id", type=int)
    if not farmer_crop_id:
        return jsonify({"success": False, "error": "farmer_crop_id is required"}), 400

    crop = query_one(
        """SELECT fc.*, c.name AS crop_name FROM farmer_crops fc
           JOIN crops c ON c.id = fc.crop_id
           WHERE fc.id = %s AND fc.user_id = %s""",
        (farmer_crop_id, g.user_id),
    )
    if not crop:
        return jsonify({"success": False, "error": "Crop not found"}), 404

    reading = query_one(
        "SELECT * FROM field_readings WHERE farmer_crop_id = %s ORDER BY recorded_at DESC LIMIT 1",
        (farmer_crop_id,),
    )

    user = query_one("SELECT location FROM users WHERE id = %s", (g.user_id,))
    scenario = crop.get("weather_scenario", "normal")
    weather = weather_service.get_current_weather(user["location"] or "India", scenario=scenario)

    temperature = reading["air_temperature_c"] if reading and reading["air_temperature_c"] is not None else weather["temperature_c"]
    humidity = reading["humidity_pct"] if reading and reading["humidity_pct"] is not None else weather["humidity_pct"]
    rainfall = reading["rainfall_mm"] if reading and reading["rainfall_mm"] is not None else weather.get("rainfall_mm", 0)

    result = predict_pest_risk(crop["crop_name"], temperature, humidity, rainfall)

    execute(
        """INSERT INTO pest_predictions (farmer_crop_id, pest_id, probability_pct, risk_level, contributing_factors)
           VALUES (%s, %s, %s, %s, %s)""",
        (
            farmer_crop_id,
            result["pest_id"],
            result["probability_pct"],
            result["risk_level"],
            json.dumps(result["contributing_factors"]),
        ),
    )

    return jsonify({"success": True, "data": result})
