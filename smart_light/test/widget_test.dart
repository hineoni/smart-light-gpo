// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_light/main.dart';
import 'package:smart_light/screens/login_screen.dart';
import 'package:smart_light/services/app_settings.dart';

void main() {
  test('settings persist the selected theme and language', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();

    await settings.setTheme(AppTheme.light);
    await settings.setLocale(const Locale('en'));
    final restored = await AppSettings.load();

    expect(restored.theme, AppTheme.light);
    expect(restored.locale, const Locale('en'));
  });

  testWidgets('app opens the sign-in screen without a saved session', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();
    await tester.pumpWidget(MyApp(settings: settings));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
