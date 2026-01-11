import 'package:flutter/material.dart';

class LightControl extends StatelessWidget {
  final double brightness;
  final Color color;
  final bool isLightOn;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onToggleLight;

  const LightControl({
    super.key,
    required this.brightness,
    required this.color,
    required this.isLightOn,
    required this.onBrightnessChanged,
    required this.onColorChanged,
    required this.onToggleLight,
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
                const Text('Освещение'),
                Switch(
                  value: isLightOn,
                  onChanged: (_) => onToggleLight(),
                  activeColor: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Слайдер яркости (активен только когда свет включён)
            Opacity(
              opacity: isLightOn ? 1.0 : 0.5,
              child: Slider(
                value: brightness,
                min: 0,
                max: 1,
                onChanged: isLightOn ? onBrightnessChanged : null,
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
            )
          ],
        ),
      ),
    );
  }

  Widget _colorButton(Color c) {
    return GestureDetector(
      onTap: isLightOn ? () => onColorChanged(c) : null,
      child: CircleAvatar(
        backgroundColor: c,
        child: color == c ? const Icon(Icons.check) : null,
      ),
    );
  }
}
