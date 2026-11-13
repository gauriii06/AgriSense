from flask import Blueprint, jsonify, request, g

from app.db import query_one, execute
from app.auth_utils import login_required
from app.services import market_service

market_bp = Blueprint("market", __name__)


@market_bp.get("/prices")
@login_required
def prices():
    crop_id = request.args.get("crop_id", type=int)
    if not crop_id:
        return jsonify({"success": False, "error": "crop_id is required"}), 400

    summary = market_service.get_market_summary(crop_id)
    if not summary:
        return jsonify({"success": True, "data": None, "message": "No market data available for this crop"})
    return jsonify({"success": True, "data": summary})


@market_bp.get("/trends")
@login_required
def trends():
    crop_id = request.args.get("crop_id", type=int)
    market_name = request.args.get("market")
    if not crop_id or not market_name:
        return jsonify({"success": False, "error": "crop_id and market are required"}), 400
    trend = market_service.get_price_trend(crop_id, market_name)
    return jsonify({"success": True, "data": {"trend": trend}})


@market_bp.post("/target-price")
@login_required
def set_target_price():
    data = request.get_json(silent=True) or {}
    crop_id = data.get("crop_id")
    target_price = data.get("target_price")
    if not crop_id or not target_price:
        return jsonify({"success": False, "error": "crop_id and target_price are required"}), 400

    existing = query_one(
        "SELECT id FROM target_prices WHERE user_id = %s AND crop_id = %s AND achieved = FALSE",
        (g.user_id, crop_id),
    )
    if existing:
        execute("UPDATE target_prices SET target_price = %s WHERE id = %s", (target_price, existing["id"]))
        return jsonify({"success": True, "message": "Target price updated"})

    target_id = execute(
        "INSERT INTO target_prices (user_id, crop_id, target_price) VALUES (%s, %s, %s)",
        (g.user_id, crop_id, target_price),
    )
    return jsonify({"success": True, "target_id": target_id}), 201
