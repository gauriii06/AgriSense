from flask import Blueprint, jsonify, request, g

from app.db import query_one, execute
from app.auth_utils import login_required

profile_bp = Blueprint("profile", __name__)


@profile_bp.get("")
@login_required
def get_profile():
    user = query_one(
        """SELECT id, full_name, email, mobile, location, state, district,
                  preferred_language, created_at FROM users WHERE id = %s""",
        (g.user_id,),
    )
    if not user:
        return jsonify({"success": False, "error": "Profile not found"}), 404

    farms = query_one("SELECT SUM(farm_size_acres) AS total_acres FROM farms WHERE user_id = %s", (g.user_id,))
    user["total_farm_size_acres"] = float(farms["total_acres"]) if farms and farms["total_acres"] else 0
    return jsonify({"success": True, "data": user})


@profile_bp.put("")
@login_required
def update_profile():
    data = request.get_json(silent=True) or {}
    allowed = ["full_name", "location", "state", "district", "preferred_language"]
    fields, values = [], []
    for key in allowed:
        if key in data:
            fields.append(f"{key} = %s")
            values.append(data[key])

    if not fields:
        return jsonify({"success": False, "error": "No valid fields to update"}), 400

    values.append(g.user_id)
    execute(f"UPDATE users SET {', '.join(fields)} WHERE id = %s", tuple(values))
    return jsonify({"success": True, "message": "Profile updated"})
