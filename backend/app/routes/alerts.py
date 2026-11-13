from flask import Blueprint, jsonify, request, g

from app.db import query_one, query_all, execute
from app.auth_utils import login_required
from app.services import weather_service
from app.services.pest_engine import predict_pest_risk
from app.services.alert_service import sync_alerts_for_crop

alerts_bp = Blueprint("alerts", __name__)


def _active_crop_context(farmer_crop_id, user_id):
    crop = query_one(
        """SELECT fc.*, c.id AS crop_ref_id, c.name AS crop_name FROM farmer_crops fc
           JOIN crops c ON c.id = fc.crop_id
           WHERE fc.user_id = %s AND (%s IS NULL OR fc.id = %s) AND fc.is_active = TRUE
           LIMIT 1""",
        (user_id, farmer_crop_id, farmer_crop_id),
    )
    if not crop:
        return None, None, None, None

    user = query_one("SELECT location FROM users WHERE id = %s", (user_id,))
    scenario = crop.get("weather_scenario", "normal")
    weather_current = weather_service.get_current_weather(user["location"] or "India", scenario=scenario)
    weather_forecast = weather_service.get_forecast(user["location"] or "India", scenario=scenario)
    reading = query_one(
        "SELECT * FROM field_readings WHERE farmer_crop_id = %s ORDER BY recorded_at DESC LIMIT 1",
        (crop["id"],),
    )
    return crop, weather_current, weather_forecast, reading


@alerts_bp.get("/generate")
@login_required
def generate():
    """
    Evaluates alert rules for the active crop and persists any new alerts,
    skipping duplicates of already-active ones (see alert_service for the
    dedup/auto-resolve logic). Returns the alerts newly created by THIS call.
    """
    farmer_crop_id = request.args.get("farmer_crop_id", type=int)
    crop, weather_current, weather_forecast, reading = _active_crop_context(farmer_crop_id, g.user_id)
    if not crop:
        return jsonify({"success": True, "data": [], "message": "No active crop set"})

    temperature = reading["air_temperature_c"] if reading and reading["air_temperature_c"] is not None else weather_current["temperature_c"]
    humidity = reading["humidity_pct"] if reading and reading["humidity_pct"] is not None else weather_current["humidity_pct"]
    rainfall = reading["rainfall_mm"] if reading and reading["rainfall_mm"] is not None else weather_current.get("rainfall_mm", 0)
    pest_risk = predict_pest_risk(crop["crop_name"], temperature, humidity, rainfall)

    before_ids = {a["id"] for a in query_all(
        "SELECT id FROM alerts WHERE user_id = %s AND farmer_crop_id = %s AND status = 'active'", (g.user_id, crop["id"])
    )}
    active_alerts = sync_alerts_for_crop(g.user_id, crop, weather_current, weather_forecast, reading, pest_risk)
    newly_created = [a for a in active_alerts if a["id"] not in before_ids]

    return jsonify({"success": True, "data": newly_created})


@alerts_bp.get("/active")
@login_required
def active_alerts():
    rows = query_all(
        "SELECT * FROM alerts WHERE user_id = %s AND status = 'active' ORDER BY "
        "FIELD(severity,'critical','high','moderate','low','informational'), created_at DESC",
        (g.user_id,),
    )
    return jsonify({"success": True, "data": rows})


@alerts_bp.get("")
@login_required
def list_alerts():
    """Full alert history regardless of status."""
    rows = query_all(
        "SELECT * FROM alerts WHERE user_id = %s ORDER BY created_at DESC LIMIT 50",
        (g.user_id,),
    )
    return jsonify({"success": True, "data": rows})


@alerts_bp.put("/<int:alert_id>/read")
@login_required
def mark_alert_read(alert_id):
    execute(
        "UPDATE alerts SET status = 'read', read_at = NOW() WHERE id = %s AND user_id = %s AND status = 'active'",
        (alert_id, g.user_id),
    )
    execute(
        "UPDATE notifications SET is_read = TRUE, read_at = NOW() WHERE alert_id = %s AND user_id = %s",
        (alert_id, g.user_id),
    )
    return jsonify({"success": True, "message": "Alert marked as read"})


@alerts_bp.put("/<int:alert_id>/dismiss")
@login_required
def dismiss_alert(alert_id):
    """Removes the alert from the active list. It remains in history/notifications."""
    execute(
        "UPDATE alerts SET status = 'dismissed', dismissed_at = NOW() WHERE id = %s AND user_id = %s",
        (alert_id, g.user_id),
    )
    return jsonify({"success": True, "message": "Alert dismissed"})


@alerts_bp.get("/notifications")
@login_required
def notifications():
    rows = query_all(
        """SELECT n.id AS notification_id, n.is_read, n.created_at,
                  a.id AS alert_id, a.status, a.type, a.severity, a.title, a.message, a.recommended_action
           FROM notifications n JOIN alerts a ON a.id = n.alert_id
           WHERE n.user_id = %s
           ORDER BY n.created_at DESC LIMIT 50""",
        (g.user_id,),
    )
    return jsonify({"success": True, "data": rows})


@alerts_bp.put("/notifications/<int:notification_id>/read")
@login_required
def mark_read(notification_id):
    """Kept for backward compatibility with the existing Flutter notifications screen."""
    notif = query_one("SELECT alert_id FROM notifications WHERE id = %s AND user_id = %s", (notification_id, g.user_id))
    execute(
        "UPDATE notifications SET is_read = TRUE, read_at = NOW() WHERE id = %s AND user_id = %s",
        (notification_id, g.user_id),
    )
    if notif:
        execute(
            "UPDATE alerts SET status = 'read', read_at = NOW() WHERE id = %s AND user_id = %s AND status = 'active'",
            (notif["alert_id"], g.user_id),
        )
    return jsonify({"success": True, "message": "Marked as read"})
