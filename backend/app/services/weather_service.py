"""
Weather intelligence service.

Uses OpenWeatherMap if OPENWEATHER_API_KEY is configured. If the key is
missing or the API call fails, falls back to a structured fallback
dataset so the app stays demonstrable. Fallback data is never silently
mixed into what looks like a live response — `is_fallback` always tells
the caller which one it got.

DESIGN NOTE: the fallback used to be a single hardcoded dataset that
always forecast an 80% chance of rain tomorrow. That silently overrode
every irrigation/alert decision toward "rain is coming, don't irrigate"
regardless of how dry the field actually was, making it impossible to
demonstrate the "dry field -> irrigation recommended" scenario without a
live API key. The fallback is now several named, deterministic scenarios
(dry / normal / rain) so the demo can actually show the decision engine
responding differently to different conditions — matching the project's
own requirement that test data be deterministic but NOT fixed to one
constant outcome.
"""
import requests
from datetime import datetime, timezone
from flask import current_app

OPENWEATHER_URL = "https://api.openweathermap.org/data/2.5/weather"
OPENWEATHER_FORECAST_URL = "https://api.openweathermap.org/data/2.5/forecast"

FALLBACK_SCENARIOS = {
    "normal": {
        "current": {
            "temperature_c": 29.0, "feels_like_c": 31.0, "humidity_pct": 62,
            "wind_speed_kmh": 10.0, "rainfall_mm": 0.0,
            "weather_condition": "Partly Cloudy", "rain_probability_pct": 25,
        },
        "forecast": [
            {"day": "Tomorrow", "condition": "Partly Cloudy", "temp_high_c": 30, "temp_low_c": 22, "rain_probability_pct": 25},
            {"day": "Day 2", "condition": "Sunny", "temp_high_c": 31, "temp_low_c": 23, "rain_probability_pct": 10},
            {"day": "Day 3", "condition": "Partly Cloudy", "temp_high_c": 30, "temp_low_c": 22, "rain_probability_pct": 20},
        ],
    },
    "dry": {
        "current": {
            "temperature_c": 34.0, "feels_like_c": 37.0, "humidity_pct": 38,
            "wind_speed_kmh": 14.0, "rainfall_mm": 0.0,
            "weather_condition": "Sunny", "rain_probability_pct": 5,
        },
        "forecast": [
            {"day": "Tomorrow", "condition": "Sunny", "temp_high_c": 35, "temp_low_c": 25, "rain_probability_pct": 5},
            {"day": "Day 2", "condition": "Sunny", "temp_high_c": 36, "temp_low_c": 26, "rain_probability_pct": 5},
            {"day": "Day 3", "condition": "Clear", "temp_high_c": 35, "temp_low_c": 25, "rain_probability_pct": 10},
        ],
    },
    "rain": {
        "current": {
            "temperature_c": 27.0, "feels_like_c": 28.0, "humidity_pct": 85,
            "wind_speed_kmh": 18.0, "rainfall_mm": 6.0,
            "weather_condition": "Rain", "rain_probability_pct": 85,
        },
        "forecast": [
            {"day": "Tomorrow", "condition": "Heavy Rain", "temp_high_c": 27, "temp_low_c": 22, "rain_probability_pct": 85},
            {"day": "Day 2", "condition": "Rain", "temp_high_c": 28, "temp_low_c": 22, "rain_probability_pct": 60},
            {"day": "Day 3", "condition": "Partly Cloudy", "temp_high_c": 30, "temp_low_c": 23, "rain_probability_pct": 30},
        ],
    },
}
DEFAULT_FALLBACK_SCENARIO = "normal"


def _fallback_current(scenario: str, location_text: str):
    data = dict(FALLBACK_SCENARIOS.get(scenario, FALLBACK_SCENARIOS[DEFAULT_FALLBACK_SCENARIO])["current"])
    data["location"] = location_text
    data["is_fallback"] = True
    data["fallback_scenario"] = scenario
    data["fetched_at"] = datetime.now(timezone.utc).isoformat()
    return data


def _fallback_forecast(scenario: str):
    return list(FALLBACK_SCENARIOS.get(scenario, FALLBACK_SCENARIOS[DEFAULT_FALLBACK_SCENARIO])["forecast"])


def get_current_weather(location_text: str, lat=None, lon=None, scenario: str = DEFAULT_FALLBACK_SCENARIO):
    api_key = current_app.config.get("OPENWEATHER_API_KEY")
    if not api_key:
        return _fallback_current(scenario, location_text)

    try:
        params = {"appid": api_key, "units": "metric"}
        if lat is not None and lon is not None:
            params.update({"lat": lat, "lon": lon})
        else:
            params["q"] = location_text

        resp = requests.get(OPENWEATHER_URL, params=params, timeout=6)
        resp.raise_for_status()
        payload = resp.json()

        return {
            "location": location_text,
            "temperature_c": payload["main"]["temp"],
            "feels_like_c": payload["main"].get("feels_like"),
            "humidity_pct": payload["main"]["humidity"],
            "wind_speed_kmh": round(payload.get("wind", {}).get("speed", 0) * 3.6, 1),
            "rainfall_mm": payload.get("rain", {}).get("1h", 0.0),
            "weather_condition": payload["weather"][0]["description"].title(),
            "rain_probability_pct": None,  # not provided by the /weather endpoint
            "is_fallback": False,
            "fetched_at": datetime.now(timezone.utc).isoformat(),
        }
    except (requests.RequestException, KeyError, ValueError) as exc:
        current_app.logger.warning("Weather API unavailable, using fallback: %s", exc)
        return _fallback_current(scenario, location_text)


def get_forecast(location_text: str, lat=None, lon=None, scenario: str = DEFAULT_FALLBACK_SCENARIO):
    api_key = current_app.config.get("OPENWEATHER_API_KEY")
    if not api_key:
        return _fallback_forecast(scenario)

    try:
        params = {"appid": api_key, "units": "metric", "cnt": 24}  # ~3 days, 3-hr steps
        if lat is not None and lon is not None:
            params.update({"lat": lat, "lon": lon})
        else:
            params["q"] = location_text

        resp = requests.get(OPENWEATHER_FORECAST_URL, params=params, timeout=6)
        resp.raise_for_status()
        payload = resp.json()

        daily = {}
        for entry in payload.get("list", []):
            day = entry["dt_txt"].split(" ")[0]
            daily.setdefault(day, []).append(entry)

        forecast = []
        for day, entries in list(daily.items())[:3]:
            temps = [e["main"]["temp"] for e in entries]
            rain_prob = max((e.get("pop", 0) for e in entries), default=0) * 100
            forecast.append(
                {
                    "day": day,
                    "condition": entries[0]["weather"][0]["description"].title(),
                    "temp_high_c": round(max(temps), 1),
                    "temp_low_c": round(min(temps), 1),
                    "rain_probability_pct": round(rain_prob, 0),
                }
            )
        return forecast
    except (requests.RequestException, KeyError, ValueError) as exc:
        current_app.logger.warning("Forecast API unavailable, using fallback: %s", exc)
        return _fallback_forecast(scenario)


def significant_conditions(current: dict) -> list:
    """Flag noteworthy weather conditions from the current reading."""
    flags = []
    if current.get("rainfall_mm", 0) and current["rainfall_mm"] > 20:
        flags.append("Heavy rainfall")
    if current.get("temperature_c", 0) and current["temperature_c"] >= 38:
        flags.append("Extreme heat")
    if current.get("wind_speed_kmh", 0) and current["wind_speed_kmh"] >= 40:
        flags.append("Strong wind")
    return flags
