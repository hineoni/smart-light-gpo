import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppTheme { dark, light, emerald, indigo }

class AppSettings extends ChangeNotifier {
  AppSettings._(this._preferences, this._theme, this._locale);

  static const _themeKey = 'settings.themeMode';
  static const _localeKey = 'settings.locale';
  static late AppSettings instance;

  final SharedPreferences _preferences;
  AppTheme _theme;
  Locale _locale;

  AppTheme get theme => _theme;
  ThemeMode get themeMode =>
      _theme == AppTheme.dark ? ThemeMode.dark : ThemeMode.light;
  Locale get locale => _locale;

  static Future<AppSettings> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedTheme = preferences.getString(_themeKey) ?? AppTheme.dark.name;
    final theme = savedTheme == 'green'
        ? AppTheme.emerald
        : AppTheme.values.byName(savedTheme);
    final languageCode = preferences.getString(_localeKey) ?? 'ru';
    final settings = AppSettings._(preferences, theme, Locale(languageCode));
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
}
