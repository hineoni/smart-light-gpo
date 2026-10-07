// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_light/main.dart';
import 'package:smart_light/l10n/generated/app_localizations.dart';
import 'package:smart_light/screens/login_screen.dart';
import 'package:smart_light/screens/positioning_screen.dart';
import 'package:smart_light/screens/settings_screen.dart';
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

  testWidgets('theme choice stays visible when settings is reopened', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await AppSettings.load();

    Widget settingsApp() => MaterialApp(
      locale: const Locale('ru'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: SettingsScreen(settings: settings),
    );

    await tester.pumpWidget(settingsApp());
    await tester.pumpAndSettle();
    expect(find.text('Тёмная тема'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<AppTheme>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Зелёная тема').last);
    await tester.pumpAndSettle();
    expect(find.text('Зелёная тема'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: Scaffold()));
    await tester.pumpWidget(settingsApp());
    await tester.pumpAndSettle();
    expect(find.text('Зелёная тема'), findsOneWidget);

    await tester.tap(find.byType(DropdownButton<AppTheme>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Синяя тема').last);
    await tester.pumpAndSettle();
    expect(find.text('Синяя тема'), findsOneWidget);
    expect((await AppSettings.load()).theme, AppTheme.indigo);
  });

  testWidgets('preset section is visible while positioning data loads', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: [AppLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: PositioningScreen(),
      ),
    );

    expect(find.text('Световые сцены'), findsOneWidget);
    expect(find.text('Готовые пресеты'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
