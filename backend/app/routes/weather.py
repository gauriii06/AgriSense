from flask import Blueprint, jsonify, g, request

from app.auth_utils import login_required
from app.db import query_one
from app.services import weather_service

weather_bp = Blueprint("weather", __name__)


def _user_location():
    user = query_one("SELECT location, state, district FROM users WHERE id = %s", (g.user_id,))
    if not user:
        return "India"
    return user.get("location") or f"{user.get('district', '')}, {user.get('state', '')}".strip(", ")


@weather_bp.get("/current")
@login_required
def current_weather():
    location = request.args.get("location") or _user_location()
    data = weather_service.get_current_weather(location)
    data["significant_conditions"] = weather_service.significant_conditions(data)
    return jsonify({"success": True, "data": data})


@weather_bp.get("/forecast")
@login_required
def forecast():
    location = request.args.get("location") or _user_location()
    data = weather_service.get_forecast(location)
    return jsonify({"success": True, "data": data})
