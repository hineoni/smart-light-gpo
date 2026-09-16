import 'package:flutter/material.dart';

TextTheme readableTextTheme(Brightness brightness) {
  final base = brightness == Brightness.dark
      ? Typography.material2021().white
      : Typography.material2021().black;
  TextStyle? weight(TextStyle? style, FontWeight value) =>
      style?.copyWith(fontWeight: value);
  return base.copyWith(
    displayLarge: weight(base.displayLarge, FontWeight.w600),
    displayMedium: weight(base.displayMedium, FontWeight.w600),
    displaySmall: weight(base.displaySmall, FontWeight.w600),
    headlineLarge: weight(base.headlineLarge, FontWeight.w600),
    headlineMedium: weight(base.headlineMedium, FontWeight.w600),
    headlineSmall: weight(base.headlineSmall, FontWeight.w600),
    titleLarge: weight(base.titleLarge, FontWeight.w600),
    titleMedium: weight(base.titleMedium, FontWeight.w600),
    titleSmall: weight(base.titleSmall, FontWeight.w600),
    bodyLarge: weight(base.bodyLarge, FontWeight.w500),
    bodyMedium: weight(base.bodyMedium, FontWeight.w500),
    bodySmall: weight(base.bodySmall, FontWeight.w500),
    labelLarge: weight(base.labelLarge, FontWeight.w600),
    labelMedium: weight(base.labelMedium, FontWeight.w600),
    labelSmall: weight(base.labelSmall, FontWeight.w600),
  );
}

ThemeData buildLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Colors.blue,
    brightness: Brightness.light,
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Avenir Next',
    textTheme: readableTextTheme(Brightness.light),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
  );
}

ThemeData buildGreenTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF008F73),
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF007A61),
        onPrimary: Colors.white,
        secondary: const Color(0xFF00B894),
        primaryContainer: const Color(0xFF006B55),
        onPrimaryContainer: Colors.white,
        surface: const Color(0xFFE5FFF7),
        surfaceContainerHighest: const Color(0xFFB8F5E2),
      );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Avenir Next',
    textTheme: readableTextTheme(Brightness.light),
    scaffoldBackgroundColor: const Color(0xFFD6FFF3),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFB8F5E2),
      foregroundColor: const Color(0xFF003D30),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFF8FE6D0),
      indicatorColor: Color(0xFF007A61),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}

ThemeData buildIndigoTheme() {
  const blue = Color(0xFF005BFF);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: blue,
        brightness: Brightness.light,
      ).copyWith(
        primary: blue,
        onPrimary: Colors.white,
        secondary: const Color(0xFF00A6FF),
        primaryContainer: const Color(0xFF0048C7),
        onPrimaryContainer: Colors.white,
        surface: const Color(0xFFEAF1FF),
        surfaceContainerHighest: const Color(0xFFC9DAFF),
      );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Avenir Next',
    textTheme: readableTextTheme(Brightness.light),
    scaffoldBackgroundColor: const Color(0xFFDCE8FF),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFC9DAFF),
      foregroundColor: Color(0xFF002E78),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFFACC7FF),
      indicatorColor: Color(0xFF005BFF),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );
}
