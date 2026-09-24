import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'api_config.dart';

class AuthService {
  static String? verificationCode;
  static String? passwordResetVerificationCode;
  static const String _accessTokenKey = 'auth.accessToken';
  static const String _refreshTokenKey = 'auth.refreshToken';

  static String? accessToken;
  static String? refreshToken;
  static String? lastErrorMessage;

  static Map<String, String> get authHeaders {
    final token = accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Future<bool> login(String email, String password) async {
    lastErrorMessage = null;

    try {
      final response = await http.post(
        ApiConfig.uri('/auth/login'),
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

      lastErrorMessage = response.statusCode == 401
          ? 'Неверный email или пароль'
          : _messageFromResponse(response, 'Не удалось войти');
    } catch (e) {
      lastErrorMessage =
          'Не удалось подключиться к серверу ${ApiConfig.baseUrl}: $e';
    }

    return false;
  }

  static Future<bool> register(
    String email,
    String password, {
    String? name,
  }) async {
    lastErrorMessage = null;

    try {
      final response = await http.post(
        ApiConfig.uri('/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password,
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        }),
      );

      if (response.statusCode != 200 && response.statusCode != 201) {
        lastErrorMessage = response.statusCode == 409
            ? 'Данный почтовый адрес уже используется'
            : _messageFromResponse(response, 'Не удалось зарегистрироваться');
        return false;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      verificationCode = data['verificationCode'] as String?;
      // Вход выполняется только после подтверждения e-mail через /auth/verify.
      return true;
    } catch (e) {
      lastErrorMessage =
          'Не удалось подключиться к серверу ${ApiConfig.baseUrl}: $e';
      return false;
    }
  }

  static Future<bool> verifyEmail(String email, String code) async {
    lastErrorMessage = null;

    try {
      final response = await http.post(
        ApiConfig.uri('/auth/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        accessToken = data['accessToken'] as String?;
        refreshToken = data['refreshToken'] as String?;
        await _persistTokens();
        return accessToken != null;
      }

      lastErrorMessage = _messageFromResponse(
        response,
        'Не удалось подтвердить e-mail',
      );
    } catch (e) {
      lastErrorMessage =
          'Не удалось подключиться к серверу ${ApiConfig.baseUrl}: $e';
    }

    return false;
  }

  static Future<bool> requestPasswordReset(String email) async {
    lastErrorMessage = null;

    try {
      final response = await http.post(
        ApiConfig.uri('/auth/password-reset/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        passwordResetVerificationCode = data['verificationCode'] as String?;
        return true;
      }

      lastErrorMessage = _messageFromResponse(
        response,
        'Не удалось отправить код восстановления',
      );
    } catch (e) {
      lastErrorMessage =
          'Не удалось подключиться к серверу ${ApiConfig.baseUrl}: $e';
    }

    return false;
  }

  static Future<String?> verifyPasswordResetCode(
    String email,
    String code,
  ) async {
    lastErrorMessage = null;

    try {
      final response = await http.post(
        ApiConfig.uri('/auth/password-reset/verify'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'code': code.trim()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['resetToken'] as String?;
      }

      lastErrorMessage = _messageFromResponse(response, 'Неверный код');
    } catch (e) {
      lastErrorMessage =
          'Не удалось подключиться к серверу ${ApiConfig.baseUrl}: $e';
    }

    return null;
  }

  static Future<bool> completePasswordReset(
    String resetToken,
    String password,
  ) async {
    lastErrorMessage = null;

    try {
      final response = await http.post(
        ApiConfig.uri('/auth/password-reset/complete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'resetToken': resetToken, 'password': password}),
      );

      if (response.statusCode == 200) return true;

      lastErrorMessage = _messageFromResponse(
        response,
        'Не удалось изменить пароль',
      );
    } catch (e) {
      lastErrorMessage =
          'Не удалось подключиться к серверу ${ApiConfig.baseUrl}: $e';
    }

    return false;
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
      ApiConfig.uri('/auth/refresh'),
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
        ApiConfig.uri('/auth/me'),
        headers: authHeaders,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static String _messageFromResponse(http.Response response, String fallback) {
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) {
        final message = body['statusMessage'] ?? body['message'];
        if (message is String && message.isNotEmpty) return message;
      }
    } catch (_) {
      // Keep the fallback below for non-JSON error responses.
    }
    return '$fallback (${response.statusCode})';
  }
}
