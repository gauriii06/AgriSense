from flask import Blueprint, jsonify, request, g

from app.db import query_one, execute
from app.auth_utils import login_required
from app.services import weather_service, market_service
from app.services.pest_engine import predict_pest_risk
from app.services.recommendation_engine import build_recommendations

recommendations_bp = Blueprint("recommendations", __name__)


def _gather_and_build(farmer_crop_id, user_id):
    crop = query_one(
        """SELECT fc.*, c.id AS crop_ref_id, c.name AS crop_name,
                  c.ideal_soil_moisture_min, c.ideal_soil_moisture_max
           FROM farmer_crops fc JOIN crops c ON c.id = fc.crop_id
           WHERE fc.id = %s AND fc.user_id = %s""",
        (farmer_crop_id, user_id),
    )
    if not crop:
        return None, None

    user = query_one("SELECT location FROM users WHERE id = %s", (user_id,))
    reading = query_one(
        "SELECT * FROM field_readings WHERE farmer_crop_id = %s ORDER BY recorded_at DESC LIMIT 1",
        (farmer_crop_id,),
    )
    scenario = crop.get("weather_scenario", "normal")
    weather_current = weather_service.get_current_weather(user["location"] or "India", scenario=scenario)
    weather_forecast = weather_service.get_forecast(user["location"] or "India", scenario=scenario)

    temperature = reading["air_temperature_c"] if reading and reading["air_temperature_c"] is not None else weather_current["temperature_c"]
    humidity = reading["humidity_pct"] if reading and reading["humidity_pct"] is not None else weather_current["humidity_pct"]
    rainfall = reading["rainfall_mm"] if reading and reading["rainfall_mm"] is not None else weather_current.get("rainfall_mm", 0)
    pest_risk = predict_pest_risk(crop["crop_name"], temperature, humidity, rainfall)

    market_summary = market_service.get_market_summary(crop["crop_ref_id"])

    recs = build_recommendations(crop, reading, weather_current, weather_forecast, pest_risk, market_summary)
    return crop, recs


@recommendations_bp.get("")
@login_required
def get_recommendations():
    farmer_crop_id = request.args.get("farmer_crop_id", type=int)
    if not farmer_crop_id:
        return jsonify({"success": False, "error": "farmer_crop_id is required"}), 400

    crop, recs = _gather_and_build(farmer_crop_id, g.user_id)
    if not crop:
        return jsonify({"success": False, "error": "Crop not found"}), 404

    for r in recs:
        execute(
            """INSERT INTO recommendations (farmer_crop_id, category, title, explanation, action, priority)
               VALUES (%s, %s, %s, %s, %s, %s)""",
            (farmer_crop_id, r["category"], r["title"], r["explanation"], r["action"], r["priority"]),
        )

    return jsonify({"success": True, "data": recs})
