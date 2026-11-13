"""
Irrigation decision support.

Deterministic rule-based logic combining current soil moisture, the crop's
ideal moisture range, and near-term rain forecast. Explanations are always
included — this is decision support, not a guaranteed outcome.
"""


def evaluate_irrigation(soil_moisture_pct, crop_moisture_min, crop_moisture_max, rain_next_24h_probability_pct):
    if soil_moisture_pct is None:
        return {
            "decision": "Monitor Conditions",
            "explanation": "No recent soil moisture reading is available.",
            "action": "Take a soil moisture reading before deciding on irrigation.",
        }

    significant_rain_expected = (rain_next_24h_probability_pct or 0) >= 60

    if soil_moisture_pct < crop_moisture_min:
        if significant_rain_expected:
            return {
                "decision": "Monitor Conditions",
                "explanation": (
                    f"Soil moisture is currently {soil_moisture_pct}%, below the ideal minimum of "
                    f"{crop_moisture_min}%, but significant rainfall is expected within 24 hours."
                ),
                "action": "Hold off on irrigation and recheck soil moisture after the rain.",
            }
        return {
            "decision": "Irrigation Recommended",
            "explanation": (
                f"Soil moisture is currently {soil_moisture_pct}%, below the ideal minimum of "
                f"{crop_moisture_min}%. No significant rainfall is expected soon."
            ),
            "action": "Consider irrigation within the next 12 hours.",
        }

    if soil_moisture_pct > crop_moisture_max:
        return {
            "decision": "Irrigation Not Required",
            "explanation": (
                f"Soil moisture is currently {soil_moisture_pct}%, above the ideal maximum of "
                f"{crop_moisture_max}%."
            ),
            "action": "Avoid irrigation today and monitor field drainage.",
        }

    return {
        "decision": "Monitor Conditions",
        "explanation": f"Soil moisture is currently {soil_moisture_pct}%, within the ideal range for this crop.",
        "action": "No action needed right now — recheck in the next 24 hours.",
    }
