import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_light/l10n/generated/app_localizations.dart';
import 'package:smart_light/models/ambient_light_reading.dart';
import 'package:smart_light/models/device_model.dart';
import 'package:smart_light/screens/lighting_advice_screen.dart';
import 'package:smart_light/screens/settings_screen.dart';
import 'package:smart_light/services/app_settings.dart';
import 'package:smart_light/widgets/ambient_light_card.dart';
import 'package:smart_light/theme/light_theme.dart';

AmbientLightReading reading(
  int percent, {
  DateTime? receivedAt,
  String deviceId = 'lamp-1',
  bool lampOn = true,
  bool includeLamp = true,
}) => AmbientLightReading.fromJson({
  'available': true,
  'raw': 4095 - (percent * 4095 / 100).round(),
  'percent': percent,
  'receivedAt': (receivedAt ?? DateTime.now()).millisecondsSinceEpoch,
  'shared': true,
  'deviceId': deviceId,
  if (includeLamp)
    'lamp': {
      'available': true,
      'isOn': lampOn,
      'brightness': lampOn ? 128 : 0,
      'r': 255,
      'g': 255,
      'b': 255,
    },
});

Widget app(Widget child, {ThemeData? palette, String language = 'ru'}) =>
    MaterialApp(
      theme: palette ?? buildLightTheme(),
      locale: Locale(language),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.load();
  });

  test(
    'zero is a real reading; invalid and missing data never mean darkness',
    () {
      expect(reading(0).level, AmbientLightLevel.dark);
      expect(reading(100).level, AmbientLightLevel.bright);
      for (final data in <Map<String, dynamic>>[
        {},
        {'available': false, 'percent': 0},
        {'available': true, 'percent': 0},
        {
          'available': true,
          'raw': 20,
          'percent': 101,
          'receivedAt': DateTime.now().millisecondsSinceEpoch,
        },
        {
          'available': true,
          'raw': '20',
          'percent': 50,
          'receivedAt': DateTime.now().millisecondsSinceEpoch,
        },
      ]) {
        expect(AmbientLightReading.fromJson(data).level, isNull);
      }
    },
  );

  test('dark theme retains the original palette and typography', () {
    final original = ThemeData(
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
    final current = buildDarkTheme();
    expect(current.colorScheme, original.colorScheme);
    expect(current.scaffoldBackgroundColor, original.scaffoldBackgroundColor);
    expect(current.cardTheme, original.cardTheme);
    expect(current.navigationBarTheme, original.navigationBarTheme);
    expect(current.textTheme, original.textTheme);
    expect(current.textTheme.bodyMedium!.fontWeight, FontWeight.w500);
  });

  test('stale and future timestamps cannot produce recommendations', () {
    final now = DateTime.now();
    expect(
      reading(
        0,
        receivedAt: now.subtract(const Duration(seconds: 6)),
      ).recommendedBrightness(.5),
      isNull,
    );
    expect(
      reading(100, receivedAt: now.add(const Duration(minutes: 1))).level,
      isNull,
    );
  });

  test(
    'comfort boundaries are inclusive and correction scales with deviation',
    () {
      expect(reading(34).level, AmbientLightLevel.dark);
      expect(reading(35).level, AmbientLightLevel.comfortable);
      expect(reading(65).level, AmbientLightLevel.comfortable);
      expect(reading(66).level, AmbientLightLevel.bright);
      expect(reading(10).recommendedBrightness(.5), closeTo(.9, 1e-9));
      expect(reading(30).recommendedBrightness(.5), closeTo(.7, 1e-9));
      expect(reading(80).recommendedBrightness(.5), closeTo(.2, 1e-9));
      expect(reading(0).recommendedBrightness(.9), 1);
      expect(reading(100).recommendedBrightness(.1), 0);
      expect(reading(0).recommendedBrightness(1), isNull);
      expect(reading(100).recommendedBrightness(0), isNull);
      expect(reading(50).recommendedBrightness(.5), isNull);
    },
  );

  testWidgets(
    'settings switch persists and readings remain when advice is off',
    (tester) async {
      await tester.pumpWidget(
        app(SettingsScreen(settings: AppSettings.instance)),
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect((await AppSettings.load()).lightingAdviceEnabled, isFalse);
      await tester.pumpWidget(
        app(
          LightingAdviceScreen(
            loadDevices: () async => [],
            loadSensorDevice: (_) async => [],
            loadReading: (_) async => reading(10),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('Советы выключены'), findsOneWidget);
      expect(find.byKey(const Key('applyLightingAdvice')), findsNothing);
      await tester.tap(find.text('Включить советы'));
      await tester.pumpAndSettle();
      expect(find.text('В комнате темно'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'suggestion changes only the selected lamp after an explicit tap',
    (tester) async {
      final commands = <(String, double)>[];
      final lamp = DeviceModel(id: 'lamp-1', name: 'Лампа у стола');
      await tester.pumpWidget(
        app(
          LightingAdviceScreen(
            loadDevices: () async => [lamp],
            loadReading: (_) async => reading(10),
            applyBrightness: (id, value) async {
              commands.add((id, value));
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(commands, isEmpty);
      expect(find.text('Установить 90%'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('applyLightingAdvice')));
      await tester.tap(find.byKey(const Key('applyLightingAdvice')));
      await tester.pump();
      expect(commands.single.$1, 'lamp-1');
      expect(commands.single.$2, closeTo(128 / 255 + .4, 1e-9));
      expect(lamp.brightness, closeTo(128 / 255 + .4, 1e-9));
      expect(lamp.color, Colors.white);
      expect(lamp.servo1Angle, 90);
      expect(find.byKey(const Key('applyLightingAdvice')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('failed command does not change the lamp or claim success', (
    tester,
  ) async {
    final lamp = DeviceModel(id: 'lamp-1', name: 'Лампа');
    await tester.pumpWidget(
      app(
        LightingAdviceScreen(
          loadDevices: () async => [lamp],
          loadReading: (_) async => reading(90),
          applyBrightness: (_, _) async => throw Exception('offline'),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('applyLightingAdvice')));
    await tester.tap(find.byKey(const Key('applyLightingAdvice')));
    await tester.pumpAndSettle();
    expect(lamp.brightness, 128 / 255);
    expect(
      find.text(
        'Не удалось изменить яркость. Проверьте подключение лампы и повторите.',
      ),
      findsOneWidget,
    );
    expect(find.text('Яркость лампы изменена'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'reading loss clears the value and disables applying a suggestion',
    (tester) async {
      var online = true;
      await tester.pumpWidget(
        app(
          LightingAdviceScreen(
            loadDevices: () async => [DeviceModel(id: 'lamp-1', name: 'Лампа')],
            loadReading: (_) async {
              if (!online) throw Exception('USB disconnected');
              return reading(10);
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('10%'), findsOneWidget);
      online = false;
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('10%'), findsNothing);
      expect(find.byKey(const Key('applyLightingAdvice')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'lamp selector contains only the lamp physically attached to the USB sensor',
    (tester) async {
      final commands = <String>[];
      await tester.pumpWidget(
        app(
          LightingAdviceScreen(
            loadDevices: () async => [
              DeviceModel(id: 'other', name: 'Другая лампа'),
              DeviceModel(id: 'lamp-1', name: 'Лампа с датчиком'),
              DeviceModel(id: 'third', name: 'Третья лампа'),
            ],
            loadReading: (_) async => reading(10),
            applyBrightness: (id, _) async {
              commands.add(id);
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Другая лампа'), findsNothing);
      expect(find.text('Третья лампа'), findsNothing);
      final selector = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(selector.initialValue, 'lamp-1');
      await tester.ensureVisible(find.byKey(const Key('applyLightingAdvice')));
      await tester.tap(find.byKey(const Key('applyLightingAdvice')));
      await tester.pump();
      expect(commands, ['lamp-1']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'only the verified sensor ID can be claimed when the lamp is missing',
    (tester) async {
      final lookedUp = <String>[];
      await tester.pumpWidget(
        app(
          LightingAdviceScreen(
            loadDevices: () async => [
              DeviceModel(id: 'other', name: 'Другая лампа'),
            ],
            loadReading: (_) async => reading(10),
            loadSensorDevice: (id) async {
              lookedUp.add(id);
              return [DeviceModel(id: id, name: 'Лампа с датчиком')];
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(lookedUp, ['lamp-1']);
      expect(find.text('Другая лампа'), findsNothing);
      final selector = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(selector.initialValue, 'lamp-1');
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'full saved USB device ID selects the existing lamp without changing board settings',
    (tester) async {
      final commands = <String>[];
      await tester.pumpWidget(
        app(
          LightingAdviceScreen(
            loadDevices: () async => [
              DeviceModel(id: 'smartlight_382ddc', name: 'Другая лампа'),
              DeviceModel(
                id: 'smartlight_d01c94-new',
                name: 'Smart Light (d01c94-new)',
              ),
            ],
            loadReading: (_) async =>
                reading(10, deviceId: 'smartlight_d01c94-new'),
            loadSensorDevice: (_) async =>
                throw StateError('Existing alias must not be claimed again'),
            applyBrightness: (id, _) async {
              commands.add(id);
            },
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      final selector = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(selector.initialValue, 'smartlight_d01c94-new');
      expect(find.text('Другая лампа'), findsNothing);
      await tester.ensureVisible(find.byKey(const Key('applyLightingAdvice')));
      await tester.tap(find.byKey(const Key('applyLightingAdvice')));
      await tester.pump();
      expect(commands, ['smartlight_d01c94-new']);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('theme text and primary buttons keep readable contrast', () {
    for (final theme in [
      buildLightTheme(),
      buildDarkTheme(),
      buildGreenTheme(),
      buildIndigoTheme(),
    ]) {
      final colors = theme.colorScheme;
      for (final pair in [
        (colors.primary, colors.onPrimary),
        (colors.primaryContainer, colors.onPrimaryContainer),
        (colors.surface, colors.onSurface),
        (colors.surfaceContainerLow, colors.onSurfaceVariant),
      ]) {
        final first = pair.$1.computeLuminance();
        final second = pair.$2.computeLuminance();
        final contrast =
            (math.max(first, second) + .05) / (math.min(first, second) + .05);
        expect(contrast, greaterThanOrEqualTo(4.5));
      }
    }
  });

  for (final width in [320.0, 1000.0]) {
    for (final palette in [
      ('light', buildLightTheme()),
      ('dark', buildDarkTheme()),
      ('green', buildGreenTheme()),
      ('indigo', buildIndigoTheme()),
    ]) {
      testWidgets('advice fits width $width, theme ${palette.$1}, in English', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          app(
            LightingAdviceScreen(
              loadDevices: () async => [
                DeviceModel(id: 'lamp-1', name: 'Desk lamp'),
              ],
              loadReading: (_) async => reading(90),
            ),
            palette: palette.$2,
            language: 'en',
          ),
        );
        await tester.pump(const Duration(seconds: 2));
        await tester.pumpAndSettle();
        expect(find.byType(AmbientLightCard), findsOneWidget);
        expect(find.text('90%'), findsOneWidget);
        expect(find.textContaining('USB'), findsNothing);
        expect(find.text('Обновляется автоматически'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
