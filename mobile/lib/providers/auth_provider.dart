import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, loggedIn, loggedOut }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  AuthStatus status = AuthStatus.unknown;
  String? errorMessage;
  bool isLoading = false;

  Future<void> bootstrap() async {
    await ApiService().loadToken();
    status = ApiService().isLoggedIn ? AuthStatus.loggedIn : AuthStatus.loggedOut;
    notifyListeners();
  }

  Future<bool> login(String identifier, String password) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _authService.login(identifier: identifier, password: password);
      status = AuthStatus.loggedIn;
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({
    required String fullName,
    String? email,
    String? mobile,
    required String password,
    String? location,
    String preferredLanguage = 'en',
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      await _authService.register(
        fullName: fullName,
        email: email,
        mobile: mobile,
        password: password,
        location: location,
        preferredLanguage: preferredLanguage,
      );
      status = AuthStatus.loggedIn;
      return true;
    } catch (e) {
      errorMessage = e.toString();
      return false;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    status = AuthStatus.loggedOut;
    notifyListeners();
  }
}
