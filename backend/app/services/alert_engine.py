"""
Personalized alert engine.

Generates alerts only when conditions actually justify them (see the five
rules in the spec: heavy rain, high-moisture+rain, low-moisture+no-rain,
high pest risk, target market price). Each alert carries a `dedup_key` —
a stable fingerprint of "this kind of alert, for this crop" — so the
route layer can avoid creating duplicate active alerts every time the
dashboard refreshes and the engine re-evaluates the same conditions.

Thresholds live here (not scattered across Flutter widgets) so they're
one place to tune.
"""

HEAVY_RAIN_PROBABILITY_THRESHOLD = 70
EXTREME_HEAT_THRESHOLD_C = 40
HIGH_SOIL_MOISTURE_THRESHOLD = 65
LOW_SOIL_MOISTURE_THRESHOLD = 35
LOW_RAIN_PROBABILITY_THRESHOLD = 25
HIGH_PEST_RISK_LEVELS = ("high", "critical")


def generate_alerts(weather_current, weather_forecast, latest_reading, pest_risk, market_target_hit, crop_name, farmer_crop_id):
    alerts = []
    scope = f"crop:{farmer_crop_id}"

    rain_prob_tomorrow = 0
    if weather_forecast:
        rain_prob_tomorrow = weather_forecast[0].get("rain_probability_pct") or 0
    soil_moisture = latest_reading.get("soil_moisture_pct") if latest_reading else None

    # --- Rule 1: Heavy rain forecast ---
    if rain_prob_tomorrow >= HEAVY_RAIN_PROBABILITY_THRESHOLD:
        alerts.append(
            {
                "dedup_key": f"weather:heavy_rain:{scope}",
                "type": "weather",
                "severity": "high",
                "title": "Heavy Rainfall Alert",
                "message": f"Heavy rainfall is expected soon ({rain_prob_tomorrow}% probability).",
                "recommended_action": "Monitor field drainage and hold off on irrigation.",
            }
        )

    # --- Rule 2: High soil moisture + rain expected -> avoid irrigation ---
    if soil_moisture is not None and soil_moisture >= HIGH_SOIL_MOISTURE_THRESHOLD and rain_prob_tomorrow >= HEAVY_RAIN_PROBABILITY_THRESHOLD:
        alerts.append(
            {
                "dedup_key": f"irrigation:avoid_high_moisture_rain:{scope}",
                "type": "irrigation",
                "severity": "moderate",
                "title": "Avoid Irrigation",
                "message": (
                    f"Soil moisture is already high ({soil_moisture}%) and rain is expected "
                    f"({rain_prob_tomorrow}% probability)."
                ),
                "recommended_action": "Avoid irrigation today and check for adequate drainage.",
            }
        )

    # --- Rule 3: Low soil moisture + low rain probability -> irrigation recommended ---
    if soil_moisture is not None and soil_moisture <= LOW_SOIL_MOISTURE_THRESHOLD and rain_prob_tomorrow <= LOW_RAIN_PROBABILITY_THRESHOLD:
        alerts.append(
            {
                "dedup_key": f"irrigation:recommended_low_moisture:{scope}",
                "type": "irrigation",
                "severity": "high",
                "title": "Irrigation Recommended",
                "message": (
                    f"Soil moisture is low ({soil_moisture}%) and little to no rain is expected "
                    f"({rain_prob_tomorrow}% probability)."
                ),
                "recommended_action": "Consider irrigation within the next 12 hours.",
            }
        )

    # --- Extreme heat ---
    if weather_current and (weather_current.get("temperature_c") or 0) >= EXTREME_HEAT_THRESHOLD_C:
        alerts.append(
            {
                "dedup_key": f"weather:extreme_heat:{scope}",
                "type": "weather",
                "severity": "moderate",
                "title": "Extreme Heat Alert",
                "message": f"Current temperature is {weather_current['temperature_c']}°C for your {crop_name} crop.",
                "recommended_action": "Consider shade/mulching and check the crop for heat stress.",
            }
        )

    # --- Rule 4: High pest risk ---
    if pest_risk and pest_risk.get("risk_level") in HIGH_PEST_RISK_LEVELS:
        alerts.append(
            {
                "dedup_key": f"pest:high_risk:{scope}:{pest_risk.get('pest_id')}",
                "type": "pest",
                "severity": "high" if pest_risk["risk_level"] == "high" else "critical",
                "title": "Pest Risk Alert",
                "message": (
                    f"Elevated pest-risk conditions detected for your {crop_name} crop "
                    f"({pest_risk.get('pest_name', 'unspecified pest')}, {pest_risk['probability_pct']}% risk)."
                ),
                "recommended_action": pest_risk.get("preventive_action", "Inspect affected crop areas."),
            }
        )

    # --- Rule 5: Target market price reached ---
    if market_target_hit:
        alerts.append(
            {
                "dedup_key": f"market:target_reached:{scope}:{market_target_hit.get('id')}",
                "type": "market",
                "severity": "moderate",
                "title": "Target Price Reached",
                "message": f"Your target price of ₹{market_target_hit['target_price']}/quintal has been reached.",
                "recommended_action": "Consider evaluating nearby markets for selling now.",
            }
        )

    severity_order = {"critical": 0, "high": 1, "moderate": 2, "low": 3, "informational": 4}
    alerts.sort(key=lambda a: severity_order[a["severity"]])
    return alerts
