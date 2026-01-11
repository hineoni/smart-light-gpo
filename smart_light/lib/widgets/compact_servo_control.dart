import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class CompactServoControl extends StatelessWidget {
  final String title;
  final double value; // Угол 0-180
  final ValueChanged<double> onChanged;

  const CompactServoControl({
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
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            // Компактный круговой индикатор
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Фоновая дуга
                  CustomPaint(
                    size: const Size(140, 140),
                    painter: _CompactCircularTrackPainter(),
                  ),

                  // Активная дуга
                  CustomPaint(
                    size: const Size(140, 140),
                    painter: _CompactCircularProgressPainter(value / 180),
                  ),

                  // Кликабельная область
                  GestureDetector(
                    onTapUp: (details) =>
                        _updateAngleFromPosition(details.localPosition),
                    onPanUpdate: (details) =>
                        _updateAngleFromPosition(details.localPosition),
                    child: Container(
                      width: 140,
                      height: 140,
                      color: Colors.transparent,
                    ),
                  ),

                  // Центральное значение
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      '${value.round()}°',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Компактный слайдер
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Slider(
                value: value,
                min: 0,
                max: 180,
                divisions: 36,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateAngleFromPosition(Offset position) {
    const center = Offset(70, 70);
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;

    // Проверяем расстояние от центра
    final distance = sqrt(dx * dx + dy * dy);
    if (distance < 35 || distance > 70) return;

    // Вычисляем угол
    double angleRad = atan2(dy, dx);
    if (angleRad < 0) angleRad += 2 * pi;

    // Диапазон от π до 2π (нижняя половина)
    if (angleRad >= pi && angleRad <= 2 * pi) {
      double angleDeg = (angleRad - pi) * 180 / pi;
      onChanged(angleDeg.clamp(0, 180));
    }
  }
}

class _CompactCircularTrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    const radius = 35.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CompactCircularProgressPainter extends CustomPainter {
  final double progress;

  _CompactCircularProgressPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    const radius = 35.0;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      pi,
      pi * progress,
      false,
      paint,
    );

    // Индикатор
    final angle = pi + (pi * progress);
    final indicatorX = center.dx + radius * cos(angle);
    final indicatorY = center.dy + radius * sin(angle);

    final indicatorPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(indicatorX, indicatorY), 4, indicatorPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is _CompactCircularProgressPainter &&
        oldDelegate.progress != progress;
  }
}
