/// App-wide constants.
///
/// IMPORTANT — Android emulator networking:
/// The Android emulator does NOT see your development machine as
/// `localhost`. Use `10.0.2.2` instead, which the emulator maps back to
/// the host machine's `localhost`. For a physical device on the same
/// Wi-Fi, use your machine's LAN IP (e.g. 192.168.x.x) instead.
///
/// Change [apiBaseUrl] below to match how you're running the app:
///   - Android emulator  -> http://10.0.2.2:5000/api
///   - Physical device   -> http://<your-computer-LAN-IP>:5000/api
///   - iOS simulator     -> http://127.0.0.1:5000/api
class AppConstants {
  static const String apiBaseUrl = 'http://127.0.0.1:5000/api';
  static const String appName = 'AgriSense';

  // SharedPreferences keys
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'user_id';
}
