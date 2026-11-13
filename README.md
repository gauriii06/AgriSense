# AgriSense

AgriSense is a mobile AI-enabled precision agriculture decision-support system. It doesn't just show raw sensor and weather numbers — it turns them into plain-language recommendations a farmer can act on: *what's happening, why it matters, what to do, and when.*

## 1. Project Overview

A farmer registers, adds a farm and crop, and from then on the app continuously combines:

- Weather (current + forecast)
- Field conditions (soil moisture, temperature, humidity, rainfall, light)
- A rule-based pest-risk engine
- An irrigation decision engine
- Crop disease image identification
- Market price intelligence
- A centralized recommendation engine
- A personalized alert/notification engine

into one dashboard and a set of focused screens.

**Built and verified in this repository:** the Flask + MySQL backend runs and was tested end-to-end (register → login → create farm → add crop → dashboard → weather → field conditions → pest risk → recommendations → market → disease image upload → alerts → notifications). The Flutter mobile app source is complete and ready to run, but requires the Flutter/Android SDK to build — see [Known Limitations](#8-known-limitations--honesty-notes) below.

## 2. Architecture

```
Flutter (Android) App  <--REST/JSON-->  Flask Backend  <-->  MySQL
                                              |
                                              +--> OpenWeatherMap (or fallback dataset)
                                              +--> Market demo data (Agmarknet-ready)
```

No Docker, no microservices, no message queues — a single Flask process talking to a single MySQL database, matching the project's "don't overengineer" requirement.

## 3. Technology Stack

- **Mobile:** Flutter + Dart (Android)
- **Backend:** Python 3 + Flask (REST API)
- **Database:** MySQL 8
- **ML/rules:** Python — deterministic rule-based pest-risk and irrigation engines (documented in code, structured so a trained scikit-learn model can be swapped in later)
- **Computer Vision:** Disease-identification workflow is fully built end-to-end, but uses a clearly-labeled deterministic **demo classifier** in place of a trained TensorFlow/Keras model — see [Known Limitations](#8-known-limitations--honesty-notes)

## 4. Folder Structure

```
agrisense/
├── backend/
│   ├── app/
│   │   ├── __init__.py         # Flask app factory
│   │   ├── config.py           # env-based config
│   │   ├── db.py               # lightweight MySQL access layer
│   │   ├── auth_utils.py       # password hashing, JWT
│   │   ├── routes/             # one file per API area
│   │   └── services/           # weather, pest, irrigation, market,
│   │                           # disease, recommendation, alert engines
│   ├── admin_static/index.html # simple functional admin panel
│   ├── requirements.txt
│   ├── .env.example
│   └── run.py
├── database/
│   ├── schema.sql              # full MySQL schema
│   └── seed_data.sql           # demo crops, pests, diseases, market prices
└── mobile/
    └── lib/
        ├── core/                # constants, theme, routes
        ├── models/
        ├── services/            # API clients per domain
        ├── providers/           # app state (auth, active crop)
        ├── screens/             # one folder per feature area
        └── widgets/             # shared UI (SectionCard, StatusPill, etc.)
```

## 5. Backend Setup (Flask + MySQL)

### 5.1 Install MySQL and create the database

```bash
# Ubuntu/Debian
sudo apt-get install mysql-server
sudo service mysql start

mysql -u root -p < database/schema.sql
mysql -u root -p agrisense < database/seed_data.sql
```

Create a dedicated app user (recommended over using root):

```sql
CREATE USER 'agrisense_app'@'%' IDENTIFIED WITH mysql_native_password BY 'choose_a_password';
GRANT ALL PRIVILEGES ON agrisense.* TO 'agrisense_app'@'%';
FLUSH PRIVILEGES;
```

### 5.2 Set up the Python environment

```bash
cd backend
python3 -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

### 5.3 Configure environment variables

```bash
cp .env.example .env
```

Edit `.env`:

```
DB_USER=agrisense_app
DB_PASSWORD=choose_a_password
DB_NAME=agrisense
SECRET_KEY=<generate a long random string>
JWT_SECRET_KEY=<generate a different long random string>

# Optional — leave blank to use built-in fallback data
OPENWEATHER_API_KEY=
AGMARKNET_API_KEY=
```

Never commit `.env`.

### 5.4 Run the backend

```bash
python run.py
```

The server listens on `0.0.0.0:5000`. Verify it's up:

```bash
curl http://127.0.0.1:5000/api/health
```

The simple admin panel is served at `http://127.0.0.1:5000/admin`.

## 6. Flutter App Setup

### 6.1 Prerequisites

- Flutter SDK (stable channel) — [flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
- Android Studio with the Android SDK and an emulator (or a physical Android device with USB debugging enabled)
- Run `flutter doctor` and resolve any ✗ items before continuing

### 6.2 Install dependencies

```bash
cd mobile
flutter pub get
```

### 6.3 Configure the backend URL — this is the step people usually get wrong

Edit `mobile/lib/core/constants/app_constants.dart`:

| Running on...                     | `apiBaseUrl` should be                          |
|-----------------------------------|--------------------------------------------------|
| Android Emulator                  | `http://10.0.2.2:5000/api`                       |
| Physical Android device (same Wi-Fi) | `http://<your-computer's-LAN-IP>:5000/api`   |
| iOS Simulator                     | `http://127.0.0.1:5000/api`                      |

**The Android emulator does not treat `localhost` as your development machine.** `10.0.2.2` is a special alias the emulator maps back to your host machine's `localhost`. This trips up almost everyone the first time.

For a physical device, find your machine's LAN IP (`ipconfig` on Windows, `ifconfig`/`ip addr` on Mac/Linux) and make sure the device and computer are on the same network. You'll also need `flask run --host=0.0.0.0` (already the default in `run.py`) so the backend accepts connections from other devices.

### 6.4 Run the app

```bash
flutter run
```

Select your emulator or connected device when prompted.

## 7. Demo Flow (End-to-End)

1. Register a new farmer account
2. Log in
3. Add a crop (this also lets you create your first farm inline)
4. Activate the crop
5. View the Dashboard — weather, field conditions, pest risk, market, priority alert, and top recommendation all in one screen
6. Tap into Weather, Field Conditions, Pest Risk, Market, or Recommendations for full detail
7. Use "Check Disease" to capture/upload a crop photo and see a result
8. Check Notifications for alert history

This exact flow was tested against the running backend in this repository using curl before the Flutter screens were written, so the API contract each screen relies on is confirmed working.

## 8. Known Limitations & Honesty Notes

In the interest of the project's own stated principle — *don't claim something works or is accurate when it hasn't been verified* — here's what's real vs. simplified in this build:

- **Weather:** Uses OpenWeatherMap if `OPENWEATHER_API_KEY` is set; otherwise falls back to a structured, clearly-labeled fallback dataset (`is_fallback: true` in every response) so the app stays demonstrable without a key.
- **Pest risk:** A deterministic, rule-based engine — not a trained ML model, and not randomized. Every score is traceable to specific contributing conditions (temperature range, humidity, rainfall, crop susceptibility). Structured so a trained scikit-learn model can later replace `pest_engine.score_pest()` without touching the rest of the app.
- **Disease identification:** The full workflow (capture → upload → backend inference → result with treatment) is real and working. However, there is no trained TensorFlow/Keras model or labeled image dataset in this environment. The classifier is a deterministic (not random) placeholder that always discloses `is_demo_model: true` and an explanatory note in its response. Swapping in a real trained model only requires implementing the `MODEL_PATH` branch in `disease_service.py` — routes and the Flutter UI don't need to change.
- **Market prices:** Demo data (clearly flagged `is_demo: true` in the schema), not a live Agmarknet feed. The service layer is structured so a live feed can populate the same table without app changes.
- **Field readings:** There's no physical sensor hardware in this project. Field conditions are logged through a `POST /api/field/readings` endpoint (manual entry today, sensor-feed-ready structure for later).

## 9. Troubleshooting

- **"Cannot reach the AgriSense server"** in the app → check `apiBaseUrl` (see §6.3), and confirm the backend is running and reachable from the device/emulator.
- **MySQL connection errors on backend startup** → confirm MySQL is running (`mysqladmin ping`) and `.env` credentials match a real MySQL user with privileges on the `agrisense` database.
- **`ModuleNotFoundError`** → make sure the virtual environment is activated and `pip install -r requirements.txt` completed without errors.
- **Emulator can't reach backend** → this is almost always the `localhost` vs `10.0.2.2` issue described in §6.3.
- **Empty dashboard / "Add a crop to get started"** → the dashboard only populates once a crop is added and marked active.
