import 'dart:async';
import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';
import '../models/ambient_light_reading.dart';
import '../services/ambient_light_service.dart';

class AmbientLightCard extends StatelessWidget {
  const AmbientLightCard({
    super.key,
    required this.reading,
    this.loading = false,
    this.hasError = false,
    this.onRefresh,
  });

  final AmbientLightReading? reading;
  final bool loading;
  final bool hasError;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    final level = reading?.level;
    final fresh = level != null;
    final label = switch (level) {
      AmbientLightLevel.dark => l10n.ambientDark,
      AmbientLightLevel.comfortable => l10n.ambientComfortable,
      AmbientLightLevel.bright => l10n.ambientBright,
      null => loading ? l10n.ambientLoading : l10n.ambientNoData,
    };
    final accent = switch (level) {
      AmbientLightLevel.dark => colors.secondary,
      AmbientLightLevel.bright => colors.tertiary,
      _ => colors.primary,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wb_sunny_outlined, color: accent),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.ambientLight,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onRefresh != null)
                  IconButton(
                    onPressed: onRefresh,
                    icon: const Icon(Icons.refresh),
                    tooltip: l10n.ambientRefresh,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  fresh ? '${reading!.percent}%' : '—',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Chip(
                  label: Text(label),
                  side: BorderSide.none,
                  backgroundColor: accent.withValues(alpha: 0.12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: fresh ? reading!.percent! / 100 : 0,
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: accent,
              backgroundColor: colors.surfaceContainerHighest,
              semanticsLabel: l10n.ambientLight,
              semanticsValue: fresh
                  ? '${reading!.percent}%'
                  : l10n.ambientNoData,
            ),
            if (!fresh && !loading) ...[
              const SizedBox(height: 8),
              Text(
                hasError ? l10n.ambientConnectionError : l10n.ambientWaiting,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class LiveAmbientLightCard extends StatefulWidget {
  const LiveAmbientLightCard({super.key, required this.deviceId});
  final String deviceId;

  @override
  State<LiveAmbientLightCard> createState() => _LiveAmbientLightCardState();
}

class _LiveAmbientLightCardState extends State<LiveAmbientLightCard> {
  Timer? _timer;
  AmbientLightReading? _reading;
  bool _fetching = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final reading = await AmbientLightService.read(widget.deviceId);
      if (mounted) {
        setState(() {
          _reading = reading;
          _hasError = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _reading = null;
          _hasError = true;
        });
      }
    } finally {
      _fetching = false;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AmbientLightCard(
    reading: _reading,
    loading: _reading == null && !_hasError,
    hasError: _hasError,
    onRefresh: _refresh,
  );
}
