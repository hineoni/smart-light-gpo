import 'package:flutter/material.dart';

class ServoControl extends StatelessWidget {
  final String title;
  final double value;
  final ValueChanged<double> onChanged;

  // Конструктор можно оставить const
  const ServoControl({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Text('$title: ${value.toInt()}°'), // динамический текст, const здесь не нужен
            Slider(
              min: 0,
              max: 180,
              value: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
