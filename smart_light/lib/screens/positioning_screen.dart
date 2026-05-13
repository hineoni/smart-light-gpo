import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/device_distance_model.dart';
import '../models/device_model.dart';
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
    lastUpdated: null,
    ttlMs: 5000,
  );
  List<DeviceModel> _devices = [];
  bool _isLoading = true;
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
    final devices = await devicesFuture;
    final summary = await summaryFuture;

    if (!mounted) return;

    setState(() {
      _devices = devices;
      _summary = summary;
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
                  if (_summary.distances.isEmpty)
                    _buildEmptyState()
                  else
                    _buildDistanceList(context),
                ],
              ),
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
                    labels: {
                      for (final node in nodes.take(3))
                        node.deviceId: _deviceName(node.deviceId),
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

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 80),
      child: Column(
        children: [
          Icon(Icons.social_distance, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('Расстояния пока не получены', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          Text(
            'Данные появятся после heartbeat от UWB-модулей',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
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

          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.straighten),
              title: Text(
                '${_deviceName(distance.fromDeviceId)} → ${_deviceName(distance.toDeviceId)}',
              ),
              subtitle: Text(
                '${distance.source == 'mock' ? 'тестовые данные' : 'данные с устройства'} · $rssi · ${_ageLabel(distance)}',
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
  final Map<String, String> labels;
  final ColorScheme colorScheme;
  final TextStyle textStyle;

  const _PositioningPainter({
    required this.nodes,
    required this.distances,
    required this.labels,
    required this.colorScheme,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final positions = _positionsFor(size);
    final linePaint = Paint()
      ..color = colorScheme.outline
      ..strokeWidth = 2;

    for (final distance in distances) {
      final from = positions[distance.fromDeviceId];
      final to = positions[distance.toDeviceId];
      if (from == null || to == null) continue;

      canvas.drawLine(from, to, linePaint);
      _drawText(
        canvas,
        '${distance.distanceM.toStringAsFixed(2)} м',
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
        oldDelegate.labels != labels ||
        oldDelegate.colorScheme != colorScheme;
  }
}
