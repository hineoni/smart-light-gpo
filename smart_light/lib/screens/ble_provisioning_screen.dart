import 'dart:async';
import 'package:flutter/material.dart';
import '../services/ble_provisioning_service.dart';

class BleProvisioningScreen extends StatefulWidget {
  const BleProvisioningScreen({super.key});

  @override
  State<BleProvisioningScreen> createState() => _BleProvisioningScreenState();
}

class _BleProvisioningScreenState extends State<BleProvisioningScreen> {
  List<String> devices = [];
  bool isScanning = false;
  bool isProvisioning = false;
  bool isManualSetup = false;
  String? selectedDevice;
  final TextEditingController ssidController = TextEditingController(
    text: 'fbq', // Предустановленный SSID
  );
  final TextEditingController passwordController = TextEditingController(
    text: '24351058', // Предустановленный пароль
  );
  final TextEditingController backendUrlController = TextEditingController(
    text: 'ws://172.20.10.13:3000/_ws',
  );
  final TextEditingController deviceIpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeBle();
  }

  @override
  void dispose() {
    BleProvisioningService.cleanup();
    super.dispose();
  }

  Future<void> _initializeBle() async {
    final hasPermissions = await BleProvisioningService.requestPermissions();
    if (!hasPermissions) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('BLE permissions required')),
        );
      }
      return;
    }
    _startScan();
  }

  Future<void> _startScan() async {
    setState(() {
      isScanning = true;
      devices.clear(); // Очищаем список перед новым сканированием
    });

    try {
      // Используем StreamController для реального времени
      Timer.periodic(const Duration(milliseconds: 500), (timer) async {
        if (!isScanning) {
          timer.cancel();
          return;
        }

        final deviceList = await BleProvisioningService.scanDevices(
          timeout: const Duration(seconds: 2), // Короткие сканы
        );

        if (mounted) {
          setState(() {
            // Добавляем только новые устройства
            for (final device in deviceList) {
              if (!devices.contains(device)) {
                devices.add(device);
                print('Real-time device added: $device');
              }
            }
          });
        }
      });

      // Останавливаем сканирование через 15 секунд
      Timer(const Duration(seconds: 15), () {
        if (mounted) {
          setState(() => isScanning = false);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => isScanning = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Scan failed: $e')));
      }
    }
  }

  Future<void> _provisionDevice() async {
    if (selectedDevice == null || isProvisioning) return;

    setState(() => isProvisioning = true);

    try {
      print('Starting full provisioning with:');
      print('  Device: ${selectedDevice!}');
      print('  SSID: ${ssidController.text}');
      print('  Backend URL: ${backendUrlController.text}');

      final success =
          await BleProvisioningService.provisionDeviceWithCustomData(
            deviceName: selectedDevice!,
            proofOfPossession: 'abcd1234',
            ssid: ssidController.text,
            password: passwordController.text,
            wsUrl: backendUrlController.text,
            deviceId: '', // ESP32 сам определит свой ID
          );

      if (mounted) {
        setState(() => isProvisioning = false);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Устройство настроено! 🎉\nВся конфигурация отправлена через BLE.',
              ),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          // Показываем опцию ручной настройки
          _showManualSetupDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isProvisioning = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _showManualSetupDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Manual Backend Setup'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'WiFi provisioning succeeded, but backend URL setup failed. '
                'You can set it up manually by entering the device IP address:',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: deviceIpController,
                decoration: const InputDecoration(
                  labelText: 'Device IP Address',
                  hintText: 'e.g., 192.168.1.100',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Skip'),
            ),
            ElevatedButton(
              onPressed: _setupBackendManually,
              child: const Text('Setup'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setupBackendManually() async {
    if (deviceIpController.text.isEmpty) return;

    Navigator.of(context).pop(); // Закрываем диалог
    setState(() => isManualSetup = true);

    try {
      final success = await BleProvisioningService.setupBackendUrlManually(
        deviceIpController.text,
        backendUrlController.text,
      );

      if (mounted) {
        setState(() => isManualSetup = false);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Backend URL configured successfully!'),
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Manual setup failed. Check device IP address.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isManualSetup = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('BLE Provisioning')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: isScanning ? null : _startScan,
                    child: Text(
                      isScanning ? 'Scanning...' : 'Scan for Devices',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Found: ${devices.length}'),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: devices.isEmpty
                  ? Center(
                      child: Text(
                        isScanning
                            ? 'Scanning for ESP32 devices...'
                            : 'No devices found. Tap "Scan for Devices"',
                        style: Theme.of(context).textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final deviceName = devices[index];
                        final isSelected = selectedDevice == deviceName;

                        return Card(
                          elevation: isSelected ? 4 : 1,
                          color: isSelected
                              ? Theme.of(context).primaryColor.withOpacity(0.1)
                              : null,
                          child: ListTile(
                            leading: Icon(
                              Icons.bluetooth,
                              color: isSelected
                                  ? Theme.of(context).primaryColor
                                  : null,
                            ),
                            title: Text(
                              deviceName,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            subtitle: const Text('ESP32 Device'),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle)
                                : null,
                            onTap: () =>
                                setState(() => selectedDevice = deviceName),
                          ),
                        );
                      },
                    ),
            ),
            if (selectedDevice != null) ...[
              const Divider(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Full Device Configuration',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'All settings will be sent via BLE in a single step',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: ssidController,
                        decoration: const InputDecoration(
                          labelText: 'WiFi SSID',
                          prefixIcon: Icon(Icons.wifi),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(
                          labelText: 'WiFi Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: backendUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Backend URL',
                          prefixIcon: Icon(Icons.cloud),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed:
                              (isProvisioning ||
                                  ssidController.text.isEmpty ||
                                  selectedDevice == null)
                              ? null
                              : _provisionDevice,
                          icon: isProvisioning
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: Text(
                            selectedDevice == null
                                ? 'Select Device First'
                                : isProvisioning
                                ? 'Provisioning...'
                                : 'Provision Device',
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
