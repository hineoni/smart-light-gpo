class RoomZoneModel {
  final String id;
  final String name;
  final double x;
  final double y;
  final double? heightM;

  const RoomZoneModel({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.heightM,
  });

  factory RoomZoneModel.fromJson(Map<String, dynamic> json) {
    return RoomZoneModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Зона',
      x: (json['x'] is num ? json['x'] as num : 0.5).toDouble(),
      y: (json['y'] is num ? json['y'] as num : 0.5).toDouble(),
      heightM: json['heightM'] is num
          ? (json['heightM'] as num).toDouble()
          : null,
    );
  }
}

class SceneDeviceStateModel {
  final String deviceId;
  final String? zoneId;
  final double brightness;
  final int colorR;
  final int colorG;
  final int colorB;
  final double servo1Angle;
  final double servo2Angle;
  final double? x;
  final double? y;
  final double? heightM;

  const SceneDeviceStateModel({
    required this.deviceId,
    required this.zoneId,
    required this.brightness,
    required this.colorR,
    required this.colorG,
    required this.colorB,
    required this.servo1Angle,
    required this.servo2Angle,
    required this.x,
    required this.y,
    required this.heightM,
  });

  factory SceneDeviceStateModel.fromJson(Map<String, dynamic> json) {
    return SceneDeviceStateModel(
      deviceId: json['deviceId'] ?? '',
      zoneId: json['zoneId'] is String ? json['zoneId'] as String : null,
      brightness: (json['brightness'] is num ? json['brightness'] as num : 0.5)
          .toDouble(),
      colorR: json['colorR'] is num ? (json['colorR'] as num).round() : 255,
      colorG: json['colorG'] is num ? (json['colorG'] as num).round() : 255,
      colorB: json['colorB'] is num ? (json['colorB'] as num).round() : 255,
      servo1Angle:
          (json['servo1Angle'] is num ? json['servo1Angle'] as num : 90)
              .toDouble(),
      servo2Angle:
          (json['servo2Angle'] is num ? json['servo2Angle'] as num : 90)
              .toDouble(),
      x: json['x'] is num ? (json['x'] as num).toDouble() : null,
      y: json['y'] is num ? (json['y'] as num).toDouble() : null,
      heightM: json['heightM'] is num
          ? (json['heightM'] as num).toDouble()
          : null,
    );
  }
}

class LightSceneModel {
  final String id;
  final String name;
  final String? zoneId;
  final List<SceneDeviceStateModel> devices;
  final DateTime? updatedAt;

  const LightSceneModel({
    required this.id,
    required this.name,
    required this.zoneId,
    required this.devices,
    required this.updatedAt,
  });

  factory LightSceneModel.fromJson(Map<String, dynamic> json) {
    final devicesJson = (json['devices'] as List? ?? [])
        .whereType<Map<String, dynamic>>();
    return LightSceneModel(
      id: json['id'] ?? '',
      name: json['name'] ?? 'Сцена',
      zoneId: json['zoneId'] is String ? json['zoneId'] as String : null,
      devices: devicesJson.map(SceneDeviceStateModel.fromJson).toList(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? ''),
    );
  }
}
