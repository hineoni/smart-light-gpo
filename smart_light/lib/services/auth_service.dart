import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String baseUrl = 'http://172.20.10.13:3000';
  static const String _accessTokenKey = 'auth.accessToken';
  static const String _refreshTokenKey = 'auth.refreshToken';

  static String? accessToken;
  static String? refreshToken;

  static Map<String, String> get authHeaders {
    final token = accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<bool> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      accessToken = data['accessToken'] as String?;
      refreshToken = data['refreshToken'] as String?;
      await _persistTokens();
      return accessToken != null;
    }

    return false;
  }

  static Future<bool> register(
    String email,
    String password, {
    String? name,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      return false;
    }

    return login(email, password);
  }

  static Future<bool> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    accessToken = prefs.getString(_accessTokenKey);
    refreshToken = prefs.getString(_refreshTokenKey);

    if (accessToken == null) return false;
    if (await _checkCurrentUser()) return true;

    return refreshAccessToken();
  }

  static Future<bool> refreshAccessToken() async {
    final token = refreshToken;
    if (token == null) {
      await logout();
      return false;
    }

    final response = await http.post(
      Uri.parse('$baseUrl/auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': token}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      accessToken = data['accessToken'] as String?;
      refreshToken = data['refreshToken'] as String?;
      await _persistTokens();
      return accessToken != null;
    }

    await logout();
    return false;
  }

  static Future<void> logout() async {
    accessToken = null;
    refreshToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessTokenKey);
    await prefs.remove(_refreshTokenKey);
  }

  static Future<void> _persistTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final access = accessToken;
    final refresh = refreshToken;
    if (access != null) {
      await prefs.setString(_accessTokenKey, access);
    }
    if (refresh != null) {
      await prefs.setString(_refreshTokenKey, refresh);
    }
  }

  static Future<bool> _checkCurrentUser() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: authHeaders,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
