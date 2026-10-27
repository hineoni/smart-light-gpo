import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import 'dart:async';
import '../models/device_model.dart';
import '../services/device_service.dart';
import '../widgets/compact_servo_control.dart';
import '../widgets/light_control.dart';
import '../widgets/ambient_light_card.dart';
import '../models/ambient_light_reading.dart';
import '../services/ambient_light_service.dart';
import '../services/app_settings.dart';

class DeviceControlScreen extends StatefulWidget {
  final DeviceModel device;

  const DeviceControlScreen({
    super.key,
    required this.device,
    this.readLamp = AmbientLightService.readLamp,
    this.turnOnLamp = DeviceService.turnOnLamp,
    this.switchOffLamp = DeviceService.switchOffLamp,
    this.setBrightness = DeviceService.applyRecommendedBrightness,
    this.checkOnline = DeviceService.checkDeviceStatus,
  }); // const можно оставить

  final Future<LampState?> Function(String) readLamp;
  final Future<void> Function(DeviceModel, double) turnOnLamp;
  final Future<void> Function(DeviceModel) switchOffLamp;
  final Future<void> Function(String, double) setBrightness;
  final Future<bool> Function(String) checkOnline;

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  Timer? _brightnessTimer;
  Timer? _servo1Timer;
  Timer? _servo2Timer;
  Timer? _stateTimer;
  LampState? _lamp;
  bool _commandPending = false;
  bool _readingState = false;
  bool get _isLightOn => _lamp?.isOn ?? false;
  bool _isDeviceOnline = true; // Статус подключения устройства

  @override
  void initState() {
    super.initState();
    _checkDeviceStatus();
    _refreshLamp();
    _stateTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _refreshLamp(),
    );
  }

  Future<void> _refreshLamp() async {
    if (_readingState ||
        _commandPending ||
        (_brightnessTimer?.isActive ?? false)) {
      return;
    }
    _readingState = true;
    try {
      final lamp = await widget.readLamp(widget.device.id);
      if (!mounted || _commandPending) return;
      setState(() {
        _lamp = lamp;
        if (lamp?.isOn == true) {
          widget.device.brightness = lamp!.brightness / 255;
          widget.device.color = Color.fromRGBO(lamp.r, lamp.g, lamp.b, 1);
          AppSettings.instance.rememberLampBrightness(
            widget.device.id,
            widget.device.brightness,
          );
        } else {
          widget.device.brightness = AppSettings.instance.lastLampBrightness(
            widget.device.id,
            fallback: widget.device.brightness,
          );
        }
      });
    } catch (_) {
      if (mounted) setState(() => _lamp = null);
    } finally {
      _readingState = false;
    }
  }

  Future<void> _runLampCommand(Future<void> Function() command) async {
    if (_commandPending) return;
    setState(() => _commandPending = true);
    try {
      await command();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.lampCommandFailed),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _commandPending = false);
        await _refreshLamp();
      }
    }
  }

  // Проверка статуса устройства при открытии экрана
  void _checkDeviceStatus() async {
    try {
      final response = await widget.checkOnline(widget.device.id);
      if (!mounted) return;
      setState(() {
        _isDeviceOnline = response;
      });

      if (!_isDeviceOnline) {
        _showDeviceOfflineDialog();
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Ошибка проверки статуса устройства: $e');
      setState(() {
        _isDeviceOnline = false;
      });
      _showDeviceOfflineDialog();
    }
  }

  void _showDeviceOfflineDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deviceUnavailable),
        content: Text(
          AppLocalizations.of(
            context,
          )!.deviceUnavailableMessage(widget.device.name),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkDeviceStatus(); // Повторная проверка
            },
            child: Text(AppLocalizations.of(context)!.retry),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _updateBrightnessDebounced(double value) {
    setState(() => widget.device.brightness = value);

    // Отменяем предыдущий таймер
    _brightnessTimer?.cancel();

    // Запускаем новый таймер на 300ms
    _brightnessTimer = Timer(const Duration(milliseconds: 300), () {
      if (_isLightOn) {
        // Отправляем только если свет включен
        _runLampCommand(() => widget.setBrightness(widget.device.id, value));
      }
    });
  }

  void _updateServo1Debounced(double angle) {
    setState(() => widget.device.servo1Angle = angle);

    _servo1Timer?.cancel();
    _servo1Timer = Timer(const Duration(milliseconds: 200), () {
      DeviceService.updateServo(widget.device.id, 1, angle);
    });
  }

  void _updateServo2Debounced(double angle) {
    setState(() => widget.device.servo2Angle = angle);

    _servo2Timer?.cancel();
    _servo2Timer = Timer(const Duration(milliseconds: 200), () {
      DeviceService.updateServo(widget.device.id, 2, angle);
    });
  }

  void _toggleLight() {
    if (_lamp == null || _commandPending) return;
    _brightnessTimer?.cancel();
    if (_isLightOn) {
      AppSettings.instance.rememberLampBrightness(
        widget.device.id,
        widget.device.brightness,
      );
      _runLampCommand(() => widget.switchOffLamp(widget.device));
    } else {
      final brightness = AppSettings.instance.lastLampBrightness(
        widget.device.id,
        fallback: widget.device.brightness,
      );
      _runLampCommand(() => widget.turnOnLamp(widget.device, brightness));
    }
  }

  @override
  void dispose() {
    _brightnessTimer?.cancel();
    _servo1Timer?.cancel();
    _servo2Timer?.cancel();
    _stateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.device.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            LiveAmbientLightCard(deviceId: widget.device.id),
            const SizedBox(height: 20),
            // Компактные сервоприводы в одной строке
            Row(
              children: [
                Expanded(
                  child: CompactServoControl(
                    title: AppLocalizations.of(context)!.servoOne,
                    value: widget.device.servo1Angle,
                    onChanged: _updateServo1Debounced,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CompactServoControl(
                    title: AppLocalizations.of(context)!.servoTwo,
                    value: widget.device.servo2Angle,
                    onChanged: _updateServo2Debounced,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Управление светом с разделением включения и яркости
            LightControl(
              brightness: widget.device.brightness,
              color: widget.device.color,
              isLightOn: _isLightOn,
              enabled: _lamp != null && !_commandPending,
              statusText: _commandPending
                  ? AppLocalizations.of(context)!.lampWaitingConfirmation
                  : _lamp == null
                  ? AppLocalizations.of(context)!.lampStateUnknown
                  : _isLightOn
                  ? '${AppLocalizations.of(context)!.lampIsOn} · ${(_lamp!.brightness * 100 / 255).round()}%'
                  : AppLocalizations.of(context)!.lampIsOff,
              onBrightnessChanged: _updateBrightnessDebounced,
              onColorChanged: (c) {
                setState(() => widget.device.color = c);
                if (_isLightOn) {
                  // Отправляем только если свет включен
                  DeviceService.updateLed(
                    widget.device.id,
                    widget.device.brightness,
                    (c.r * 255).round(),
                    (c.g * 255).round(),
                    (c.b * 255).round(),
                  );
                }
              },
              onToggleLight: _toggleLight,
            ),
          ],
        ),
      ),
    );
  }
}
