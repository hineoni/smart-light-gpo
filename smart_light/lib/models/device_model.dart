import 'package:flutter/material.dart';

class DeviceModel {
  final String id;
  String name;

  double servo1Angle;
  double servo2Angle;

  double brightness;
  Color color;

  DeviceModel({
    required this.id,
    required this.name,
    this.servo1Angle = 90,
    this.servo2Angle = 90,
    this.brightness = 0.5,
    this.color = Colors.white,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    // Безопасное преобразование servo углов (0-180) -> нормализация не нужна
    double servo1 = (json['servo1Angle'] ?? 90).toDouble();
    double servo2 = (json['servo2Angle'] ?? 90).toDouble();
    
    // Brightness должен быть от 0.0 до 1.0
    double brightness = (json['brightness'] ?? 0.5).toDouble();
    // Если brightness больше 1.0, нормализуем (возможно пришел 0-255)
    if (brightness > 1.0) {
      brightness = brightness / 255.0;
    }
    
    return DeviceModel(
      id: json['id'] ?? json['deviceId'],
      name: json['name'] ?? 'Unknown Device',
      servo1Angle: servo1.clamp(0.0, 180.0), // Углы сервоприводов 0-180
      servo2Angle: servo2.clamp(0.0, 180.0), // Углы сервоприводов 0-180
      brightness: brightness.clamp(0.0, 1.0), // Яркость 0.0-1.0
      color: Color.fromRGBO(
        json['colorR'] ?? 255,
        json['colorG'] ?? 255,
        json['colorB'] ?? 255,
        1.0,
      ),
    );
  }

  factory DeviceModel.fromOnlineJson(Map<String, dynamic> json) {
    // Безопасное преобразование для online данных
    double servo1 = (json['servo1Angle'] ?? 90).toDouble();
    double servo2 = (json['servo2Angle'] ?? 90).toDouble();
    
    return DeviceModel(
      id: json['deviceId'],
      name: json['name'] ?? 'Unknown Device',
      servo1Angle: servo1.clamp(0.0, 180.0), // Углы сервоприводов 0-180
      servo2Angle: servo2.clamp(0.0, 180.0), // Углы сервоприводов 0-180
      brightness: 0.5, // Default brightness
      color: Colors.white, // Default color
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'servo1Angle': servo1Angle,
      'servo2Angle': servo2Angle,
      'brightness': brightness,
      'colorR': color.red,
      'colorG': color.green,
      'colorB': color.blue,
    };
  }
}
