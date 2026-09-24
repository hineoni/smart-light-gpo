import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/api_config.dart';
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
  final TextEditingController ssidController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController deviceIpController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeBle();
  }

  @override
  void dispose() {
    BleProvisioningService.cleanup();
    ssidController.dispose();
    passwordController.dispose();
    deviceIpController.dispose();
    super.dispose();
  }

  Future<void> _initializeBle() async {
    final hasPermissions = await BleProvisioningService.requestPermissions();
    if (!hasPermissions) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.blePermissionsRequired),
          ),
        );
      }
      return;
    }
    _startScan();
  }

  Future<void> _startScan() async {
    if (isScanning) return;
    setState(() {
      isScanning = true;
      devices.clear(); // Очищаем список перед новым сканированием
    });

    try {
      final deviceList = await BleProvisioningService.scanDevices(
        timeout: const Duration(seconds: 15),
      );
      if (mounted) {
        setState(() {
          devices = deviceList;
          isScanning = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isScanning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.scanFailed(e.toString()),
            ),
          ),
        );
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
      print('  Backend URL: ${ApiConfig.deviceProvisioningBackendUrl}');

      final success =
          await BleProvisioningService.provisionDeviceWithCustomData(
            deviceName: selectedDevice!,
            proofOfPossession: 'abcd1234',
            ssid: ssidController.text,
            password: passwordController.text,
            wsUrl: ApiConfig.deviceProvisioningBackendUrl,
            deviceId: '', // ESP32 сам определит свой ID
          );

      if (mounted) {
        setState(() => isProvisioning = false);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.deviceConfigured),
              duration: Duration(seconds: 3),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        } else {
          // Показываем опцию ручной настройки
          _showManualSetupDialog();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isProvisioning = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorWithDetails(e.toString()),
            ),
          ),
        );
      }
    }
  }

  Future<void> _showManualSetupDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.manualBackendSetup),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppLocalizations.of(context)!.manualBackendSetupDescription),
              const SizedBox(height: 16),
              TextField(
                controller: deviceIpController,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.deviceIpAddress,
                  hintText: AppLocalizations.of(context)!.deviceIpExample,
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(AppLocalizations.of(context)!.skip),
            ),
            ElevatedButton(
              onPressed: _setupBackendManually,
              child: Text(AppLocalizations.of(context)!.setup),
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
        ApiConfig.deviceProvisioningBackendUrl,
      );

      if (mounted) {
        setState(() => isManualSetup = false);

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.backendConfigured),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.manualSetupFailed),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isManualSetup = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorWithDetails(e.toString()),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.bleProvisioning)),
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
                      isScanning ? l10n.scanning : l10n.scanForDevices,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(l10n.foundDevices(devices.length)),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: devices.isEmpty
                  ? Center(
                      child: Text(
                        isScanning
                            ? l10n.scanningForDevices
                            : l10n.noDevicesFound,
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
                              ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
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
                            subtitle: Text(l10n.esp32Device),
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
                        l10n.fullDeviceConfiguration,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.configurationDescription,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: ssidController,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Wi-Fi SSID',
                          prefixIcon: Icon(Icons.wifi),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: l10n.wifiPassword,
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        obscureText: true,
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
                                ? l10n.selectDeviceFirst
                                : isProvisioning
                                ? l10n.provisioning
                                : l10n.provisionDevice,
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
