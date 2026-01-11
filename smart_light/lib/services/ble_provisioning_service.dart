import 'dart:async';
import 'dart:convert';
import 'package:flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BleProvisioningService {
  static const String devicePrefix = 'SmartLight_';
  static const String proofOfPossession = 'abcd1234';

  static Future<bool> requestPermissions() async {
    final bluetooth = await Permission.bluetooth.request();
    final bluetoothScan = await Permission.bluetoothScan.request();
    final bluetoothConnect = await Permission.bluetoothConnect.request();
    final location = await Permission.location.request();

    return bluetooth.isGranted &&
        bluetoothScan.isGranted &&
        bluetoothConnect.isGranted &&
        location.isGranted;
  }

  static Future<List<String>> scanDevices({Duration timeout = const Duration(seconds: 30)}) async {
    print('Starting BLE scan for ESP devices...');
    
    try {
      // Проверяем Bluetooth
      if (await FlutterBluePlus.isSupported == false) {
        print("Bluetooth not supported by this device");
        return [];
      }

      // Ждем когда Bluetooth включится
      await FlutterBluePlus.adapterState.where((val) => val == BluetoothAdapterState.on).first;
      
      List<String> foundDevices = [];
      
      // Слушаем результаты сканирования (правильный способ по документации)
      var subscription = FlutterBluePlus.onScanResults.listen((results) {
        if (results.isNotEmpty) {
          for (ScanResult result in results) {
            String? name = result.device.localName;
            if (name != null && name.startsWith(devicePrefix) && !foundDevices.contains(name)) {
              foundDevices.add(name);
              print('Found device: $name');
            }
          }
        }
      }, onError: (e) => print('Scan error: $e'));

      // Отменяем подписку когда сканирование остановится
      FlutterBluePlus.cancelWhenScanComplete(subscription);

      // Запускаем сканирование
      await FlutterBluePlus.startScan(timeout: timeout);

      // Ждем завершения сканирования
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
      
      print('Scan completed. Found ${foundDevices.length} devices: ${foundDevices.join(", ")}');
      return foundDevices;
    } catch (e) {
      print('Scan error: $e');
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      return [];
    }
  }

  static Future<bool> provisionDevice(
    String deviceName,
    String ssid,
    String password,
    String backendUrl,
  ) async {
    try {
      print('Starting provisioning for device: $deviceName');
      
      // Используем стандартный ESP BLE provisioning с хаком для передачи backend URL
      print('Using ESP BLE provisioning with backend URL hack...');
      final success = await _standardProvisioning(deviceName, ssid, password, backendUrl);
      
      if (success) {
        print('SUCCESS: Standard ESP provisioning with backend URL hack completed!');
        return true;
      }
      
      print('Standard provisioning failed, trying direct BLE as fallback...');
      // Fallback к direct BLE если стандартный способ не сработал
      final bleSuccess = await _sendFullConfigViaBle(
        deviceName: deviceName,
        ssid: ssid,
        password: password,
        wsUrl: backendUrl,
      );
      
      if (bleSuccess) {
        print('SUCCESS: Direct BLE fallback completed!');
        return true;
      }
      
      return false;
    } catch (e) {
      print('Provisioning failed: $e');
      return false;
    }
  }

  /// Новый метод с полной конфигурацией
  static Future<bool> provisionDeviceWithCustomData({
    required String deviceName,
    required String proofOfPossession,
    required String ssid,
    required String password,
    required String wsUrl,
    required String deviceId, // не используется, но оставляем для совместимости
  }) async {
    return await provisionDevice(deviceName, ssid, password, wsUrl);
  }
  
  /// Стандартное ESP BLE provisioning + HTTP backend setup
  static Future<bool> _standardProvisioning(
    String deviceName,
    String ssid,
    String password,
    String backendUrl,
  ) async {
    print('Using standard ESP BLE provisioning');
    
    final flutterEspBleProv = FlutterEspBleProv();
    
    // Сначала проверим доступные WiFi сети на устройстве
    try {
      print('Scanning WiFi networks on device...');
      final wifiList = await flutterEspBleProv.scanWifiNetworks(
        deviceName, // Полное имя устройства
        proofOfPossession,
      );
      print('WiFi scan completed, found ${wifiList.length} networks');
    } catch (e) {
      print('WiFi scan failed: $e');
      // Продолжаем даже если сканирование не удалось
    }

    // Отправляем WiFi credentials с хаком для передачи backend URL
    print('Sending WiFi credentials with backend URL hack...');
    
    // ХАК: добавляем backend URL к паролю через разделитель
    final hackPassword = '$password|ws:$backendUrl';
    print('Original password: $password');
    print('Hacked password: $hackPassword');
    
    // Используем полное имя устройства вместо prefix
    final success = await flutterEspBleProv.provisionWifi(
      deviceName, // Полное имя устройства
      proofOfPossession, 
      ssid,
      hackPassword, // Используем модифицированный пароль
    ).timeout(
      const Duration(seconds: 60), // Добавляем timeout
      onTimeout: () {
        print('WiFi provisioning timeout after 60 seconds');
        return false;
      },
    );
    
    print('Provisioning result: $success');
    
    if (success == true) {
      print('WiFi credentials sent successfully');
      print('Device should be connecting to WiFi and restarting...');
      
      // Ждем подключения устройства к WiFi и отправляем backend URL
      print('Waiting for device to connect to WiFi and sending backend URL...');
      final backendSetupSuccess = await _setupBackendUrl(deviceName, backendUrl);
      
      if (backendSetupSuccess) {
        print('Provisioning completed successfully');
        return true;
      } else {
        print('Backend URL setup failed, but WiFi provisioning succeeded');
        // Возвращаем true, так как WiFi provisioning успешен
        // Backend URL можно будет настроить позже через веб-интерфейс
        return true;
      }
    } else {
      print('Provisioning failed');
      return false;
    }
  }

  /// Отправляет backend URL на устройство через HTTP API
  static Future<bool> _setupBackendUrl(String deviceName, String backendUrl) async {
    // Генерируем device_id на основе deviceName
    final deviceId = deviceName.replaceAll(devicePrefix, '');
    
    print('Waiting for device to reboot and connect to WiFi...');
    await Future.delayed(const Duration(seconds: 15)); // Увеличиваем время ожидания
    
    print('Starting device search in local network...');
    // Сначала пробуем найти устройство в сети
    final deviceIp = await _findDeviceInNetwork();
    
    if (deviceIp != null) {
      print('Found device at IP: $deviceIp');
      return await _sendBackendConfig(deviceIp, backendUrl, deviceId);
    }
    
    // Если не нашли, пробуем типичные IP адреса
    print('Device not found automatically, trying common IP addresses...');
    final possibleIps = [
      '192.168.1.100', // Типичные IP в домашней сети
      '192.168.0.100',
      '192.168.1.101',
      '192.168.0.101',
      '192.168.1.110',
      '192.168.0.110',
    ];
    
    for (final ip in possibleIps) {
      final success = await _sendBackendConfig(ip, backendUrl, deviceId);
      if (success) {
        return true;
      }
    }
    
    print('Could not send backend URL to any IP address');
    return false;
  }
  
  /// Ищет устройство в локальной сети по HTTP запросам
  static Future<String?> _findDeviceInNetwork() async {
    print('Scanning local network for device...');
    
    // Определяем подсеть (обычно 192.168.1.x или 192.168.0.x)
    final subnets = ['192.168.1', '192.168.0'];
    
    for (final subnet in subnets) {
      print('Scanning subnet $subnet.x...');
      // Сканируем диапазон IP адресов
      final futures = <Future<String?>>[];
      
      for (int i = 100; i <= 120; i++) {
        final ip = '$subnet.$i';
        futures.add(_checkDeviceAtIp(ip));
      }
      
      // Ждем результатов со всех IP адресов
      final results = await Future.wait(futures, eagerError: false);
      
      // Ищем первый успешный результат
      for (final result in results) {
        if (result != null) {
          print('Device found in subnet $subnet: $result');
          return result;
        }
      }
      print('No device found in subnet $subnet');
    }
    
    print('Device not found in any subnet');
    return null;
  }
  
  /// Проверяет, является ли IP адрес нашим устройством
  static Future<String?> _checkDeviceAtIp(String ip) async {
    try {
      final url = Uri.parse('http://$ip/api/status');
      final response = await http.get(url).timeout(const Duration(seconds: 2));
      
      if (response.statusCode == 200) {
        // Проверяем, что это наше устройство по содержимому ответа
        final responseData = jsonDecode(response.body);
        if (responseData.containsKey('device_type') || 
            responseData.containsKey('status') ||
            response.body.contains('SmartLight')) {
          return ip;
        }
      }
    } catch (e) {
      // Игнорируем ошибки - устройство просто не доступно по этому IP
    }
    
    return null;
  }
  
  /// Отправляет конфигурацию backend на указанный IP
  static Future<bool> _sendBackendConfig(String ip, String backendUrl, String deviceId) async {
    try {
      print('Sending backend URL to $ip...');
      
      final url = Uri.parse('http://$ip/api/setup-backend');
      final body = jsonEncode({
        'backend_url': backendUrl,
        'device_id': deviceId,
      });
      
      print('Request body: $body');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: body,
      ).timeout(const Duration(seconds: 8)); // Увеличиваем timeout
      
      print('Response from $ip: ${response.statusCode}');
      print('Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'success') {
          print('Backend URL sent successfully to $ip');
          return true;
        } else {
          print('Backend setup failed on $ip: ${responseData['message']}');
        }
      } else {
        print('HTTP error $ip: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Failed to connect to $ip: $e');
    }
    
    return false;
  }

  static Future<void> cleanup() async {
    // Cleanup not needed for flutter_esp_ble_prov
  }

  /// Ручная настройка backend URL по IP адресу устройства
  static Future<bool> setupBackendUrlManually(
    String deviceIp,
    String backendUrl, {
    String? deviceId,
  }) async {
    try {
      print('Manually setting up backend URL for device at $deviceIp');
      
      // Если device_id не указан, используем случайный
      final finalDeviceId = deviceId ?? 'device_${DateTime.now().millisecondsSinceEpoch}';
      
      return await _sendBackendConfig(deviceIp, backendUrl, finalDeviceId);
    } catch (e) {
      print('Manual backend setup failed: $e');
      return false;
    }
  }

  /// Получает текущую конфигурацию устройства
  static Future<Map<String, dynamic>?> getDeviceConfig(String deviceIp) async {
    try {
      final url = Uri.parse('http://$deviceIp/api/status');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      print('Failed to get device config from $deviceIp: $e');
    }
    
    return null;
  }

  static Future<bool> _sendFullConfigViaBle({
    required String deviceName,
    required String ssid,
    required String password,
    required String wsUrl,
  }) async {
    BluetoothDevice? connectedDevice;
    
    try {
      print('Using flutter_blue_plus for direct BLE communication');
      
      // Находим устройство
      BluetoothDevice? targetDevice = await _findBleDevice(deviceName);
      if (targetDevice == null) {
        print('BLE device $deviceName not found');
        return false;
      }

      print('Connecting to BLE device: $deviceName');
      await targetDevice.connect(timeout: const Duration(seconds: 15));
      connectedDevice = targetDevice;

      // Обнаруживаем сервисы
      List<BluetoothService> services = await targetDevice.discoverServices();
      print('Found ${services.length} services:');
      
      // Формируем JSON с полной конфигурацией
      final configData = {
        'ssid': ssid,
        'password': password,  
        'ws_url': wsUrl,
      };

      final jsonString = json.encode(configData);
      print('Sending JSON: $jsonString');
      final jsonBytes = utf8.encode(jsonString);
      
      // Ищем характеристику 1775ff53 (которая работала в прошлый раз)
      const targetCharUuid = '1775ff53-6b43-439b-877c-060f2d9bed07';
      
      for (var service in services) {
        print('  Service: ${service.uuid}');
        
        for (var char in service.characteristics) {
          print('    Char: ${char.uuid}');
          
          // Пробуем найти нашу рабочую характеристику
          if (char.uuid.toString().toLowerCase() == targetCharUuid.toLowerCase()) {
            print('  -> Found target characteristic: ${char.uuid}');
            
            try {
              await char.write(jsonBytes, withoutResponse: false);
              print('Data written successfully to target characteristic!');
              
              // Даем время на обработку
              await Future.delayed(const Duration(seconds: 5));
              return true;
            } catch (writeError) {
              print('Write error on target char: $writeError');
            }
          }
        }
      }

      print('Target characteristic $targetCharUuid not found - trying fallback');
      
      // Fallback: ищем любую writable характеристику
      for (var service in services) {
        for (var char in service.characteristics) {
          if (char.properties.write || char.properties.writeWithoutResponse) {
            print('  -> Trying fallback characteristic: ${char.uuid}');
            
            try {
              await char.write(jsonBytes, withoutResponse: false);
              print('Data written successfully to fallback characteristic!');
              
              // Даем время на обработку
              await Future.delayed(const Duration(seconds: 5));
              return true;
            } catch (writeError) {
              print('Write error on fallback char: $writeError');
            }
          }
        }
      }

      print('No suitable characteristic found for custom config');
      return false;

    } catch (e) {
      print('Direct BLE config error: $e');
      return false;
    } finally {
      if (connectedDevice != null) {
        await connectedDevice.disconnect();
      }
    }
  }

  static Future<BluetoothDevice?> _findBleDevice(String deviceName) async {
    try {
      // Проверяем уже подключенные устройства
      for (BluetoothDevice device in FlutterBluePlus.connectedDevices) {
        if (device.localName == deviceName) return device;
      }

      // Сканируем устройства
      List<String> foundNames = await scanDevices(timeout: const Duration(seconds: 15));
      
      if (foundNames.contains(deviceName)) {
        // Получаем последние результаты сканирования
        final scanResults = FlutterBluePlus.lastScanResults;
        for (ScanResult result in scanResults) {
          if (result.device.localName == deviceName) {
            return result.device;
          }
        }
      }
      
      return null;
    } catch (e) {
      print('Find BLE device error: $e');
      return null;
    }
  }
}
