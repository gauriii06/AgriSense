"""
Creates a demo farmer account for local development/demos.
Run with: ./venv/bin/python seed_demo_user.py
"""
from app import create_app
from app.db import query_one, execute
from app.auth_utils import hash_password

app = create_app()

with app.app_context():
    existing = query_one("SELECT id FROM users WHERE email = %s", ("demo@agrisense.app",))
    if existing:
        print("Demo user already exists (demo@agrisense.app / demo1234)")
    else:
        user_id = execute(
            """INSERT INTO users (full_name, email, password_hash, location, state, district, preferred_language)
               VALUES (%s, %s, %s, %s, %s, %s, %s)""",
            ("Gauri Patil", "demo@agrisense.app", hash_password("demo1234"),
             "Nashik, Maharashtra", "Maharashtra", "Nashik", "en"),
        )
        farm_id = execute(
            "INSERT INTO farms (user_id, farm_name, farm_size_acres, location_text) VALUES (%s, %s, %s, %s)",
            (user_id, "Tomato Farm", 5, "Nashik"),
        )
        crop = query_one("SELECT id FROM crops WHERE name = %s", ("Tomato",))
        farmer_crop_id = execute(
            """INSERT INTO farmer_crops (user_id, farm_id, crop_id, variety, sowing_date, farm_size_acres, growth_stage, is_active)
               VALUES (%s, %s, %s, %s, %s, %s, %s, TRUE)""",
            (user_id, farm_id, crop["id"], "Roma", "2026-06-01", 5, "flowering"),
        )
        execute(
            """INSERT INTO field_readings
               (farmer_crop_id, soil_moisture_pct, soil_temperature_c, air_temperature_c, humidity_pct, rainfall_mm, light_intensity_lux, source)
               VALUES (%s, %s, %s, %s, %s, %s, %s, 'demo')""",
            (farmer_crop_id, 31, 28, 32, 82, 5, 15000),
        )
        print("Created demo user: demo@agrisense.app / demo1234")
        print(f"  user_id={user_id}, farm_id={farm_id}, farmer_crop_id={farmer_crop_id}")
