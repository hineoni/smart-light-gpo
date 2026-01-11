import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class BleProvisioningService {
  static const String servicePrefix = "SmartLight_";
  static const String customEndpointName = "backend_config";

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _wifiCharacteristic;
  BluetoothCharacteristic? _customCharacteristic;

  // Стандартные UUID для WiFi Provisioning (ESP32)
  static const String _wifiProvServiceUuid =
      "0000ffff-0000-1000-8000-00805f9b34fb";
  static const String _wifiProvCharUuid =
      "0000ff51-0000-1000-8000-00805f9b34fb";
  static const String _customProvCharUuid =
      "0000ff52-0000-1000-8000-00805f9b34fb";

  Future<bool> requestPermissions() async {
    try {
      Map<Permission, PermissionStatus> statuses = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.bluetoothAdvertise,
        Permission.location,
      ].request();

      return statuses.values.every((status) => status.isGranted);
    } catch (e) {
      debugPrint('Error requesting permissions: $e');
      return false;
    }
  }

  Future<List<BluetoothDevice>> scanForDevices() async {
    if (!await requestPermissions()) {
      throw Exception('Bluetooth permissions not granted');
    }

    List<BluetoothDevice> devices = [];

    // Проверяем, включен ли Bluetooth
    if (await FlutterBluePlus.isSupported == false) {
      throw Exception('Bluetooth not supported by this device');
    }

    var subscription = FlutterBluePlus.onScanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName.startsWith(servicePrefix)) {
          if (!devices.contains(r.device)) {
            devices.add(r.device);
          }
        }
      }
    }, onError: (e) => debugPrint('Scan error: $e'));

    // Запускаем сканирование на 10 секунд
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
    await Future.delayed(const Duration(seconds: 10));
    await FlutterBluePlus.stopScan();

    subscription.cancel();
    return devices;
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      _connectedDevice = device;

      // Ищем нужные сервисы и характеристики
      List<BluetoothService> services = await device.discoverServices();

      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase().contains('ffff')) {
          debugPrint('Found provisioning service: ${service.uuid}');

          for (BluetoothCharacteristic characteristic
              in service.characteristics) {
            debugPrint('Found characteristic: ${characteristic.uuid}');

            // Ищем характеристику для WiFi provisioning
            if (characteristic.uuid.toString().toLowerCase().contains('ff51')) {
              _wifiCharacteristic = characteristic;
            }
            // Ищем характеристику для custom endpoint
            else if (characteristic.uuid.toString().toLowerCase().contains(
              'ff52',
            )) {
              _customCharacteristic = characteristic;
            }
          }
        }
      }

      return _wifiCharacteristic != null;
    } catch (e) {
      debugPrint('Error connecting to device: $e');
      return false;
    }
  }

  Future<bool> provisionWiFi(String ssid, String password) async {
    if (_wifiCharacteristic == null) {
      throw Exception('Not connected to provisioning device');
    }

    try {
      // Создаем JSON с WiFi credentials
      Map<String, dynamic> wifiConfig = {'ssid': ssid, 'password': password};

      String jsonData = json.encode(wifiConfig);
      List<int> data = utf8.encode(jsonData);

      await _wifiCharacteristic!.write(data);

      // Ждем подтверждения
      await Future.delayed(const Duration(seconds: 2));

      return true;
    } catch (e) {
      debugPrint('Error provisioning WiFi: $e');
      return false;
    }
  }

  Future<bool> configureBackend(String backendUrl) async {
    if (_customCharacteristic == null) {
      debugPrint(
        'Custom characteristic not found, trying to use WiFi characteristic',
      );
      if (_wifiCharacteristic == null) {
        throw Exception(
          'No suitable characteristic found for backend configuration',
        );
      }
      _customCharacteristic = _wifiCharacteristic;
    }

    try {
      // Отправляем URL бекенда
      List<int> data = utf8.encode(backendUrl);
      await _customCharacteristic!.write(data);

      // Ждем подтверждения
      await Future.delayed(const Duration(seconds: 1));

      // Читаем ответ если возможно
      if (_customCharacteristic!.properties.read) {
        List<int> response = await _customCharacteristic!.read();
        String responseStr = utf8.decode(response);
        debugPrint('Backend config response: $responseStr');

        Map<String, dynamic> responseJson = json.decode(responseStr);
        return responseJson['status'] == 'success';
      }

      return true;
    } catch (e) {
      debugPrint('Error configuring backend: $e');
      return false;
    }
  }

  Future<bool> completeProvisioning(
    String ssid,
    String password,
    String backendUrl,
  ) async {
    try {
      // Сначала настраиваем WiFi
      bool wifiSuccess = await provisionWiFi(ssid, password);
      if (!wifiSuccess) {
        throw Exception('WiFi provisioning failed');
      }

      // Затем настраиваем бекенд
      bool backendSuccess = await configureBackend(backendUrl);
      if (!backendSuccess) {
        throw Exception('Backend configuration failed');
      }

      return true;
    } catch (e) {
      debugPrint('Error completing provisioning: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      await _connectedDevice!.disconnect();
      _connectedDevice = null;
      _wifiCharacteristic = null;
      _customCharacteristic = null;
    }
  }

  bool get isConnected => _connectedDevice != null;
  String? get connectedDeviceName => _connectedDevice?.platformName;
}
