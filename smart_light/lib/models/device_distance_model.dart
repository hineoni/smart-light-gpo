class DeviceDistanceModel {
  final String fromDeviceId;
  final String toDeviceId;
  final double distanceM;
  final DateTime? updatedAt;
  final int? rssiDbm;
  final int ageMs;
  final String source;

  const DeviceDistanceModel({
    required this.fromDeviceId,
    required this.toDeviceId,
    required this.distanceM,
    required this.updatedAt,
    required this.rssiDbm,
    required this.ageMs,
    required this.source,
  });

  factory DeviceDistanceModel.fromJson(Map<String, dynamic> json) {
    return DeviceDistanceModel(
      fromDeviceId: json['fromDeviceId'] ?? '',
      toDeviceId: json['toDeviceId'] ?? '',
      distanceM: (json['distanceM'] ?? 0).toDouble(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? ''),
      rssiDbm: json['rssiDbm'] is num ? (json['rssiDbm'] as num).round() : null,
      ageMs: json['ageMs'] is num ? (json['ageMs'] as num).round() : 0,
      source: json['source'] ?? 'device',
    );
  }
}

class PositioningNodeModel {
  final String deviceId;
  final bool online;
  final DateTime? lastSeenAt;
  final bool? uwbReady;
  final int? uwbRangeCount;

  const PositioningNodeModel({
    required this.deviceId,
    required this.online,
    required this.lastSeenAt,
    required this.uwbReady,
    required this.uwbRangeCount,
  });

  factory PositioningNodeModel.fromJson(Map<String, dynamic> json) {
    return PositioningNodeModel(
      deviceId: json['deviceId'] ?? '',
      online: json['online'] == true,
      lastSeenAt: DateTime.tryParse(json['lastSeenAt'] ?? ''),
      uwbReady: json['uwbReady'] is bool ? json['uwbReady'] as bool : null,
      uwbRangeCount: json['uwbRangeCount'] is num
          ? (json['uwbRangeCount'] as num).round()
          : null,
    );
  }
}

class PositioningSummaryModel {
  final List<DeviceDistanceModel> distances;
  final List<PositioningNodeModel> nodes;
  final DateTime? lastUpdated;
  final int ttlMs;

  const PositioningSummaryModel({
    required this.distances,
    required this.nodes,
    required this.lastUpdated,
    required this.ttlMs,
  });

  factory PositioningSummaryModel.fromJson(Map<String, dynamic> json) {
    final distancesJson = (json['distances'] as List? ?? [])
        .whereType<Map<String, dynamic>>();
    final nodesJson = (json['nodes'] as List? ?? [])
        .whereType<Map<String, dynamic>>();

    return PositioningSummaryModel(
      distances: distancesJson.map(DeviceDistanceModel.fromJson).toList(),
      nodes: nodesJson.map(PositioningNodeModel.fromJson).toList(),
      lastUpdated: DateTime.tryParse(json['lastUpdated'] ?? ''),
      ttlMs: json['ttlMs'] is num ? (json['ttlMs'] as num).round() : 5000,
    );
  }

  factory PositioningSummaryModel.fromDistances(
    List<DeviceDistanceModel> distances,
  ) {
    final nodeIds = <String>{};
    for (final distance in distances) {
      nodeIds.add(distance.fromDeviceId);
      nodeIds.add(distance.toDeviceId);
    }

    return PositioningSummaryModel(
      distances: distances,
      nodes: nodeIds
          .map(
            (id) => PositioningNodeModel(
              deviceId: id,
              online: false,
              lastSeenAt: null,
              uwbReady: null,
              uwbRangeCount: null,
            ),
          )
          .toList(),
      lastUpdated: distances
          .where((distance) => distance.updatedAt != null)
          .map((distance) => distance.updatedAt!)
          .fold<DateTime?>(
            null,
            (latest, updatedAt) => latest == null || updatedAt.isAfter(latest)
                ? updatedAt
                : latest,
          ),
      ttlMs: 5000,
    );
  }
}
