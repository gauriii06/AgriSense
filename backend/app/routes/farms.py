from flask import Blueprint, jsonify, request, g

from app.db import query_all, execute
from app.auth_utils import login_required

farms_bp = Blueprint("farms", __name__)


@farms_bp.get("")
@login_required
def list_farms():
    farms = query_all("SELECT * FROM farms WHERE user_id = %s ORDER BY created_at DESC", (g.user_id,))
    return jsonify({"success": True, "data": farms})


@farms_bp.post("")
@login_required
def create_farm():
    data = request.get_json(silent=True) or {}
    farm_name = (data.get("farm_name") or "").strip()
    if not farm_name:
        return jsonify({"success": False, "error": "farm_name is required"}), 400

    farm_id = execute(
        """INSERT INTO farms (user_id, farm_name, farm_size_acres, latitude, longitude, location_text)
           VALUES (%s, %s, %s, %s, %s, %s)""",
        (
            g.user_id,
            farm_name,
            data.get("farm_size_acres"),
            data.get("latitude"),
            data.get("longitude"),
            data.get("location_text"),
        ),
    )
    return jsonify({"success": True, "farm_id": farm_id}), 201
