import 'package:flutter/material.dart';
import 'dart:async';
import '../services/device_service.dart';
import '../models/device_model.dart';
import 'device_control_screen.dart';
import 'ble_provisioning_screen.dart';
import 'api_test_screen.dart';

class DeviceListScreen extends StatefulWidget {
  const DeviceListScreen({super.key});

  @override
  State<DeviceListScreen> createState() => _DeviceListScreenState();
}

class _DeviceListScreenState extends State<DeviceListScreen> {
  late Future<List<DeviceModel>> _devicesFuture;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    
    // Автообновление каждые 5 секунд
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _loadDevices();
        });
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _loadDevices() {
    _devicesFuture = DeviceService.getDevices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мои устройства'),
        actions: [
          IconButton(
            icon: const Icon(Icons.api),
            tooltip: 'API Test',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ApiTestScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BleProvisioningScreen()),
          );
          setState(() {
            _loadDevices();
          });
        },
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _loadDevices();
          });
          // Ждем завершения загрузки
          await _devicesFuture;
        },
        child: FutureBuilder<List<DeviceModel>>(
          future: _devicesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Ошибка: ${snapshot.error}'),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadDevices();
                        });
                      },
                      child: const Text('Повторить'),
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              // Важно! Для pull-to-refresh с пустым списком нужен scrollable widget
              return ListView(
                children: const [
                  SizedBox(height: 200), // Отступ сверху
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.device_hub, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('Нет устройств', style: TextStyle(fontSize: 18)),
                        SizedBox(height: 8),
                        Text('Потяните вниз для обновления', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                ],
              );
            } else {
              final devices = snapshot.data!;
              return ListView.builder(
                itemCount: devices.length,
                itemBuilder: (context, index) {
                  final device = devices[index];
                  return ListTile(
                    title: Text(device.name),
                    trailing: const Icon(Icons.arrow_forward),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DeviceControlScreen(device: device),
                        ),
                      );
                    },
                    onLongPress: () {
                      _showDeviceOptions(context, device);
                    },
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }

  void _showDeviceOptions(BuildContext context, DeviceModel device) {
    final _controller = TextEditingController(text: device.name);

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Переименовать устройство',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () async {
                      await DeviceService.renameDevice(
                        device.id,
                        _controller.text,
                      );
                      setState(() {
                        _loadDevices();
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Сохранить'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () async {
                      await DeviceService.removeDevice(device.id);
                      setState(() {
                        _loadDevices();
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Удалить'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
