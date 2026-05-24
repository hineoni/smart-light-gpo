import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/device_model.dart';
import '../models/device_distance_model.dart';
import '../models/light_scene_model.dart';
import 'auth_service.dart';

class DeviceService {
  static const String baseUrl =
      'http://172.20.10.13:3000'; // Измените на IP бекенда если нужно

  static Map<String, String> get _headers => AuthService.authHeaders;

  static Future<http.Response> _get(String path) {
    return http.get(Uri.parse('$baseUrl$path'), headers: _headers);
  }

  static Future<http.Response> _post(String path, {Object? body}) {
    return http.post(Uri.parse('$baseUrl$path'), headers: _headers, body: body);
  }

  static Future<http.Response> _put(String path, {Object? body}) {
    return http.put(Uri.parse('$baseUrl$path'), headers: _headers, body: body);
  }

  static Future<http.Response> _delete(String path) {
    return http.delete(Uri.parse('$baseUrl$path'), headers: _headers);
  }

  static Future<List<DeviceModel>> getDevices() async {
    try {
      print('[DEVICE_SERVICE] Requesting devices from $baseUrl/devices');
      // Сначала пробуем /devices (все устройства)
      final response = await _get('/devices');
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
        final fallbackResponse = await _get('/devices/online');
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
      final response = await _post('/devices', body: json.encode(body));
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
      final response = await _delete('/devices/$id');
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
      final response = await _put(
        '/devices/$id',
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
      final response = await _post(
        '/devices/$deviceId/servo',
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
      final response = await _post(
        '/devices/$deviceId/led',
        body: json.encode({'type': 'set_led_color', 'r': r, 'g': g, 'b': b}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update LED color');
      }

      // Also set brightness
      final brightnessResponse = await _post(
        '/devices/$deviceId/led',
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
      final response = await _post(
        '/devices/$deviceId/led',
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
      final response = await _get('/devices/online');
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

  static Future<List<DeviceDistanceModel>> getDistances() async {
    try {
      final response = await _get(
        '/devices/distances',
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> data =
            (json.decode(response.body) as List).cast<Map<String, dynamic>>();
        return data.map((json) => DeviceDistanceModel.fromJson(json)).toList();
      }

      throw Exception('Failed to load distances');
    } catch (e) {
      return [];
    }
  }

  static Future<PositioningSummaryModel> getPositioningSummary() async {
    try {
      final response = await _get(
        '/devices/distances/summary',
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return PositioningSummaryModel.fromJson(data);
      }

      throw Exception('Failed to load positioning summary');
    } catch (e) {
      final distances = await getDistances();
      return PositioningSummaryModel.fromDistances(distances);
    }
  }

  static Future<List<RoomZoneModel>> getZones() async {
    try {
      final response = await _get('/zones').timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> data =
            (json.decode(response.body) as List).cast<Map<String, dynamic>>();
        return data.map(RoomZoneModel.fromJson).toList();
      }
    } catch (e) {
      print('[DEVICE_SERVICE] Error loading zones: $e');
    }
    return [];
  }

  static Future<List<LightSceneModel>> getScenes() async {
    try {
      final response = await _get(
        '/scenes',
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List<Map<String, dynamic>> data =
            (json.decode(response.body) as List).cast<Map<String, dynamic>>();
        return data.map(LightSceneModel.fromJson).toList();
      }
    } catch (e) {
      print('[DEVICE_SERVICE] Error loading scenes: $e');
    }
    return [];
  }

  static Future<LightSceneModel?> saveScene(
    String name, {
    String? zoneId,
  }) async {
    try {
      final response = await _post(
        '/scenes',
        body: json.encode({'name': name, if (zoneId != null) 'zoneId': zoneId}),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return LightSceneModel.fromJson(json.decode(response.body));
      }
    } catch (e) {
      print('[DEVICE_SERVICE] Error saving scene: $e');
    }
    return null;
  }

  static Future<bool> applyScene(String sceneId) async {
    try {
      final response = await _post(
        '/scenes/$sceneId/apply',
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('[DEVICE_SERVICE] Error applying scene: $e');
      return false;
    }
  }

  static Future<bool> deleteScene(String sceneId) async {
    try {
      final response = await _delete(
        '/scenes/$sceneId',
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('[DEVICE_SERVICE] Error deleting scene: $e');
      return false;
    }
  }

  static Future<LightSceneModel?> updateScene(
    String sceneId, {
    String? name,
    String? zoneId,
    bool clearZone = false,
  }) async {
    try {
      final response = await _put(
        '/scenes/$sceneId',
        body: json.encode({
          if (name != null) 'name': name,
          if (clearZone)
            'zoneId': null
          else if (zoneId != null)
            'zoneId': zoneId,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return LightSceneModel.fromJson(json.decode(response.body));
      }
    } catch (e) {
      print('[DEVICE_SERVICE] Error updating scene: $e');
    }
    return null;
  }

  static Future<RoomZoneModel?> saveZone({
    String? id,
    required String name,
    required double x,
    required double y,
    double? heightM,
  }) async {
    try {
      final response = await _post(
        '/zones',
        body: json.encode({
          if (id != null) 'id': id,
          'name': name,
          'x': x,
          'y': y,
          if (heightM != null) 'heightM': heightM,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return RoomZoneModel.fromJson(json.decode(response.body));
      }
    } catch (e) {
      print('[DEVICE_SERVICE] Error saving zone: $e');
    }
    return null;
  }

  static Future<bool> deleteZone(String zoneId) async {
    try {
      final response = await _delete(
        '/zones/$zoneId',
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('[DEVICE_SERVICE] Error deleting zone: $e');
      return false;
    }
  }

  static Future<bool> assignDeviceZone(String deviceId, String zoneId) async {
    try {
      final response = await _post(
        '/devices/$deviceId/zone',
        body: json.encode({'zoneId': zoneId}),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('[DEVICE_SERVICE] Error assigning zone: $e');
      return false;
    }
  }

  static Future<bool> aimDeviceAtTarget(
    String sourceDeviceId,
    String targetDeviceId,
  ) async {
    try {
      final response = await _post(
        '/devices/$sourceDeviceId/aim',
        body: json.encode({'targetDeviceId': targetDeviceId}),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('[DEVICE_SERVICE] Error aiming device: $e');
      return false;
    }
  }

  // Проверка статуса устройства через online роут
  static Future<bool> checkDeviceStatus(String deviceId) async {
    try {
      print('[DEVICE_SERVICE] Checking status for device: $deviceId');
      final response = await _get(
        '/devices/online',
      ).timeout(const Duration(seconds: 5)); // Таймаут 5 секунд

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
