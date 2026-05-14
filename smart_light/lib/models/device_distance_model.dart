class DeviceDistanceModel {
  final String fromDeviceId;
  final String toDeviceId;
  final double distanceM;
  final DateTime? updatedAt;
  final int? rssiDbm;
  final double? stability;
  final String? stabilityLabel;
  final int ageMs;
  final String source;

  const DeviceDistanceModel({
    required this.fromDeviceId,
    required this.toDeviceId,
    required this.distanceM,
    required this.updatedAt,
    required this.rssiDbm,
    required this.stability,
    required this.stabilityLabel,
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
      stability: json['stability'] is num
          ? (json['stability'] as num).toDouble()
          : null,
      stabilityLabel: json['stabilityLabel'] is String
          ? json['stabilityLabel'] as String
          : null,
      ageMs: json['ageMs'] is num ? (json['ageMs'] as num).round() : 0,
      source: json['source'] ?? 'device',
    );
  }
}

class PositioningLayoutNodeModel {
  final String deviceId;
  final double x;
  final double y;
  final String label;

  const PositioningLayoutNodeModel({
    required this.deviceId,
    required this.x,
    required this.y,
    required this.label,
  });

  factory PositioningLayoutNodeModel.fromJson(Map<String, dynamic> json) {
    return PositioningLayoutNodeModel(
      deviceId: json['deviceId'] ?? '',
      x: (json['x'] is num ? json['x'] as num : 0.5).toDouble(),
      y: (json['y'] is num ? json['y'] as num : 0.5).toDouble(),
      label: json['label'] ?? '',
    );
  }
}

class PositioningLayoutModel {
  final List<PositioningLayoutNodeModel> nodes;
  final String method;

  const PositioningLayoutModel({required this.nodes, required this.method});

  factory PositioningLayoutModel.fromJson(Map<String, dynamic>? json) {
    final nodesJson = (json?['nodes'] as List? ?? [])
        .whereType<Map<String, dynamic>>();
    return PositioningLayoutModel(
      nodes: nodesJson.map(PositioningLayoutNodeModel.fromJson).toList(),
      method: json?['method'] is String ? json!['method'] as String : 'none',
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
  final PositioningLayoutModel layout;
  final DateTime? lastUpdated;
  final int ttlMs;

  const PositioningSummaryModel({
    required this.distances,
    required this.nodes,
    required this.layout,
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
      layout: PositioningLayoutModel.fromJson(
        json['layout'] is Map<String, dynamic>
            ? json['layout'] as Map<String, dynamic>
            : null,
      ),
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
      layout: PositioningLayoutModel(
        method: nodeIds.length <= 2 ? 'line' : 'triangle',
        nodes: nodeIds
            .toList()
            .asMap()
            .entries
            .map(
              (entry) => PositioningLayoutNodeModel(
                deviceId: entry.value,
                x: nodeIds.length <= 1
                    ? 0.5
                    : 0.22 + 0.56 * entry.key / (nodeIds.length - 1),
                y: 0.5,
                label: String.fromCharCode(65 + entry.key),
              ),
            )
            .toList(),
      ),
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
