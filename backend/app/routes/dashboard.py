from flask import Blueprint, jsonify, g

from app.db import query_one
from app.auth_utils import login_required
from app.services import weather_service, market_service
from app.services.pest_engine import predict_pest_risk
from app.services.recommendation_engine import build_recommendations
from app.services.alert_service import sync_alerts_for_crop

dashboard_bp = Blueprint("dashboard", __name__)


@dashboard_bp.get("/summary")
@login_required
def summary():
    user = query_one("SELECT full_name, location FROM users WHERE id = %s", (g.user_id,))

    active_crop = query_one(
        """SELECT fc.*, c.id AS crop_ref_id, c.name AS crop_name,
                  c.ideal_soil_moisture_min, c.ideal_soil_moisture_max,
                  f.farm_name
           FROM farmer_crops fc
           JOIN crops c ON c.id = fc.crop_id
           JOIN farms f ON f.id = fc.farm_id
           WHERE fc.user_id = %s AND fc.is_active = TRUE
           LIMIT 1""",
        (g.user_id,),
    )

    if not active_crop:
        return jsonify(
            {
                "success": True,
                "data": {
                    "farmer_name": user["full_name"],
                    "has_active_crop": False,
                    "message": "Add a crop and mark it active to see your dashboard.",
                },
            }
        )

    scenario = active_crop.get("weather_scenario", "normal")
    weather_current = weather_service.get_current_weather(user["location"] or "India", scenario=scenario)
    weather_forecast = weather_service.get_forecast(user["location"] or "India", scenario=scenario)

    reading = query_one(
        "SELECT * FROM field_readings WHERE farmer_crop_id = %s ORDER BY recorded_at DESC LIMIT 1",
        (active_crop["id"],),
    )

    temperature = reading["air_temperature_c"] if reading and reading["air_temperature_c"] is not None else weather_current["temperature_c"]
    humidity = reading["humidity_pct"] if reading and reading["humidity_pct"] is not None else weather_current["humidity_pct"]
    rainfall = reading["rainfall_mm"] if reading and reading["rainfall_mm"] is not None else weather_current.get("rainfall_mm", 0)
    pest_risk = predict_pest_risk(active_crop["crop_name"], temperature, humidity, rainfall)

    market_summary = market_service.get_market_summary(active_crop["crop_ref_id"])

    recs = build_recommendations(active_crop, reading, weather_current, weather_forecast, pest_risk, market_summary)
    top_recommendation = recs[0] if recs else None

    active_alerts = sync_alerts_for_crop(g.user_id, active_crop, weather_current, weather_forecast, reading, pest_risk)
    top_alert = active_alerts[0] if active_alerts else None

    return jsonify(
        {
            "success": True,
            "data": {
                "farmer_name": user["full_name"],
                "has_active_crop": True,
                "farm_name": active_crop["farm_name"],
                "crop_name": active_crop["crop_name"],
                "growth_stage": active_crop["growth_stage"],
                "weather": {
                    "temperature_c": weather_current["temperature_c"],
                    "humidity_pct": weather_current["humidity_pct"],
                    "condition": weather_current["weather_condition"],
                    "forecast_summary": weather_forecast[0]["condition"] if weather_forecast else None,
                },
                "field": {
                    "soil_moisture_pct": reading["soil_moisture_pct"] if reading else None,
                },
                "pest_risk": {
                    "level": pest_risk["risk_level"],
                    "probability_pct": pest_risk["probability_pct"],
                },
                "market": (
                    {"price": market_summary["best_price"], "market": market_summary["best_market"]}
                    if market_summary
                    else None
                ),
                "priority_alert": top_alert,
                "recommendation": top_recommendation,
            },
        }
    )
