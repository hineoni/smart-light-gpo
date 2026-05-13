import 'dart:async';
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
  List<DeviceDistanceModel> _distances = [];
  List<DeviceModel> _devices = [];
  bool _isLoading = true;
  DateTime? _lastUpdated;

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

    final results = await Future.wait([
      DeviceService.getDevices(),
      DeviceService.getDistances(),
    ]);

    if (!mounted) return;

    setState(() {
      _devices = results[0] as List<DeviceModel>;
      _distances = results[1] as List<DeviceDistanceModel>;
      _lastUpdated = DateTime.now();
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
                  if (_distances.isEmpty)
                    _buildEmptyState()
                  else
                    _buildDistanceList(),
                ],
              ),
      ),
    );
  }

  Widget _buildStatusPanel(BuildContext context) {
    final theme = Theme.of(context);
    final updatedText = _lastUpdated == null
        ? 'нет данных'
        : '${_lastUpdated!.hour.toString().padLeft(2, '0')}:'
              '${_lastUpdated!.minute.toString().padLeft(2, '0')}:'
              '${_lastUpdated!.second.toString().padLeft(2, '0')}';

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
                Text('Онлайн-устройств: ${_devices.length}'),
                const SizedBox(height: 4),
                Text(
                  'Последнее обновление: $updatedText',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.only(top: 120),
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

  Widget _buildDistanceList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Расстояния между платами',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        ..._distances.map((distance) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.straighten),
              title: Text(
                '${_deviceName(distance.fromDeviceId)} -> ${_deviceName(distance.toDeviceId)}',
              ),
              subtitle: Text(
                distance.source == 'mock'
                    ? 'тестовые данные'
                    : 'данные с устройства',
              ),
              trailing: Text(
                '${distance.distanceM.toStringAsFixed(2)} м',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
