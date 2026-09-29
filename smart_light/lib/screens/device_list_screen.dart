import 'package:flutter/material.dart';
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
  List<DeviceModel>? _devices;
  Object? _loadError;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _refreshDevices();
  }

  Future<void> _refreshDevices() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final devices = await DeviceService.getDevices().timeout(
        const Duration(seconds: 12),
      );
      if (!mounted) return;
      setState(() {
        _devices = devices;
        _loadError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error);
      if (_devices != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorWithDetails(error.toString()),
            ),
          ),
        );
      }
    } finally {
      _refreshing = false;
    }
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
          if (mounted) await _refreshDevices();
        },
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDevices,
        child: _buildDeviceList(l10n),
      ),
    );
  }

  Widget _buildDeviceList(AppLocalizations l10n) {
    final devices = _devices;
    if (devices == null || devices.isEmpty) {
      return CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: _loadError != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.errorWithDetails(_loadError.toString())),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshDevices,
                          child: Text(l10n.retry),
                        ),
                      ],
                    )
                  : devices == null
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
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
                        Text(l10n.pullToRefresh),
                      ],
                    ),
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        return ListTile(
          title: Text(device.name),
          trailing: const Icon(Icons.arrow_forward),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DeviceControlScreen(device: device),
              ),
            );
            if (mounted) await _refreshDevices();
          },
          onLongPress: () => _showDeviceOptions(context, device),
        );
      },
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
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      await _refreshDevices();
                    },
                    child: Text(AppLocalizations.of(context)!.save),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () async {
                      await DeviceService.removeDevice(device.id);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                      await _refreshDevices();
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
