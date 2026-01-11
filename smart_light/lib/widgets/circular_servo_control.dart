import 'dart:math';
import 'package:flutter/material.dart';

class CircularServoControl extends StatelessWidget {
  final String title;
  final double value; // Угол 0-180
  final ValueChanged<double> onChanged;

  const CircularServoControl({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            
            // Круговой индикатор
            SizedBox(
              width: 150,
              height: 150,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Фоновая дуга (180 градусов)
                  CustomPaint(
                    size: const Size(150, 150),
                    painter: _CircularTrackPainter(),
                  ),
                  
                  // Активная дуга (показывает текущий угол)
                  CustomPaint(
                    size: const Size(150, 150),
                    painter: _CircularProgressPainter(value / 180),
                  ),
                  
                  // Драggable индикатор
                  GestureDetector(
                    onPanUpdate: (details) {
                      _updateAngleFromPosition(details.localPosition);
                    },
                    child: Container(
                      width: 150,
                      height: 150,
                      color: Colors.transparent,
                    ),
                  ),
                  
                  // Центральное значение
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${value.round()}°',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Традиционный слайдер как fallback
            Slider(
              value: value,
              min: 0,
              max: 180,
              divisions: 180,
              label: '${value.round()}°',
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  void _updateAngleFromPosition(Offset position) {
    // Центр виджета
    const center = Offset(75, 75);
    
    // Вектор от центра к позиции касания
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    
    // Проверяем что касание достаточно близко к окружности
    final distance = sqrt(dx * dx + dy * dy);
    if (distance < 40 || distance > 80) return; // Только на дуге
    
    // Угол в радианах (-π до π)
    double angleRad = atan2(dy, dx);
    
    // Преобразуем в диапазон 0-π (нижняя половина окружности) 
    if (angleRad < 0) angleRad += 2 * pi;
    
    // Ограничиваем диапазон π до 0 (180° до 0°)
    if (angleRad >= pi && angleRad <= 2 * pi) {
      double angleDeg = (angleRad - pi) * 180 / pi;
      angleDeg = angleDeg.clamp(0, 180);
      onChanged(angleDeg);
    }
  }
}

class _CircularTrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    const radius = 60.0;

    // Рисуем дугу от 180° до 0° (нижняя половина)
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi, // Начинаем с 180°
      pi, // Рисуем 180° (до 0°)
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CircularProgressPainter extends CustomPainter {
  final double progress; // 0.0 - 1.0

  _CircularProgressPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    const radius = 60.0;

    // Рисуем активную дугу
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi, // Начинаем с 180°
      pi * progress, // Прогресс от 0 до π
      false,
      paint,
    );

    // Рисуем индикатор на конце дуги
    final angle = pi + (pi * progress);
    final indicatorX = center.dx + radius * cos(angle);
    final indicatorY = center.dy + radius * sin(angle);

    final indicatorPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(indicatorX, indicatorY), 6, indicatorPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _CircularProgressPainter && oldDelegate.progress != progress;
  }
}