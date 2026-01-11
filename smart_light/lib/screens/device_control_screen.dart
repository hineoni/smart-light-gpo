import 'package:flutter/material.dart';
import 'dart:async';
import '../models/device_model.dart';
import '../services/device_service.dart';
import '../widgets/servo_control.dart';
import '../widgets/circular_servo_control.dart';
import '../widgets/compact_servo_control.dart';
import '../widgets/light_control.dart';

class DeviceControlScreen extends StatefulWidget {
  final DeviceModel device;

  const DeviceControlScreen({super.key, required this.device}); // const можно оставить

  @override
  State<DeviceControlScreen> createState() => _DeviceControlScreenState();
}

class _DeviceControlScreenState extends State<DeviceControlScreen> {
  Timer? _brightnessTimer;
  Timer? _servo1Timer;
  Timer? _servo2Timer;
  bool _isLightOn = true; // Состояние включения света
  bool _isDeviceOnline = true; // Статус подключения устройства
  
  @override
  void initState() {
    super.initState();
    _checkDeviceStatus();
  }
  
  // Проверка статуса устройства при открытии экрана
  void _checkDeviceStatus() async {
    try {
      final response = await DeviceService.checkDeviceStatus(widget.device.id);
      setState(() {
        _isDeviceOnline = response;
      });
      
      if (!_isDeviceOnline) {
        _showDeviceOfflineDialog();
      }
    } catch (e) {
      print('Ошибка проверки статуса устройства: $e');
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
        title: const Text('Устройство недоступно'),
        content: Text('Устройство "${widget.device.name}" не отвечает. Проверьте подключение.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkDeviceStatus(); // Повторная проверка
            },
            child: const Text('Повторить'),
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
      if (_isLightOn) { // Отправляем только если свет включен
        DeviceService.updateLed(
          widget.device.id, 
          value, 
          widget.device.color.red, 
          widget.device.color.green, 
          widget.device.color.blue
        );
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
    setState(() {
      _isLightOn = !_isLightOn;
    });
    
    if (_isLightOn) {
      // Включаем свет с текущими параметрами
      DeviceService.updateLed(
        widget.device.id, 
        widget.device.brightness, 
        widget.device.color.red, 
        widget.device.color.green, 
        widget.device.color.blue
      );
    } else {
      // Выключаем свет (clear_leds команда)
      DeviceService.turnOffLeds(widget.device.id);
    }
  }
  
  @override
  void dispose() {
    _brightnessTimer?.cancel();
    _servo1Timer?.cancel();
    _servo2Timer?.cancel();
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
            // Компактные сервоприводы в одной строке
            Row(
              children: [
                Expanded(
                  child: CompactServoControl(
                    title: 'Сервопривод 1',
                    value: widget.device.servo1Angle,
                    onChanged: _updateServo1Debounced,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: CompactServoControl(
                    title: 'Сервопривод 2',
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
              onBrightnessChanged: _updateBrightnessDebounced,
              onColorChanged: (c) {
                setState(() => widget.device.color = c);
                if (_isLightOn) { // Отправляем только если свет включен
                  DeviceService.updateLed(widget.device.id, widget.device.brightness, c.red, c.green, c.blue);
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
