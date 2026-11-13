from flask import Blueprint, jsonify, request, g

from app.db import query_one, execute
from app.auth_utils import hash_password, verify_password, generate_token, login_required

auth_bp = Blueprint("auth", __name__)


@auth_bp.post("/register")
def register():
    data = request.get_json(silent=True) or {}
    full_name = (data.get("full_name") or "").strip()
    email = (data.get("email") or "").strip() or None
    mobile = (data.get("mobile") or "").strip() or None
    password = data.get("password") or ""
    location = data.get("location")
    preferred_language = data.get("preferred_language", "en")

    if not full_name or not password or (not email and not mobile):
        return jsonify({"success": False, "error": "Full name, password, and email or mobile are required"}), 400
    if len(password) < 6:
        return jsonify({"success": False, "error": "Password must be at least 6 characters"}), 400

    existing = query_one(
        "SELECT id FROM users WHERE (email IS NOT NULL AND email = %s) OR (mobile IS NOT NULL AND mobile = %s)",
        (email, mobile),
    )
    if existing:
        return jsonify({"success": False, "error": "An account with this email/mobile already exists"}), 409

    user_id = execute(
        """INSERT INTO users (full_name, email, mobile, password_hash, location, preferred_language)
           VALUES (%s, %s, %s, %s, %s, %s)""",
        (full_name, email, mobile, hash_password(password), location, preferred_language),
    )
    token = generate_token(user_id)
    return jsonify({"success": True, "token": token, "user_id": user_id}), 201


@auth_bp.post("/login")
def login():
    data = request.get_json(silent=True) or {}
    identifier = (data.get("email") or data.get("mobile") or data.get("identifier") or "").strip()
    password = data.get("password") or ""

    if not identifier or not password:
        return jsonify({"success": False, "error": "Email/mobile and password are required"}), 400

    user = query_one(
        "SELECT id, password_hash FROM users WHERE email = %s OR mobile = %s",
        (identifier, identifier),
    )
    if not user or not verify_password(password, user["password_hash"]):
        return jsonify({"success": False, "error": "Invalid credentials"}), 401

    token = generate_token(user["id"])
    return jsonify({"success": True, "token": token, "user_id": user["id"]})


@auth_bp.post("/logout")
@login_required
def logout():
    # Stateless JWT: logout is handled client-side by discarding the token.
    return jsonify({"success": True, "message": "Logged out"})


@auth_bp.get("/me")
@login_required
def me():
    user = query_one(
        "SELECT id, full_name, email, mobile, location, state, district, preferred_language FROM users WHERE id = %s",
        (g.user_id,),
    )
    if not user:
        return jsonify({"success": False, "error": "User not found"}), 404
    return jsonify({"success": True, "data": user})
