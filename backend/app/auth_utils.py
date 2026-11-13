import datetime
from functools import wraps

import bcrypt
import jwt
from flask import current_app, jsonify, request, g


def hash_password(plain_password: str) -> str:
    return bcrypt.hashpw(plain_password.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")


def verify_password(plain_password: str, password_hash: str) -> bool:
    try:
        return bcrypt.checkpw(plain_password.encode("utf-8"), password_hash.encode("utf-8"))
    except ValueError:
        return False


def generate_token(user_id: int) -> str:
    cfg = current_app.config
    payload = {
        "user_id": user_id,
        "exp": datetime.datetime.utcnow() + datetime.timedelta(hours=cfg["JWT_EXPIRY_HOURS"]),
        "iat": datetime.datetime.utcnow(),
    }
    return jwt.encode(payload, cfg["JWT_SECRET_KEY"], algorithm="HS256")


def decode_token(token: str):
    cfg = current_app.config
    return jwt.decode(token, cfg["JWT_SECRET_KEY"], algorithms=["HS256"])


def login_required(f):
    """Decorator: requires a valid 'Authorization: Bearer <token>' header."""

    @wraps(f)
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get("Authorization", "")
        if not auth_header.startswith("Bearer "):
            return jsonify({"success": False, "error": "Missing or invalid Authorization header"}), 401
        token = auth_header.split(" ", 1)[1]
        try:
            payload = decode_token(token)
        except jwt.ExpiredSignatureError:
            return jsonify({"success": False, "error": "Token expired, please log in again"}), 401
        except jwt.InvalidTokenError:
            return jsonify({"success": False, "error": "Invalid token"}), 401
        g.user_id = payload["user_id"]
        return f(*args, **kwargs)

    return wrapper
