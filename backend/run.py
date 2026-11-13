from app import create_app

app = create_app()

if __name__ == "__main__":
    # host=0.0.0.0 so the Android emulator (10.0.2.2) / physical device can reach it
    app.run(host="0.0.0.0", port=5000, debug=True, use_reloader=False)
