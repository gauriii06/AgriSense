import '../services/api_service.dart';

class AuthService {
  final ApiService _api = ApiService();

  Future<void> register({
    required String fullName,
    String? email,
    String? mobile,
    required String password,
    String? location,
    String preferredLanguage = 'en',
  }) async {
    final res = await _api.post('/auth/register', {
      'full_name': fullName,
      if (email != null && email.isNotEmpty) 'email': email,
      if (mobile != null && mobile.isNotEmpty) 'mobile': mobile,
      'password': password,
      'location': location,
      'preferred_language': preferredLanguage,
    });
    await _api.saveToken(res['token']);
  }

  Future<void> login({required String identifier, required String password}) async {
    final res = await _api.post('/auth/login', {
      'email': identifier,
      'mobile': identifier,
      'password': password,
    });
    await _api.saveToken(res['token']);
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout', {});
    } catch (_) {
      // Even if the call fails, clear the local token.
    }
    await _api.clearToken();
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _api.get('/auth/me');
    return res['data'];
  }
}
