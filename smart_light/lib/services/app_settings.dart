import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { dark, light, emerald, indigo }

class AppSettings extends ChangeNotifier {
  AppSettings._(
    this._preferences,
    this._theme,
    this._locale,
    this._lightingAdviceEnabled,
  );

  static const _themeKey = 'settings.themeMode';
  static const _localeKey = 'settings.locale';
  static const _lightingAdviceKey = 'settings.lightingAdviceEnabled';
  static late AppSettings instance;

  final SharedPreferences _preferences;
  AppTheme _theme;
  Locale _locale;
  bool _lightingAdviceEnabled;

  AppTheme get theme => _theme;
  ThemeMode get themeMode =>
      _theme == AppTheme.dark ? ThemeMode.dark : ThemeMode.light;
  Locale get locale => _locale;
  bool get lightingAdviceEnabled => _lightingAdviceEnabled;

  double lastLampBrightness(String deviceId, {required double fallback}) {
    final saved = _preferences.getInt('lamp.$deviceId.lastBrightness');
    if (saved != null && saved > 0 && saved <= 255) return saved / 255;
    return fallback.isFinite && fallback > 0 ? fallback.clamp(0.0, 1.0) : 0.5;
  }

  Future<void> rememberLampBrightness(
    String deviceId,
    double brightness,
  ) async {
    if (!brightness.isFinite || brightness <= 0) return;
    final value = (brightness.clamp(0.0, 1.0) * 255).round();
    final key = 'lamp.$deviceId.lastBrightness';
    if (_preferences.getInt(key) != value)
      await _preferences.setInt(key, value);
  }

  static Future<AppSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedTheme = preferences.getString(_themeKey) ?? AppTheme.dark.name;
    final theme = savedTheme == 'green'
        ? AppTheme.emerald
        : AppTheme.values.byName(savedTheme);
    final languageCode = preferences.getString(_localeKey) ?? 'ru';
    final settings = AppSettings._(
      preferences,
      theme,
      Locale(languageCode),
      preferences.getBool(_lightingAdviceKey) ?? true,
    );
    instance = settings;
    return settings;
  }

  Future<void> setTheme(AppTheme theme) async {
    if (_theme == theme) return;
    _theme = theme;
    notifyListeners();
    await _preferences.setString(_themeKey, theme.name);
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    await _preferences.setString(_localeKey, locale.languageCode);
  }

  Future<void> setLightingAdviceEnabled(bool enabled) async {
    if (_lightingAdviceEnabled == enabled) return;
    _lightingAdviceEnabled = enabled;
    notifyListeners();
    await _preferences.setBool(_lightingAdviceKey, enabled);
  }
}
