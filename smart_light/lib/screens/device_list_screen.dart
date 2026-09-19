import 'package:flutter/material.dart';
import 'dart:async';
import '../services/device_service.dart';
import '../l10n/generated/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myDevices),
        actions: [
          IconButton(
            icon: const Icon(Icons.api),
            tooltip: l10n.apiTest,
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
          final provisioned = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (_) => const BleProvisioningScreen()),
          );
          if (provisioned == true) {
            await DeviceService.claimOnlineDevices();
          }
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
                    Text(l10n.errorWithDetails(snapshot.error.toString())),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _loadDevices();
                        });
                      },
                      child: Text(l10n.retry),
                    ),
                  ],
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              // Важно! Для pull-to-refresh с пустым списком нужен scrollable widget
              return ListView(
                children: [
                  const SizedBox(height: 200), // Отступ сверху
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.device_hub,
                          size: 64,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noDevices,
                          style: const TextStyle(fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.pullToRefresh,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
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
    final controller = TextEditingController(text: device.name);

    showModalBottomSheet(
      context: context,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.renameDevice,
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
                        controller.text,
                      );
                      setState(() {
                        _loadDevices();
                      });
                      Navigator.pop(context);
                    },
                    child: Text(AppLocalizations.of(context)!.save),
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
                    child: Text(AppLocalizations.of(context)!.delete),
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
