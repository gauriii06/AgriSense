import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_constants.dart';

/// Thrown for any API failure so screens can show one consistent message.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.tokenKey);
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }

  bool get isLoggedIn => _token != null;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('${AppConstants.apiBaseUrl}$path');
    if (query == null) return base;
    return base.replace(queryParameters: query.map((k, v) => MapEntry(k, '$v')));
  }

  Future<Map<String, dynamic>> _handle(http.Response resp) async {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Unexpected server response. Please try again.');
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return body;
    }
    throw ApiException(body['error'] ?? 'Something went wrong', statusCode: resp.statusCode);
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query}) async {
    try {
      final resp = await http.get(_uri(path, query), headers: _headers).timeout(const Duration(seconds: 12));
      return await _handle(resp);
    } on SocketException {
      throw ApiException('Cannot reach the AgriSense server. Check your connection and backend URL.');
    } on http.ClientException {
      throw ApiException('Network error. Please try again.');
    }
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> data) async {
    try {
      final resp = await http
          .post(_uri(path), headers: _headers, body: jsonEncode(data))
          .timeout(const Duration(seconds: 12));
      return await _handle(resp);
    } on SocketException {
      throw ApiException('Cannot reach the AgriSense server. Check your connection and backend URL.');
    } on http.ClientException {
      throw ApiException('Network error. Please try again.');
    }
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> data) async {
    try {
      final resp = await http
          .put(_uri(path), headers: _headers, body: jsonEncode(data))
          .timeout(const Duration(seconds: 12));
      return await _handle(resp);
    } on SocketException {
      throw ApiException('Cannot reach the AgriSense server. Check your connection and backend URL.');
    }
  }

  /// Multipart upload, used for crop disease images.
  Future<Map<String, dynamic>> uploadImage(String path, Map<String, String> fields, File imageFile) async {
    try {
      final request = http.MultipartRequest('POST', _uri(path));
      if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
      request.fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      final streamed = await request.send().timeout(const Duration(seconds: 20));
      final resp = await http.Response.fromStream(streamed);
      return await _handle(resp);
    } on SocketException {
      throw ApiException('Cannot reach the AgriSense server. Check your connection and backend URL.');
    }
  }
}
