class DeviceDistanceModel {
  final String fromDeviceId;
  final String toDeviceId;
  final double distanceM;
  final DateTime? updatedAt;
  final String source;

  const DeviceDistanceModel({
    required this.fromDeviceId,
    required this.toDeviceId,
    required this.distanceM,
    required this.updatedAt,
    required this.source,
  });

  factory DeviceDistanceModel.fromJson(Map<String, dynamic> json) {
    return DeviceDistanceModel(
      fromDeviceId: json['fromDeviceId'] ?? '',
      toDeviceId: json['toDeviceId'] ?? '',
      distanceM: (json['distanceM'] ?? 0).toDouble(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? ''),
      source: json['source'] ?? 'device',
    );
  }
}
