enum AmbientLightLevel { dark, comfortable, bright }

class LampState {
  const LampState({
    required this.isOn,
    required this.brightness,
    required this.r,
    required this.g,
    required this.b,
  });
  final bool isOn;
  final int brightness;
  final int r;
  final int g;
  final int b;

  static LampState? tryParse(dynamic data) {
    if (data is! Map || data['available'] != true || data['isOn'] is! bool) {
      return null;
    }
    for (final key in ['brightness', 'r', 'g', 'b']) {
      final value = data[key];
      if (value is! int || value < 0 || value > 255) return null;
    }
    if (data['isOn'] != (data['brightness'] > 0)) return null;
    return LampState(
      isOn: data['isOn'],
      brightness: data['brightness'],
      r: data['r'],
      g: data['g'],
      b: data['b'],
    );
  }
}

class AmbientLightReading {
  const AmbientLightReading({
    this.available = false,
    this.raw,
    this.percent,
    this.receivedAt,
    this.shared = false,
    this.deviceId,
    this.lamp,
  });

  final bool available;
  final int? raw;
  final int? percent;
  final DateTime? receivedAt;
  final bool shared;
  final String? deviceId;
  final LampState? lamp;
  LampState? get currentLamp => _telemetryFreshAt(DateTime.now()) ? lamp : null;

  factory AmbientLightReading.fromJson(Map<String, dynamic> json) {
    final raw = json['raw'];
    final percent = json['percent'];
    final timestamp = json['receivedAt'];
    final valid =
        json['available'] == true &&
        raw is int &&
        raw >= 0 &&
        raw <= 4095 &&
        percent is int &&
        percent >= 0 &&
        percent <= 100 &&
        timestamp is num &&
        timestamp.isFinite &&
        timestamp > 0;
    return AmbientLightReading(
      available: valid,
      raw: valid ? raw : null,
      percent: valid ? percent : null,
      receivedAt:
          timestamp is num &&
              timestamp.isFinite &&
              timestamp > 0 &&
              timestamp < 8640000000000000
          ? DateTime.fromMillisecondsSinceEpoch(timestamp.toInt())
          : null,
      shared: json['shared'] == true,
      deviceId: json['deviceId'] is String ? json['deviceId'] as String : null,
      lamp: LampState.tryParse(json['lamp']),
    );
  }

  bool isFreshAt(DateTime now) {
    if (!available || percent == null) return false;
    return _telemetryFreshAt(now);
  }

  bool _telemetryFreshAt(DateTime now) {
    final timestamp = receivedAt;
    if (timestamp == null) return false;
    final age = now.difference(timestamp);
    return age >= const Duration(seconds: -5) &&
        age <= Duration(seconds: shared ? 5 : 30);
  }

  bool get isFresh => isFreshAt(DateTime.now());

  AmbientLightLevel? get level {
    if (!isFresh) return null;
    if (percent! < 35) return AmbientLightLevel.dark;
    if (percent! > 65) return AmbientLightLevel.bright;
    return AmbientLightLevel.comfortable;
  }

  double? recommendedBrightness(double current) {
    if (!current.isFinite) return null;
    final currentLevel = level;
    if (currentLevel == null || currentLevel == AmbientLightLevel.comfortable) {
      return null;
    }
    final normalized = current.clamp(0.0, 1.0);
    // Initial relative-scale rule: compensate the distance from the midpoint.
    // A 35–65% deadband avoids small corrections near the midpoint.
    final target = (normalized + (50 - percent!) / 100).clamp(0.0, 1.0);
    return (target - normalized).abs() < 0.005 ? null : target;
  }
}
