import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_light/models/ambient_light_reading.dart';
import 'package:smart_light/models/device_model.dart';
import 'package:smart_light/screens/device_control_screen.dart';
import 'package:smart_light/screens/lighting_advice_screen.dart';
import 'package:smart_light/services/app_settings.dart';
import 'package:smart_light/widgets/light_control.dart';
import 'ambient_light_test.dart' as fixtures;

const off = LampState(isOn: false, brightness: 0, r: 255, g: 255, b: 255);
const on = LampState(isOn: true, brightness: 153, r: 255, g: 255, b: 255);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppSettings.load();
  });

  test('off state is distinct from missing or stale state', () {
    final actualOff = fixtures.reading(20, lampOn: false);
    expect(actualOff.currentLamp!.isOn, isFalse);
    expect(actualOff.currentLamp!.brightness, 0);
    expect(fixtures.reading(20, includeLamp: false).currentLamp, isNull);
    expect(
      fixtures
          .reading(
            20,
            receivedAt: DateTime.now().subtract(const Duration(seconds: 6)),
          )
          .currentLamp,
      isNull,
    );
    expect(
      LampState.tryParse({
        'available': true,
        'isOn': false,
        'brightness': 50,
        'r': 255,
        'g': 255,
        'b': 255,
      }),
      isNull,
    );
    expect(
      LampState.tryParse({
        'available': true,
        'isOn': true,
        'brightness': '153',
        'r': 255,
        'g': 255,
        'b': 255,
      }),
      isNull,
    );
  });

  test('turning off does not erase the last brightness', () async {
    final settings = AppSettings.instance;
    await settings.rememberLampBrightness('lamp-1', .6);
    await settings.rememberLampBrightness('lamp-1', 0);
    final restored = await AppSettings.load();
    expect(restored.lastLampBrightness('lamp-1', fallback: .2), .6);
    expect(restored.lastLampBrightness('other', fallback: .4), .4);
  });

  testWidgets(
    'advice shows off and explicitly turns on at the suggested brightness',
    (tester) async {
      final lamp = DeviceModel(id: 'lamp-1', name: 'Лампа', brightness: .6);
      final turnedOn = <double>[];
      await tester.pumpWidget(
        fixtures.app(
          LightingAdviceScreen(
            loadDevices: () async => [lamp],
            loadReading: (_) async => fixtures.reading(10, lampOn: false),
            turnOnLamp: (_, brightness) async {
              turnedOn.add(brightness);
            },
            applyBrightness: (_, _) async =>
                fail('An off lamp requires the power-on path'),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Лампа выключена'), findsOneWidget);
      expect(find.text('Яркость лампы сейчас: 60%'), findsNothing);
      expect(find.text('Включить на 100%'), findsOneWidget);
      expect(turnedOn, isEmpty);
      await tester.tap(find.byKey(const Key('applyLightingAdvice')));
      await tester.pump();
      expect(turnedOn, [1.0]);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'unknown board state cannot be replaced by an old server brightness',
    (tester) async {
      await tester.pumpWidget(
        fixtures.app(
          LightingAdviceScreen(
            loadDevices: () async => [
              DeviceModel(id: 'lamp-1', name: 'Лампа', brightness: .87),
            ],
            loadReading: (_) async => fixtures.reading(10, includeLamp: false),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Состояние лампы пока неизвестно'), findsOneWidget);
      expect(find.textContaining('87%'), findsNothing);
      expect(find.byKey(const Key('applyLightingAdvice')), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('an off lamp in a bright room does not suggest turning on', (
    tester,
  ) async {
    await tester.pumpWidget(
      fixtures.app(
        LightingAdviceScreen(
          loadDevices: () async => [DeviceModel(id: 'lamp-1', name: 'Лампа')],
          loadReading: (_) async => fixtures.reading(90, lampOn: false),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('applyLightingAdvice')), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('switch reads the board and restores brightness after off/on', (
    tester,
  ) async {
    LampState state = off;
    final restored = <double>[];
    final device = DeviceModel(id: 'lamp-1', name: 'Лампа', brightness: .6);
    await tester.pumpWidget(
      fixtures.app(
        DeviceControlScreen(
          device: device,
          checkOnline: (_) async => true,
          readLamp: (_) async => state,
          turnOnLamp: (_, brightness) async {
            restored.add(brightness);
            state = on;
          },
          switchOffLamp: (_) async {
            state = off;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<LightControl>(find.byType(LightControl)).isLightOn,
      isFalse,
    );
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(restored, [.6]);
    expect(
      tester.widget<LightControl>(find.byType(LightControl)).isLightOn,
      isTrue,
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LightControl>(find.byType(LightControl)).isLightOn,
      isFalse,
    );
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(restored, [.6, .6]);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('failed switch command does not pretend the lamp is on', (
    tester,
  ) async {
    await tester.pumpWidget(
      fixtures.app(
        DeviceControlScreen(
          device: DeviceModel(id: 'lamp-1', name: 'Лампа'),
          checkOnline: (_) async => true,
          readLamp: (_) async => off,
          turnOnLamp: (_, _) async => throw StateError('offline'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Switch));
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(
      tester.widget<LightControl>(find.byType(LightControl)).isLightOn,
      isFalse,
    );
    expect(
      find.text('Лампа не подтвердила команду. Проверьте подключение.'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
