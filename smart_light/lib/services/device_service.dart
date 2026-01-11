import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/device_model.dart';

class DeviceService {
  static const String baseUrl =
      'http://172.20.10.13:3000'; // Измените на IP бекенда если нужно

  static Future<List<DeviceModel>> getDevices() async {
    try {
      print('[DEVICE_SERVICE] Requesting devices from $baseUrl/devices');
      // Сначала пробуем /devices (все устройства)
      final response = await http.get(Uri.parse('$baseUrl/devices'));
      print('[DEVICE_SERVICE] Response status: ${response.statusCode}');
      print('[DEVICE_SERVICE] Response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> data =
            (json.decode(response.body) as List).cast<Map<String, dynamic>>();
        print('[DEVICE_SERVICE] Parsed ${data.length} devices');
        final devices = data.map((json) {
          print('[DEVICE_SERVICE] Processing device: $json');
          return DeviceModel.fromJson(json);
        }).toList();
        print('[DEVICE_SERVICE] Returning ${devices.length} devices');
        return devices;
      } else {
        // Если /devices не работает, пробуем /devices/online
        print('[DEVICE_SERVICE] Trying fallback: $baseUrl/devices/online');
        final fallbackResponse = await http.get(
          Uri.parse('$baseUrl/devices/online'),
        );
        print(
          '[DEVICE_SERVICE] Fallback status: ${fallbackResponse.statusCode}',
        );
        print('[DEVICE_SERVICE] Fallback body: ${fallbackResponse.body}');

        if (fallbackResponse.statusCode == 200) {
          final List<Map<String, dynamic>> data =
              (json.decode(fallbackResponse.body) as List)
                  .cast<Map<String, dynamic>>();
          return data.map((json) => DeviceModel.fromOnlineJson(json)).toList();
        } else {
          throw Exception('Both /devices and /devices/online endpoints failed');
        }
      }
    } catch (e, stackTrace) {
      print('[DEVICE_SERVICE] ERROR loading devices: $e');
      print('[DEVICE_SERVICE] Stack trace: $stackTrace');
      // Не возвращаем заглушки - возвращаем пустой список
      return [];
    }
  }

  static Future<void> addDevice(String name, {String? id, String? ip}) async {
    try {
      final body = {'name': name, 'ip': ip ?? 'unknown'};
      if (id != null) body['id'] = id;
      final response = await http.post(
        Uri.parse('$baseUrl/devices'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );
      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('Failed to add device');
      }
    } catch (e) {
      // Не используем fallback заглушки
      print('Error adding device: $e');
      throw Exception('Failed to add device: $e');
    }
  }

  static Future<void> removeDevice(String id) async {
    try {
      final response = await http.delete(Uri.parse('$baseUrl/devices/$id'));
      if (response.statusCode != 200) {
        throw Exception('Failed to remove device');
      }
    } catch (e) {
      // Не используем fallback заглушки
      print('Error removing device: $e');
      throw Exception('Failed to remove device: $e');
    }
  }

  static Future<void> renameDevice(String id, String newName) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/devices/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': newName}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to rename device');
      }
    } catch (e) {
      // Не используем fallback заглушки
      print('Error renaming device: $e');
      throw Exception('Failed to rename device: $e');
    }
  }

  static Future<void> updateServo(
    String deviceId,
    int servo,
    double angle,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/devices/$deviceId/servo'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'servo': servo, 'angle': angle}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update servo');
      }
    } catch (e) {
      // No fallback for servo control
    }
  }

  static Future<void> updateLed(
    String deviceId,
    double brightness,
    int r,
    int g,
    int b,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/devices/$deviceId/led'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'type': 'set_led_color', 'r': r, 'g': g, 'b': b}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update LED color');
      }

      // Also set brightness
      final brightnessResponse = await http.post(
        Uri.parse('$baseUrl/devices/$deviceId/led'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'type': 'set_led_brightness',
          'brightness': (brightness * 255).toInt(),
        }),
      );
      if (brightnessResponse.statusCode != 200) {
        throw Exception('Failed to update LED brightness');
      }
    } catch (e) {
      // No fallback
    }
  }

  static Future<void> turnOffLeds(String deviceId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/devices/$deviceId/led'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'type': 'clear_leds'}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to turn off LEDs');
      }
    } catch (e) {
      print('[DEVICE_SERVICE] Error turning off LEDs: $e');
    }
  }

  static Future<List<DeviceModel>> getOnlineDevices() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/devices/online'));
      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> data =
            (json.decode(response.body) as List).cast<Map<String, dynamic>>();
        return data.map((json) => DeviceModel.fromOnlineJson(json)).toList();
      } else {
        throw Exception('Failed to load online devices');
      }
    } catch (e) {
      return [];
    }
  }

  // Проверка статуса устройства через online роут
  static Future<bool> checkDeviceStatus(String deviceId) async {
    try {
      print('[DEVICE_SERVICE] Checking status for device: $deviceId');
      final response = await http
          .get(
            Uri.parse('$baseUrl/devices/online'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5)); // Таймаут 5 секунд

      print('[DEVICE_SERVICE] Online devices response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final List<dynamic> onlineDevices = json.decode(response.body);
        final isOnline = onlineDevices.any(
          (device) => device['deviceId'] == deviceId,
        );
        print(
          '[DEVICE_SERVICE] Device $deviceId is ${isOnline ? 'online' : 'offline'}',
        );
        return isOnline;
      } else {
        print(
          '[DEVICE_SERVICE] Online devices check failed: ${response.statusCode}',
        );
        return false;
      }
    } catch (e) {
      print('[DEVICE_SERVICE] Error checking device status: $e');
      return false;
    }
  }

  // Удаляем fallback заглушки - теперь возвращаем пустые списки при ошибках
  // static final List<DeviceModel> _fallbackDevices = [
  //   DeviceModel(id: '1', name: 'Устройство 1'),
  //   DeviceModel(id: '2', name: 'Устройство 2'),
  // ];
}
