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
    bodyLarge: weight(
      base.bodyLarge,
      brightness == Brightness.dark ? FontWeight.w500 : FontWeight.w400,
    ),
    bodyMedium: weight(
      base.bodyMedium,
      brightness == Brightness.dark ? FontWeight.w500 : FontWeight.w400,
    ),
    bodySmall: weight(
      base.bodySmall,
      brightness == Brightness.dark ? FontWeight.w500 : FontWeight.w400,
    ),
    labelLarge: weight(base.labelLarge, FontWeight.w600),
    labelMedium: weight(base.labelMedium, FontWeight.w600),
    labelSmall: weight(base.labelSmall, FontWeight.w600),
  );
}

ThemeData _buildTheme(ColorScheme scheme, Color background) {
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: 'Avenir Next',
    textTheme: readableTextTheme(scheme.brightness),
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLow,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: const WidgetStatePropertyAll(
        TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
  );
}

ThemeData buildDarkTheme() => ThemeData(
  brightness: Brightness.dark,
  fontFamily: 'Avenir Next',
  textTheme: readableTextTheme(Brightness.dark),
  navigationBarTheme: const NavigationBarThemeData(
    backgroundColor: Color(0xFF1C1B1F),
    indicatorColor: Color(0xFF3F51B5),
    labelTextStyle: WidgetStatePropertyAll(
      TextStyle(fontWeight: FontWeight.w600),
    ),
  ),
);

ThemeData buildLightTheme() => _buildTheme(
  ColorScheme.fromSeed(seedColor: const Color(0xFF7456AD)).copyWith(
    primary: const Color(0xFF7456AD),
    onPrimary: Colors.white,
    primaryContainer: const Color(0xFFEADFFF),
    onPrimaryContainer: const Color(0xFF382458),
    tertiary: const Color(0xFF8C632C),
    surface: const Color(0xFFFFFDFF),
    surfaceContainerLowest: Colors.white,
    surfaceContainerLow: const Color(0xFFFEFCFF),
    surfaceContainerHighest: const Color(0xFFEEE7F6),
    outlineVariant: const Color(0xFFE4DBEE),
  ),
  const Color(0xFFF9F6FF),
);

ThemeData buildGreenTheme() => _buildTheme(
  ColorScheme.fromSeed(
    seedColor: const Color(0xFF00BE87),
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFF5CE1AE),
    onPrimary: const Color(0xFF003826),
    primaryContainer: const Color(0xFF087957),
    onPrimaryContainer: const Color(0xFFE9FFF4),
    tertiary: const Color(0xFFF7D17A),
    surface: const Color(0xFF0B463A),
    surfaceContainerLowest: const Color(0xFF07382E),
    surfaceContainerLow: const Color(0xFF115040),
    surfaceContainer: const Color(0xFF175D4B),
    surfaceContainerHigh: const Color(0xFF1B6754),
    surfaceContainerHighest: const Color(0xFF247B65),
    onSurface: const Color(0xFFE6FFF2),
    onSurfaceVariant: const Color(0xFFB7E6D1),
    outlineVariant: const Color(0xFF337F6A),
  ),
  const Color(0xFF073B31),
);

ThemeData buildIndigoTheme() => _buildTheme(
  ColorScheme.fromSeed(
    seedColor: const Color(0xFF386BFF),
    brightness: Brightness.dark,
  ).copyWith(
    primary: const Color(0xFFB0CEFF),
    onPrimary: const Color(0xFF102D69),
    primaryContainer: const Color(0xFF3B63CC),
    onPrimaryContainer: Colors.white,
    tertiary: const Color(0xFFFFD28A),
    surface: const Color(0xFF193B85),
    surfaceContainerLowest: const Color(0xFF10275D),
    surfaceContainerLow: const Color(0xFF1D4197),
    surfaceContainer: const Color(0xFF244CA2),
    surfaceContainerHigh: const Color(0xFF2D56AD),
    surfaceContainerHighest: const Color(0xFF365DA5),
    onSurface: const Color(0xFFF0F5FF),
    onSurfaceVariant: const Color(0xFFC2D4F8),
    outlineVariant: const Color(0xFF456BB3),
  ),
  const Color(0xFF142F75),
);
