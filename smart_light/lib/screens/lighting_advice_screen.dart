import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/ambient_light_reading.dart';
import '../models/device_model.dart';
import '../services/ambient_light_service.dart';
import '../services/app_settings.dart';
import '../services/device_service.dart';
import '../widgets/ambient_light_card.dart';

class LightingAdviceScreen extends StatefulWidget {
  const LightingAdviceScreen({
    super.key,
    this.loadDevices = DeviceService.getDevices,
    this.loadReading = AmbientLightService.read,
    this.applyBrightness = DeviceService.applyRecommendedBrightness,
    this.loadSensorDevice = DeviceService.claimSensorDevice,
    this.turnOnLamp = DeviceService.turnOnLamp,
  });

  final Future<List<DeviceModel>> Function() loadDevices;
  final Future<AmbientLightReading> Function(String?) loadReading;
  final Future<void> Function(String, double) applyBrightness;
  final Future<List<DeviceModel>> Function(String) loadSensorDevice;
  final Future<void> Function(DeviceModel, double) turnOnLamp;

  @override
  State<LightingAdviceScreen> createState() => _LightingAdviceScreenState();
}

class _LightingAdviceScreenState extends State<LightingAdviceScreen> {
  Timer? _timer;
  List<DeviceModel> _devices = [];
  DeviceModel? _selectedDevice;
  AmbientLightReading? _reading;
  bool _hasError = false;
  bool _fetching = false;
  bool _applying = false;
  DateTime? _appliedAt;
  String? _appliedDeviceId;
  int _selectionVersion = 0;
  String? _lookedUpSensorId;
  bool _sensorLampOnly = AmbientLightService.usesSharedUsbSensor;

  bool get _onlySensorLamp => _sensorLampOnly;
  LampState? get _lamp =>
      _selectedDevice?.id == _reading?.deviceId ? _reading?.currentLamp : null;
  double? get _recommendedBrightness {
    final device = _selectedDevice;
    final lamp = _lamp;
    if (device == null || lamp == null) return null;
    final current = lamp.isOn
        ? lamp.brightness / 255
        : AppSettings.instance.lastLampBrightness(
            device.id,
            fallback: device.brightness,
          );
    if (!lamp.isOn) {
      return _reading?.level == AmbientLightLevel.dark
          ? _reading?.recommendedBrightness(current) ?? current
          : null;
    }
    return _reading?.recommendedBrightness(current);
  }

  String? get _sensorDeviceId => _reading?.deviceId;

  List<DeviceModel> get _eligibleDevices => _onlySensorLamp
      ? _devices.where((device) => device.id == _sensorDeviceId).toList()
      : _devices;

  void _selectSensorLamp() {
    final eligible = _eligibleDevices;
    _selectedDevice = eligible.isEmpty ? null : eligible.first;
  }

  bool get _waitingAfterApply =>
      _appliedAt != null &&
      _appliedDeviceId == _selectedDevice?.id &&
      !(_reading?.receivedAt?.isAfter(_appliedAt!) ?? false);

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await widget.loadDevices();
      if (!mounted) return;
      setState(() {
        _devices = List.of(devices);
        _selectSensorLamp();
        _selectionVersion++;
      });
      _refresh();
    } catch (_) {
      // Shared USB readings still work when there is no selectable lamp.
    }
  }

  Future<void> _refresh() async {
    if (_fetching) return;
    _fetching = true;
    final version = _selectionVersion;
    try {
      final reading = await widget.loadReading(_selectedDevice?.id);
      List<DeviceModel> sensorDevices = [];
      final sensorId = reading.deviceId;
      if (reading.shared &&
          sensorId != null &&
          _lookedUpSensorId != sensorId &&
          !_devices.any((device) => device.id == sensorId)) {
        _lookedUpSensorId = sensorId;
        sensorDevices = await widget.loadSensorDevice(sensorId);
      }
      if (mounted && (reading.shared || version == _selectionVersion)) {
        setState(() {
          _reading = reading;
          if (reading.shared) _sensorLampOnly = true;
          for (final device in sensorDevices.where(
            (device) => device.id == sensorId,
          )) {
            if (!_devices.any((existing) => existing.id == device.id)) {
              _devices.add(device);
            }
          }
          if (reading.shared) _selectSensorLamp();
          final lamp = reading.currentLamp;
          if (_selectedDevice?.id == reading.deviceId &&
              lamp?.isOn == true &&
              !_applying) {
            _selectedDevice!.brightness = lamp!.brightness / 255;
            AppSettings.instance.rememberLampBrightness(
              _selectedDevice!.id,
              _selectedDevice!.brightness,
            );
          }
          _hasError = false;
        });
      }
    } catch (_) {
      if (mounted && version == _selectionVersion) {
        setState(() {
          _reading = null;
          _hasError = true;
        });
      }
    } finally {
      _fetching = false;
    }
  }

  Future<void> _apply() async {
    final device = _selectedDevice;
    final target = _recommendedBrightness;
    if (_applying ||
        target == null ||
        !AppSettings.instance.lightingAdviceEnabled ||
        (_onlySensorLamp && device?.id != _sensorDeviceId) ||
        _waitingAfterApply) {
      return;
    }
    setState(() => _applying = true);
    try {
      if (_lamp?.isOn == false) {
        await widget.turnOnLamp(device!, target);
      } else {
        await widget.applyBrightness(device!.id, target);
      }
      if (!mounted) return;
      setState(() {
        device.brightness = target;
        _appliedAt = DateTime.now();
        _appliedDeviceId = device.id;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.lightingAdviceApplied),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.lightingAdviceApplyFailed,
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _applying = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(l10n.lightingAdvice)),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final sensor = AmbientLightCard(
                        reading: _reading,
                        loading: _reading == null && !_hasError,
                        hasError: _hasError,
                        onRefresh: _refresh,
                      );
                      final advice = _buildAdvice(context, l10n);
                      if (constraints.maxWidth >= 760) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: sensor),
                            const SizedBox(width: 20),
                            Expanded(child: advice),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [sensor, const SizedBox(height: 20), advice],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Card(
                    margin: EdgeInsets.zero,
                    child: ExpansionTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(l10n.lightingAdviceHowItWorks),
                      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        Text(l10n.lightingAdviceThresholds),
                        const SizedBox(height: 16),
                        Table(
                          columnWidths: const {
                            0: FlexColumnWidth(),
                            1: FlexColumnWidth(),
                          },
                          children: [
                            TableRow(
                              children: [
                                Text(l10n.ambientLight),
                                Text(l10n.lightingAdviceCorrection),
                              ],
                            ),
                            for (final example in const [
                              '10%|+40',
                              '30%|+20',
                              '35–65%|0',
                              '70%|−20',
                              '90%|−40',
                            ])
                              TableRow(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(example.split('|')[0]),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 10),
                                    child: Text(
                                      '${example.split('|')[1]} ${l10n.lightingAdvicePoints}',
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdvice(BuildContext context, AppLocalizations l10n) {
    final settings = AppSettings.instance;
    final level = _reading?.level;
    final device = _selectedDevice;
    final target = _recommendedBrightness;
    final title = switch (level) {
      AmbientLightLevel.dark => l10n.lightingAdviceDarkTitle,
      AmbientLightLevel.bright => l10n.lightingAdviceBrightTitle,
      AmbientLightLevel.comfortable => l10n.lightingAdviceComfortTitle,
      null => l10n.ambientNoData,
    };
    final body = switch (level) {
      AmbientLightLevel.dark => l10n.lightingAdviceDarkBody,
      AmbientLightLevel.bright => l10n.lightingAdviceBrightBody,
      AmbientLightLevel.comfortable => l10n.lightingAdviceComfortBody,
      null => l10n.ambientWaiting,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    settings.lightingAdviceEnabled
                        ? title
                        : l10n.lightingAdviceDisabled,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!settings.lightingAdviceEnabled) ...[
              Text(l10n.lightingAdviceDisabledDescription),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => settings.setLightingAdviceEnabled(true),
                child: Text(l10n.lightingAdviceEnable),
              ),
            ] else ...[
              Text(body),
              const SizedBox(height: 20),
              if (_eligibleDevices.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: device?.id,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l10n.lightingAdviceChooseLamp,
                  ),
                  items: [
                    for (final item in _eligibleDevices)
                      DropdownMenuItem(
                        value: item.id,
                        child: Text(item.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: _applying
                      ? null
                      : (id) {
                          if (id == null) return;
                          setState(() {
                            _selectedDevice = _devices.firstWhere(
                              (item) => item.id == id,
                            );
                            if (!AmbientLightService.usesSharedUsbSensor) {
                              _reading = null;
                            }
                            _selectionVersion++;
                          });
                          _refresh();
                        },
                )
              else
                Text(
                  _reading == null && !_hasError
                      ? l10n.ambientLoading
                      : _onlySensorLamp
                      ? l10n.lightingAdviceSensorLampMissing
                      : l10n.lightingAdviceNoLamps,
                ),
              if (device != null) ...[
                const SizedBox(height: 12),
                Text(
                  _lamp == null
                      ? l10n.lampStateUnknown
                      : !_lamp!.isOn
                      ? l10n.lampIsOff
                      : '${l10n.lightingAdviceCurrentBrightness}: ${(_lamp!.brightness * 100 / 255).round()}%',
                ),
              ],
              if (_waitingAfterApply) ...[
                const SizedBox(height: 16),
                Text(l10n.ambientWaiting),
              ] else if (target != null) ...[
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const Key('applyLightingAdvice'),
                  onPressed: _applying ? null : _apply,
                  icon: _applying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    _applying
                        ? l10n.lightingAdviceApplying
                        : '${_lamp?.isOn == false ? l10n.lampTurnOnAt : l10n.lightingAdviceApply} ${(target * 100).round()}%',
                  ),
                ),
              ] else if (device != null &&
                  _lamp?.isOn == true &&
                  (level == AmbientLightLevel.dark ||
                      level == AmbientLightLevel.bright)) ...[
                const SizedBox(height: 16),
                Text(l10n.lightingAdviceAtLimit),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
