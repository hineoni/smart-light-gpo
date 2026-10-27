import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/ambient_light_reading.dart';
import 'api_config.dart';
import 'auth_service.dart';

class AmbientLightService {
  static const _localBaseUrl = String.fromEnvironment('LIGHT_SENSOR_BASE_URL');
  static bool get usesSharedUsbSensor => _localBaseUrl.isNotEmpty;

  static Future<LampState?> readLamp(String deviceId) async {
    final reading = await read(deviceId);
    if (reading.deviceId != deviceId) return null;
    return reading.currentLamp;
  }

  static Future<void> confirmLamp(
    String deviceId, {
    required bool isOn,
    double? brightness,
    required DateTime after,
  }) async {
    final deadline = DateTime.now().add(const Duration(seconds: 7));
    while (DateTime.now().isBefore(deadline)) {
      final reading = await read(deviceId);
      final lamp = reading.currentLamp;
      if (reading.deviceId == deviceId &&
          lamp != null &&
          (reading.receivedAt?.isAfter(after) ?? false) &&
          lamp.isOn == isOn &&
          (brightness == null ||
              (lamp.brightness / 255 - brightness).abs() <= 1.5 / 255)) {
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    throw StateError('Lamp did not confirm the command');
  }

  static Future<AmbientLightReading> read(String? deviceId) async {
    if (!usesSharedUsbSensor && deviceId == null) {
      return const AmbientLightReading();
    }
    final uri = usesSharedUsbSensor
        ? Uri.parse('$_localBaseUrl/ambient-light')
        : ApiConfig.uri(
            '/devices/${Uri.encodeComponent(deviceId!)}/ambient-light',
          );
    // Never send cloud tokens to the local sensor bridge.
    final response = await http
        .get(uri, headers: usesSharedUsbSensor ? null : AuthService.authHeaders)
        .timeout(const Duration(seconds: 3));
    if (response.statusCode != 200) {
      throw Exception('Light sensor request failed (${response.statusCode})');
    }
    return AmbientLightReading.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }
}
