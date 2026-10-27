import 'package:flutter/material.dart';
import '../l10n/generated/app_localizations.dart';

class LightControl extends StatelessWidget {
  final double brightness;
  final Color color;
  final bool isLightOn;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onToggleLight;
  final bool enabled;
  final String? statusText;

  const LightControl({
    super.key,
    required this.brightness,
    required this.color,
    required this.isLightOn,
    required this.onBrightnessChanged,
    required this.onColorChanged,
    required this.onToggleLight,
    this.enabled = true,
    this.statusText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(AppLocalizations.of(context)!.lighting),
                Switch(
                  value: isLightOn,
                  onChanged: enabled ? (_) => onToggleLight() : null,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (statusText != null) Text(statusText!),
            // Слайдер яркости (активен только когда свет включён)
            Opacity(
              opacity: isLightOn ? 1.0 : 0.5,
              child: Slider(
                value: brightness,
                min: 0,
                max: 1,
                onChanged: enabled && isLightOn ? onBrightnessChanged : null,
              ),
            ),
            const SizedBox(height: 8),
            // Кнопки выбора цвета (активны только когда свет включён)
            Opacity(
              opacity: isLightOn ? 1.0 : 0.5,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _colorButton(Colors.white),
                  _colorButton(Colors.red),
                  _colorButton(Colors.green),
                  _colorButton(Colors.blue),
                  _colorButton(Colors.yellow),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorButton(Color c) {
    return GestureDetector(
      onTap: enabled && isLightOn ? () => onColorChanged(c) : null,
      child: CircleAvatar(
        backgroundColor: c,
        child: color == c ? const Icon(Icons.check) : null,
      ),
    );
  }
}
