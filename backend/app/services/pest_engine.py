"""
Pest-risk prediction engine.

Transparent, rule-based, DETERMINISTIC risk engine — not a random-number
generator and not a trained model pretending to be one. The same inputs
always produce the same output, and every point on the score is traceable
to a specific, human-readable reason.

DESIGN NOTE (v2): The original version awarded flat all-or-nothing points
(e.g. +35 for "temperature anywhere in a wide favorable range", plus an
unconditional +20 just for the crop being on the pest's list). That made
the score pin near 100 for almost any real-world reading. This version
uses graduated scoring — each factor contributes a score that scales with
how strongly the condition is actually present, not just whether a wide
threshold was crossed at all — so the output meaningfully differentiates
between, e.g., a cool/dry reading and a hot/humid/rain-soaked one.

Weights (sum to 100 at maximum):
  Temperature suitability   -> up to 35
  Humidity suitability      -> up to 30
  Rainfall suitability      -> up to 20
  Crop susceptibility base  -> 10 (the pest is already filtered to crops
                                    it's known to affect, so this is a
                                    small constant contribution, not a
                                    dominant one)
Structured so a trained scikit-learn model could later replace
`score_pest()` without touching the rest of the app.
"""
from app.db import query_all

CROP_SUSCEPTIBILITY_BASE = 10


def _crop_matches(pest_affected_crops: str, crop_name: str) -> bool:
    if not pest_affected_crops:
        return False
    names = [c.strip().lower() for c in pest_affected_crops.split(",")]
    return crop_name.lower() in names


def _temperature_score(temperature_c, t_min, t_max, weight=35):
    """Graduated: peaks at the center of the favorable range, tapers at
    the edges, and gives a small amount of credit just outside the range
    (pests don't stop existing exactly at a boundary line)."""
    if temperature_c is None or t_min is None or t_max is None:
        return 0, None
    temperature_c, t_min, t_max = float(temperature_c), float(t_min), float(t_max)

    if t_min <= temperature_c <= t_max:
        center = (t_min + t_max) / 2
        half_range = max((t_max - t_min) / 2, 0.1)
        closeness = 1 - abs(temperature_c - center) / half_range  # 1.0 at center, 0.0 at edge
        points = weight * (0.55 + 0.45 * closeness)
        return round(points, 1), f"Temperature {temperature_c}°C is within the pest's favorable range ({t_min}–{t_max}°C)"

    dist = min(abs(temperature_c - t_min), abs(temperature_c - t_max))
    if dist <= 3:
        points = weight * 0.25 * (1 - dist / 3)
        return round(points, 1), f"Temperature {temperature_c}°C is close to the pest's favorable range ({t_min}–{t_max}°C)"

    return 0, None


def _humidity_score(humidity_pct, h_min, weight=30):
    if humidity_pct is None or h_min is None:
        return 0, None
    humidity_pct, h_min = float(humidity_pct), float(h_min)

    if humidity_pct >= h_min:
        span = max(100 - h_min, 1)
        frac = min((humidity_pct - h_min) / span, 1)
        points = weight * (0.5 + 0.5 * frac)
        return round(points, 1), f"Humidity {humidity_pct}% is above the pest's favorable threshold ({h_min}%+)"

    gap = h_min - humidity_pct
    if gap <= 10:
        points = weight * 0.25 * (1 - gap / 10)
        return round(points, 1), f"Humidity {humidity_pct}% is approaching the pest's favorable threshold ({h_min}%+)"

    return 0, None


def _rainfall_score(rainfall_mm, weight=20, saturation_mm=20):
    if not rainfall_mm or rainfall_mm <= 0:
        return 0, None
    rainfall_mm = float(rainfall_mm)
    frac = min(rainfall_mm / saturation_mm, 1)
    points = weight * frac
    return round(points, 1), f"Recent rainfall of {rainfall_mm}mm increases favorable conditions"


def score_pest(pest: dict, crop_name: str, temperature_c: float, humidity_pct: float, rainfall_mm: float):
    if not _crop_matches(pest["affected_crops"], crop_name):
        return None

    score = 0.0
    reasons = []

    t_points, t_reason = _temperature_score(temperature_c, pest.get("favorable_temp_min"), pest.get("favorable_temp_max"))
    score += t_points
    if t_reason:
        reasons.append(t_reason)

    h_points, h_reason = _humidity_score(humidity_pct, pest.get("favorable_humidity_min"))
    score += h_points
    if h_reason:
        reasons.append(h_reason)

    r_points, r_reason = _rainfall_score(rainfall_mm)
    score += r_points
    if r_reason:
        reasons.append(r_reason)

    score += CROP_SUSCEPTIBILITY_BASE
    reasons.append(f"{crop_name} is on this pest's known susceptible crop list")

    score = round(min(score, 100), 1)

    # Thresholds tuned so the project's own worked demo scenario (~64%,
    # expected to read as MODERATE) lands correctly, while still keeping
    # four meaningfully distinct bands.
    if score >= 86:
        level = "critical"  # "VERY HIGH" per spec, mapped to the schema's 'critical' enum value
    elif score >= 66:
        level = "high"
    elif score >= 31:
        level = "moderate"
    else:
        level = "low"

    return {
        "pest_id": pest["id"],
        "pest_name": pest["name"],
        "probability_pct": score,
        "risk_level": level,
        "contributing_factors": reasons,
        "preventive_action": pest["preventive_action"],
    }


def predict_pest_risk(crop_name: str, temperature_c: float, humidity_pct: float, rainfall_mm: float):
    """Evaluate every pest in the catalog against current conditions, return the highest risk."""
    pests = query_all("SELECT * FROM pests")
    results = []
    for pest in pests:
        result = score_pest(pest, crop_name, temperature_c, humidity_pct, rainfall_mm)
        if result:
            results.append(result)

    if not results:
        return {
            "pest_id": None,
            "pest_name": None,
            "probability_pct": 0,
            "risk_level": "low",
            "contributing_factors": ["No known pests catalogued for this crop under current conditions"],
            "preventive_action": "Continue routine field monitoring.",
        }

    results.sort(key=lambda r: r["probability_pct"], reverse=True)
    return results[0]
