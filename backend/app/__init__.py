from flask import Flask, jsonify, send_from_directory
from flask_cors import CORS
import os

from app.config import Config
from app import db as db_module


def create_app():
    app = Flask(__name__)
    app.config.from_object(Config)

    CORS(app)  # Flutter app runs on a different origin/port during dev
    db_module.init_app(app)

    # ---- Blueprints ----
    from app.routes.auth import auth_bp
    from app.routes.profile import profile_bp
    from app.routes.farms import farms_bp
    from app.routes.crops import crops_bp
    from app.routes.weather import weather_bp
    from app.routes.field import field_bp
    from app.routes.pests import pests_bp
    from app.routes.disease import disease_bp
    from app.routes.market import market_bp
    from app.routes.recommendations import recommendations_bp
    from app.routes.alerts import alerts_bp
    from app.routes.dashboard import dashboard_bp
    from app.routes.admin import admin_bp

    app.register_blueprint(auth_bp, url_prefix="/api/auth")
    app.register_blueprint(profile_bp, url_prefix="/api/profile")
    app.register_blueprint(farms_bp, url_prefix="/api/farms")
    app.register_blueprint(crops_bp, url_prefix="/api/crops")
    app.register_blueprint(weather_bp, url_prefix="/api/weather")
    app.register_blueprint(field_bp, url_prefix="/api/field")
    app.register_blueprint(pests_bp, url_prefix="/api/pests")
    app.register_blueprint(disease_bp, url_prefix="/api/disease")
    app.register_blueprint(market_bp, url_prefix="/api/market")
    app.register_blueprint(recommendations_bp, url_prefix="/api/recommendations")
    app.register_blueprint(alerts_bp, url_prefix="/api/alerts")
    app.register_blueprint(dashboard_bp, url_prefix="/api/dashboard")
    app.register_blueprint(admin_bp, url_prefix="/api/admin")

    @app.get("/api/health")
    def health():
        return jsonify({"success": True, "status": "AgriSense backend is running"})

    @app.get("/admin")
    def admin_panel():
        admin_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "admin_static")
        return send_from_directory(admin_dir, "index.html")

    @app.errorhandler(404)
    def not_found(e):
        return jsonify({"success": False, "error": "Resource not found"}), 404

    @app.errorhandler(500)
    def server_error(e):
        return jsonify({"success": False, "error": "Internal server error"}), 500

    return app
