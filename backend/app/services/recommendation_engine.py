"""
Centralized recommendation engine.

Combines field conditions, weather, pest risk, and market data into a
prioritized list of actionable recommendations. Rule-based by design —
see project principle: "a good rule-based decision beats a meaningless
AI-generated one."
"""
from app.services.irrigation_engine import evaluate_irrigation


def build_recommendations(crop, latest_reading, weather_current, weather_forecast, pest_risk, market_summary):
    """
    crop: dict with crop_name, ideal_soil_moisture_min/max, growth_stage
    latest_reading: dict from field_readings (or None)
    weather_current / weather_forecast: dicts/list from weather_service
    pest_risk: dict from pest_engine
    market_summary: dict from market_service (or None)
    Returns a list of recommendation dicts, highest priority first.
    """
    recs = []

    # --- Irrigation ---
    rain_prob = 0
    if weather_forecast:
        rain_prob = weather_forecast[0].get("rain_probability_pct") or 0
    soil_moisture = latest_reading["soil_moisture_pct"] if latest_reading else None
    irrigation = evaluate_irrigation(
        soil_moisture,
        crop.get("ideal_soil_moisture_min"),
        crop.get("ideal_soil_moisture_max"),
        rain_prob,
    )
    # Both "irrigate now" and "avoid irrigation, moisture already excessive" are
    # actionable decisions the farmer should act on today. Only the passive
    # "Monitor Conditions" case (nothing to actually do right now) is lower
    # priority. Irrigation is appended to the list first, so on a priority tie
    # with pest risk it still surfaces first — matching the demo scenario
    # where "avoid irrigation, check drainage" is the headline action.
    priority = "high" if irrigation["decision"] in ("Irrigation Recommended", "Irrigation Not Required") else "medium"
    recs.append(
        {
            "category": "irrigation",
            "title": irrigation["decision"],
            "explanation": irrigation["explanation"],
            "action": irrigation["action"],
            "priority": priority,
        }
    )

    # --- Pest management ---
    if pest_risk and pest_risk.get("risk_level") in ("high", "moderate"):
        recs.append(
            {
                "category": "pest_management",
                "title": f"{pest_risk['risk_level'].title()} Pest Risk"
                + (f" — {pest_risk['pest_name']}" if pest_risk.get("pest_name") else ""),
                "explanation": "Conditions favorable for: " + ", ".join(pest_risk.get("contributing_factors", [])),
                "action": pest_risk.get("preventive_action", "Inspect the crop for early symptoms."),
                "priority": "high" if pest_risk["risk_level"] == "high" else "medium",
            }
        )

    # --- Weather-driven crop protection ---
    if weather_current and weather_current.get("rainfall_mm", 0) and weather_current["rainfall_mm"] > 20:
        recs.append(
            {
                "category": "crop_protection",
                "title": "Heavy Rainfall Impact",
                "explanation": "Heavy rainfall has been recorded recently, which can cause waterlogging.",
                "action": "Check field drainage and avoid additional irrigation.",
                "priority": "high",
            }
        )

    # --- Market selection ---
    if market_summary:
        recs.append(
            {
                "category": "market_selection",
                "title": f"Best Price: {market_summary['best_market']}",
                "explanation": f"₹{market_summary['best_price']:.0f}/quintal is the highest available price nearby, trend is {market_summary['trend'].lower()}.",
                "action": f"Consider selling at {market_summary['best_market']} if trend holds.",
                "priority": "low",
            }
        )

    # --- Harvesting nudge based on growth stage ---
    if crop.get("growth_stage") == "maturity":
        recs.append(
            {
                "category": "harvesting",
                "title": "Crop Nearing Harvest",
                "explanation": "The crop's recorded growth stage is 'maturity'.",
                "action": "Plan harvesting logistics and monitor weather for a dry window.",
                "priority": "medium",
            }
        )

    order = {"high": 0, "medium": 1, "low": 2}
    recs.sort(key=lambda r: order[r["priority"]])
    return recs
