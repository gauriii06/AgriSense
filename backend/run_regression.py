"""
Regression test runner using Flask's test_client() — exercises the real
routes/services/DB without needing a persistent background HTTP server.
Run with: ./venv/bin/python run_regression.py
"""
import json
import sys

sys.path.insert(0, ".")
from app import create_app

app = create_app()
client = app.test_client()


def call(method, path, token=None, json_body=None):
    headers = {"Authorization": f"Bearer {token}"} if token else {}
    resp = client.open(path, method=method, json=json_body, headers=headers)
    try:
        body = resp.get_json()
    except Exception:
        body = resp.data
    return resp.status_code, body


def p(label, status, body):
    print(f"\n--- {label} [{status}] ---")
    print(json.dumps(body, indent=2, default=str)[:1500])


# 1. Login as the existing demo farmer
status, body = call("POST", "/api/auth/login", json_body={"email": "gauri@example.com", "password": "farmer123"})
p("LOGIN", status, body)
token = body["token"]

# 2. Get crop
status, body = call("GET", "/api/crops", token=token)
p("MY CROPS", status, body)
fc = body["data"][0]
fc_id = fc["id"]
crop_id = fc["crop_id"]
print(f"\nfc_id={fc_id} crop_id={crop_id}")

# TEST A: Dry field -> Irrigation Recommended
status, body = call("POST", "/api/field/readings", token=token, json_body={
    "farmer_crop_id": fc_id, "soil_moisture_pct": 28, "soil_temperature_c": 30,
    "air_temperature_c": 33, "humidity_pct": 50, "rainfall_mm": 0, "light_intensity_lux": 18000,
})
status, body = call("GET", f"/api/recommendations?farmer_crop_id={fc_id}", token=token)
p("TEST A - Recommendations (expect Irrigation Recommended)", status, body)
status, body = call("GET", f"/api/alerts/generate?farmer_crop_id={fc_id}", token=token)
p("TEST A - Alerts generated (expect Irrigation Recommended alert)", status, body)

# TEST B: Wet field + rain forecast -> Not Required + avoid-irrigation alert
status, body = call("POST", "/api/field/readings", token=token, json_body={
    "farmer_crop_id": fc_id, "soil_moisture_pct": 78, "soil_temperature_c": 26,
    "air_temperature_c": 28, "humidity_pct": 85, "rainfall_mm": 15, "light_intensity_lux": 9000,
})
status, body = call("GET", f"/api/recommendations?farmer_crop_id={fc_id}", token=token)
p("TEST B - Recommendations (expect Irrigation Not Required)", status, body)
status, body = call("GET", "/api/alerts/active", token=token)
p("TEST B - Active alerts", status, body)

# TEST C: High pest conditions
status, body = call("POST", "/api/field/readings", token=token, json_body={
    "farmer_crop_id": fc_id, "soil_moisture_pct": 55, "soil_temperature_c": 29,
    "air_temperature_c": 30, "humidity_pct": 88, "rainfall_mm": 18, "light_intensity_lux": 12000,
})
status, body = call("GET", f"/api/pests/risk?farmer_crop_id={fc_id}", token=token)
p("TEST C - Pest risk HIGH conditions", status, body)

# TEST D: Low pest conditions
status, body = call("POST", "/api/field/readings", token=token, json_body={
    "farmer_crop_id": fc_id, "soil_moisture_pct": 55, "soil_temperature_c": 20,
    "air_temperature_c": 19, "humidity_pct": 38, "rainfall_mm": 0, "light_intensity_lux": 12000,
})
status, body = call("GET", f"/api/pests/risk?farmer_crop_id={fc_id}", token=token)
p("TEST D - Pest risk LOW conditions", status, body)

# TEST E: Market target price
status, body = call("POST", "/api/market/target-price", token=token, json_body={"crop_id": crop_id, "target_price": 2800})
p("TEST E - Set target price", status, body)
status, body = call("GET", f"/api/alerts/generate?farmer_crop_id={fc_id}", token=token)
p("TEST E - Alerts generated (expect Target Price Reached)", status, body)

# TEST F: Alert dismissal lifecycle
status, body = call("GET", "/api/alerts/active", token=token)
p("TEST F - Active alerts before dismiss", status, body)
if body["data"]:
    alert_id = body["data"][0]["id"]
    status, body = call("PUT", f"/api/alerts/{alert_id}/dismiss", token=token)
    p(f"TEST F - Dismiss alert {alert_id}", status, body)
    status, body = call("GET", "/api/alerts/active", token=token)
    p("TEST F - Active alerts after dismiss (should be missing that alert)", status, body)
    status, body = call("GET", "/api/alerts", token=token)
    dismissed_present = any(a["id"] == alert_id and a["status"] == "dismissed" for a in body["data"])
    print(f"\nTEST F - Alert still present in full history with status=dismissed: {dismissed_present}")

# TEST G: Dashboard consistency check - dedup, no duplicate alert spam on repeated generate calls
status, body1 = call("GET", f"/api/alerts/generate?farmer_crop_id={fc_id}", token=token)
status, body2 = call("GET", f"/api/alerts/generate?farmer_crop_id={fc_id}", token=token)
print(f"\nTEST G - Dedup check: 1st generate call created {len(body1['data'])} alerts, "
      f"2nd immediate call (same conditions) created {len(body2['data'])} alerts (expect 0)")

status, body = call("GET", "/api/dashboard/summary", token=token)
p("TEST G - Dashboard summary reflects current conditions", status, body)

print("\n\n=== REGRESSION RUN COMPLETE ===")
