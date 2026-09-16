import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/device_service.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.addDevice)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: l10n.deviceName),
            ),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: l10n.optionalDeviceId,
              ),
            ),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: l10n.optionalIpAddress,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                final name = _nameController.text.trim();
                final id = _idController.text.trim().isNotEmpty
                    ? _idController.text.trim()
                    : null;
                final ip = _ipController.text.trim().isNotEmpty
                    ? _ipController.text.trim()
                    : 'unknown';
                if (name.isNotEmpty) {
                  await DeviceService.addDevice(name, id: id, ip: ip);
                  Navigator.pop(context);
                }
              },
              child: Text(l10n.add),
            ),
          ],
        ),
      ),
    );
  }
}
