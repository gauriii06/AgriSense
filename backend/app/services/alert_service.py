"""
Orchestrates the alert engine against real data and persists results with
deduplication + auto-resolution. Used by both the dashboard summary and
the dedicated /alerts endpoints so there is exactly one code path that
creates/resolves alerts — the dashboard's "priority alert" is always a
real, persisted row with an id that can be read/dismissed, not an
ephemeral duplicate of the same logic.
"""
from app.db import query_one, query_all, execute
from app.services import weather_service, market_service
from app.services.pest_engine import predict_pest_risk
from app.services.alert_engine import generate_alerts


def sync_alerts_for_crop(user_id, crop, weather_current, weather_forecast, reading, pest_risk):
    """
    Evaluate alert rules for this crop and persist any new ones
    (skipping duplicates of already-active alerts), then auto-resolve any
    previously active alert whose condition no longer holds. Returns the
    current list of active alerts for this crop, most severe first.
    """
    market_summary = market_service.get_market_summary(crop["crop_ref_id"])
    market_hit = None
    if market_summary:
        market_hit = market_service.check_target_price(user_id, crop["crop_ref_id"], market_summary["best_price"])

    candidate_alerts = generate_alerts(
        weather_current, weather_forecast, reading, pest_risk, market_hit, crop["crop_name"], crop["id"]
    )

    for a in candidate_alerts:
        existing_active = query_one(
            "SELECT id FROM alerts WHERE user_id = %s AND dedup_key = %s AND status = 'active'",
            (user_id, a["dedup_key"]),
        )
        if existing_active:
            continue
        alert_id = execute(
            """INSERT INTO alerts (user_id, farmer_crop_id, type, severity, title, message, recommended_action, dedup_key, status)
               VALUES (%s, %s, %s, %s, %s, %s, %s, %s, 'active')""",
            (user_id, crop["id"], a["type"], a["severity"], a["title"], a["message"], a["recommended_action"], a["dedup_key"]),
        )
        execute("INSERT INTO notifications (user_id, alert_id) VALUES (%s, %s)", (user_id, alert_id))

    candidate_keys = {a["dedup_key"] for a in candidate_alerts}
    currently_active = query_all(
        "SELECT * FROM alerts WHERE user_id = %s AND farmer_crop_id = %s AND status = 'active' "
        "ORDER BY FIELD(severity,'critical','high','moderate','low','informational'), created_at DESC",
        (user_id, crop["id"]),
    )
    for row in currently_active:
        if row["dedup_key"] not in candidate_keys:
            execute("UPDATE alerts SET status = 'resolved', resolved_at = NOW() WHERE id = %s", (row["id"],))

    # Re-fetch so the resolved ones above are excluded from what we return.
    return query_all(
        "SELECT * FROM alerts WHERE user_id = %s AND farmer_crop_id = %s AND status = 'active' "
        "ORDER BY FIELD(severity,'critical','high','moderate','low','informational'), created_at DESC",
        (user_id, crop["id"]),
    )
