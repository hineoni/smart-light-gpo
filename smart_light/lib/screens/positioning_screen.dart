import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/device_distance_model.dart';
import '../models/device_model.dart';
import '../models/light_scene_model.dart';
import '../services/device_service.dart';

class PositioningScreen extends StatefulWidget {
  const PositioningScreen({super.key});

  @override
  State<PositioningScreen> createState() => _PositioningScreenState();
}

class _PositioningScreenState extends State<PositioningScreen> {
  Timer? _refreshTimer;
  PositioningSummaryModel _summary = const PositioningSummaryModel(
    distances: [],
    nodes: [],
    layout: PositioningLayoutModel(nodes: [], method: 'none'),
    lastUpdated: null,
    ttlMs: 5000,
  );
  List<DeviceModel> _devices = [];
  List<RoomZoneModel> _zones = [];
  List<LightSceneModel> _scenes = [];
  String? _selectedZoneId;
  bool _isLoading = true;
  bool _isSavingScene = false;
  DateTime? _lastPolledAt;

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _loadData(showLoader: false);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadData({bool showLoader = true}) async {
    if (showLoader) {
      setState(() => _isLoading = true);
    }

    final devicesFuture = DeviceService.getDevices();
    final summaryFuture = DeviceService.getPositioningSummary();
    final zonesFuture = DeviceService.getZones();
    final scenesFuture = DeviceService.getScenes();
    final devices = await devicesFuture;
    final summary = await summaryFuture;
    final zones = await zonesFuture;
    final scenes = await scenesFuture;

    if (!mounted) return;

    setState(() {
      _devices = devices;
      _summary = summary;
      _zones = zones;
      _scenes = scenes;
      _selectedZoneId ??= zones.isNotEmpty ? zones.first.id : null;
      _lastPolledAt = DateTime.now();
      _isLoading = false;
    });
  }

  String _deviceName(String id) {
    for (final device in _devices) {
      if (device.id == id) {
        return device.name;
      }
    }
    return id;
  }

  String _nodeLabel(String id) {
    final suffix = id.length >= 4
        ? id.substring(id.length - 4).toUpperCase()
        : id;
    return 'Плата $suffix';
  }

  String _timeLabel(DateTime? value) {
    if (value == null) return 'нет данных';
    return '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}:'
        '${value.second.toString().padLeft(2, '0')}';
  }

  String _ageLabel(DeviceDistanceModel distance) {
    if (distance.ageMs <= 0) return 'только что';
    if (distance.ageMs < 1000) return '${distance.ageMs} мс';
    return '${(distance.ageMs / 1000).toStringAsFixed(1)} с';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Расположение'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Обновить',
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildStatusPanel(context),
                  const SizedBox(height: 16),
                  _buildPositionScheme(context),
                  const SizedBox(height: 16),
                  _buildScenesPanel(context),
                  const SizedBox(height: 16),
                  _buildOrientationPanel(context),
                  const SizedBox(height: 16),
                  if (_summary.distances.isEmpty)
                    _buildEmptyState()
                  else
                    _buildDistanceList(context),
                ],
              ),
      ),
    );
  }

  Widget _buildScenesPanel(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Световые сцены',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                FilledButton.icon(
                  icon: _isSavingScene
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bookmark_add_outlined),
                  label: const Text('Сохранить'),
                  onPressed: _isSavingScene ? null : _saveCurrentScene,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_zones.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _selectedZoneId,
                decoration: const InputDecoration(
                  labelText: 'Зона для новой сцены',
                  border: OutlineInputBorder(),
                ),
                items: _zones
                    .map(
                      (zone) => DropdownMenuItem(
                        value: zone.id,
                        child: Text(
                          '${zone.name}${zone.heightM == null ? '' : ' · ${zone.heightM!.toStringAsFixed(1)} м'}',
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _selectedZoneId = value),
              ),
            const SizedBox(height: 12),
            if (_scenes.isEmpty)
              Text(
                'Сохраненных сцен пока нет',
                style: theme.textTheme.bodySmall,
              )
            else
              ..._scenes.take(4).map((scene) {
                final zoneName = _zones
                    .where((zone) => zone.id == scene.zoneId)
                    .map((zone) => zone.name)
                    .firstOrNull;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.light_mode_outlined),
                  title: Text(scene.name),
                  subtitle: Text(
                    '${scene.devices.length} плат${zoneName == null ? '' : ' · $zoneName'}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.play_arrow),
                    tooltip: 'Применить сцену',
                    onPressed: () => _applyScene(scene.id),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCurrentScene() async {
    setState(() => _isSavingScene = true);
    final scene = await DeviceService.saveScene(
      'Сцена ${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      zoneId: _selectedZoneId,
    );
    if (!mounted) return;

    setState(() => _isSavingScene = false);
    if (scene == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить сцену')),
      );
      return;
    }

    await _loadData(showLoader: false);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Сцена "${scene.name}" сохранена')));
  }

  Future<void> _applyScene(String sceneId) async {
    final ok = await DeviceService.applyScene(sceneId);
    if (!mounted) return;
    await _loadData(showLoader: false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Сцена применена' : 'Не удалось применить сцену'),
      ),
    );
  }

  Widget _buildStatusPanel(BuildContext context) {
    final theme = Theme.of(context);
    final onlineCount = _summary.nodes.where((node) => node.online).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.sensors),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Узлов: ${_summary.nodes.length} · онлайн: $onlineCount'),
                const SizedBox(height: 4),
                Text(
                  'Данные: ${_timeLabel(_summary.lastUpdated)} · опрос: ${_timeLabel(_lastPolledAt)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPositionScheme(BuildContext context) {
    final theme = Theme.of(context);
    final nodes = _summary.nodes.isNotEmpty
        ? _summary.nodes
        : _devices
              .map(
                (device) => PositioningNodeModel(
                  deviceId: device.id,
                  online: false,
                  lastSeenAt: null,
                  uwbReady: null,
                  uwbRangeCount: null,
                ),
              )
              .take(3)
              .toList();

    return SizedBox(
      height: 260,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: nodes.isEmpty
            ? const Center(child: Icon(Icons.hub_outlined, size: 56))
            : Padding(
                padding: const EdgeInsets.all(12),
                child: CustomPaint(
                  painter: _PositioningPainter(
                    nodes: nodes.take(3).toList(),
                    distances: _summary.distances,
                    layout: _summary.layout,
                    labels: {
                      for (final node in nodes.take(3))
                        node.deviceId: _nodeLabel(node.deviceId),
                    },
                    colorScheme: theme.colorScheme,
                    textStyle:
                        theme.textTheme.labelMedium ??
                        const TextStyle(fontSize: 12),
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
      ),
    );
  }

  Widget _buildOrientationPanel(BuildContext context) {
    final theme = Theme.of(context);
    final nodeIds = _summary.nodes.map((node) => node.deviceId).toSet();
    final visibleDevices = _devices
        .where((device) => nodeIds.isEmpty || nodeIds.contains(device.id))
        .take(3)
        .toList();

    if (visibleDevices.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Направление ламп',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...visibleDevices.map((device) {
          final pan = device.servo1Angle.round();
          final tilt = device.servo2Angle.round();
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.explore_outlined),
              title: Text(_deviceName(device.id)),
              subtitle: Text(
                '${_panLabel(device.servo1Angle)} · ${_tiltLabel(device.servo2Angle)} · высота не задана',
              ),
              trailing: Text(
                '$pan° / $tilt°',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  String _panLabel(double angle) {
    if (angle < 70) return 'влево';
    if (angle > 110) return 'вправо';
    return 'по центру';
  }

  String _tiltLabel(double angle) {
    if (angle < 70) return 'вверх';
    if (angle > 110) return 'вниз';
    return 'горизонтально';
  }

  Widget _buildEmptyState() {
    final hasUwbHeartbeat = _summary.nodes.any(
      (node) => node.uwbReady != null || node.uwbRangeCount != null,
    );
    final uwbStatus = hasUwbHeartbeat
        ? _summary.nodes
              .map(
                (node) =>
                    '${_nodeLabel(node.deviceId)}: UWB ${node.uwbReady == true ? 'ready' : 'not ready'}, ranges ${node.uwbRangeCount ?? 0}',
              )
              .join('\n')
        : 'UWB-статус пока не пришел в heartbeat';

    return Padding(
      padding: const EdgeInsets.only(top: 80),
      child: Column(
        children: [
          const Icon(Icons.social_distance, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Расстояния пока не получены',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 8),
          Text(
            '$uwbStatus\nДанные появятся, когда UWB-модуль отдаст range-фрейм',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildDistanceList(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Расстояния между платами',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ..._summary.distances.map((distance) {
          final rssi = distance.rssiDbm == null
              ? 'RSSI нет'
              : '${distance.rssiDbm} dBm';
          final stability = _PositioningPainter.stabilityText(distance);

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.straighten),
              title: Text(
                '${_deviceName(distance.fromDeviceId)} → ${_deviceName(distance.toDeviceId)}',
              ),
              subtitle: Text(
                '${distance.source == 'mock' ? 'тестовые данные' : 'данные с устройства'} · $stability · $rssi · ${_ageLabel(distance)}',
              ),
              trailing: Text(
                '${distance.distanceM.toStringAsFixed(2)} м',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _PositioningPainter extends CustomPainter {
  final List<PositioningNodeModel> nodes;
  final List<DeviceDistanceModel> distances;
  final PositioningLayoutModel layout;
  final Map<String, String> labels;
  final ColorScheme colorScheme;
  final TextStyle textStyle;

  const _PositioningPainter({
    required this.nodes,
    required this.distances,
    required this.layout,
    required this.labels,
    required this.colorScheme,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (layout.nodes.isEmpty && nodes.length == 2) {
      _paintTwoNodeRuler(canvas, size);
      return;
    }

    final positions = _positionsFor(size);
    for (final distance in distances) {
      final from = positions[distance.fromDeviceId];
      final to = positions[distance.toDeviceId];
      if (from == null || to == null) continue;
      final linePaint = Paint()
        ..color = _stabilityColor(distance)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(from, to, linePaint);
      _drawText(
        canvas,
        '${distance.distanceM.toStringAsFixed(2)} м · ${stabilityText(distance)}',
        Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2 - 18),
        textStyle.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      );
    }

    for (final node in nodes) {
      final center = positions[node.deviceId];
      if (center == null) continue;

      final fill = Paint()
        ..color = node.online ? colorScheme.primary : colorScheme.secondary;
      final border = Paint()
        ..color = colorScheme.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;

      canvas.drawCircle(center, 22, fill);
      canvas.drawCircle(center, 22, border);
      _drawText(
        canvas,
        labels[node.deviceId] ?? node.deviceId,
        center + const Offset(0, 34),
        textStyle.copyWith(color: colorScheme.onSurface),
      );
    }
  }

  Map<String, Offset> _positionsFor(Size size) {
    if (layout.nodes.isNotEmpty) {
      return {
        for (final node in layout.nodes)
          node.deviceId: Offset(
            node.x.clamp(0.0, 1.0) * size.width,
            node.y.clamp(0.0, 1.0) * size.height,
          ),
      };
    }

    final center = Offset(size.width / 2, size.height / 2 - 8);
    final radius = math.min(size.width, size.height) * 0.32;

    if (nodes.length == 1) {
      return {nodes.first.deviceId: center};
    }

    return {
      for (var i = 0; i < nodes.length; i++)
        nodes[i].deviceId: Offset(
          center.dx +
              math.cos(-math.pi / 2 + i * 2 * math.pi / nodes.length) * radius,
          center.dy +
              math.sin(-math.pi / 2 + i * 2 * math.pi / nodes.length) * radius,
        ),
    };
  }

  Color _stabilityColor(DeviceDistanceModel distance) {
    switch (distance.stabilityLabel) {
      case 'stable':
        return colorScheme.primary;
      case 'moving':
        return colorScheme.tertiary;
      case 'weak':
        return colorScheme.error;
      default:
        return colorScheme.outline;
    }
  }

  static String stabilityText(DeviceDistanceModel distance) {
    switch (distance.stabilityLabel) {
      case 'stable':
        return 'стабильно';
      case 'moving':
        return 'движение';
      case 'weak':
        return 'слабый сигнал';
      default:
        return 'оценка';
    }
  }

  void _paintTwoNodeRuler(Canvas canvas, Size size) {
    final distance = distances
        .where(
          (item) =>
              nodes.any((node) => node.deviceId == item.fromDeviceId) &&
              nodes.any((node) => node.deviceId == item.toDeviceId),
        )
        .firstOrNull;
    final fromNode = distance == null
        ? nodes.first
        : nodes.firstWhere((node) => node.deviceId == distance.fromDeviceId);
    final toNode = distance == null
        ? nodes.last
        : nodes.firstWhere((node) => node.deviceId == distance.toDeviceId);

    final left = Offset(size.width * 0.24, size.height * 0.48);
    final right = Offset(size.width * 0.76, size.height * 0.48);
    final linePaint = Paint()
      ..color = colorScheme.primary.withValues(alpha: 0.75)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final tickPaint = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(left, right, linePaint);
    for (var i = 0; i <= 4; i++) {
      final x = left.dx + (right.dx - left.dx) * i / 4;
      canvas.drawLine(
        Offset(x, left.dy - 10),
        Offset(x, left.dy + 10),
        tickPaint,
      );
    }

    if (distance != null) {
      final label = '${distance.distanceM.toStringAsFixed(2)} м';
      final bubbleStyle = textStyle.copyWith(
        color: colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.w700,
      );
      final textPainter = TextPainter(
        text: TextSpan(text: label, style: bubbleStyle),
        maxLines: 1,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();
      final bubbleCenter = Offset(size.width / 2, left.dy - 42);
      final bubbleRect = Rect.fromCenter(
        center: bubbleCenter,
        width: textPainter.width + 24,
        height: textPainter.height + 14,
      );
      final bubblePaint = Paint()..color = colorScheme.primaryContainer;
      canvas.drawRRect(
        RRect.fromRectAndRadius(bubbleRect, const Radius.circular(8)),
        bubblePaint,
      );
      textPainter.paint(
        canvas,
        bubbleRect.center -
            Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    _drawNode(canvas, left, fromNode);
    _drawNode(canvas, right, toNode);
    _drawText(
      canvas,
      labels[fromNode.deviceId] ?? fromNode.deviceId,
      left + const Offset(0, 42),
      textStyle.copyWith(color: colorScheme.onSurface),
    );
    _drawText(
      canvas,
      labels[toNode.deviceId] ?? toNode.deviceId,
      right + const Offset(0, 42),
      textStyle.copyWith(color: colorScheme.onSurface),
    );
  }

  void _drawNode(Canvas canvas, Offset center, PositioningNodeModel node) {
    final fill = Paint()
      ..color = node.online ? colorScheme.primary : colorScheme.secondary;
    final border = Paint()
      ..color = colorScheme.surface
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawCircle(center, 24, fill);
    canvas.drawCircle(center, 24, border);
    final iconStyle = textStyle.copyWith(
      color: colorScheme.onPrimary,
      fontWeight: FontWeight.w800,
    );
    _drawText(canvas, node.online ? 'ON' : 'OFF', center, iconStyle);
  }

  void _drawText(Canvas canvas, String text, Offset center, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 96);

    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _PositioningPainter oldDelegate) {
    return oldDelegate.nodes != nodes ||
        oldDelegate.distances != distances ||
        oldDelegate.layout != layout ||
        oldDelegate.labels != labels ||
        oldDelegate.colorScheme != colorScheme;
  }
}
