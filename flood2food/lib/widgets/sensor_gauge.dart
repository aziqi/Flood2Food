import 'dart:math' as math;
import 'package:flutter/material.dart';

class SensorGauge extends StatelessWidget {
  final double value;
  final String unit;
  final double minValue;
  final double maxValue;
  final Color? color;

  const SensorGauge({
    super.key,
    required this.value,
    required this.unit,
    this.minValue = 0,
    this.maxValue = 100,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final normalized = ((value - minValue) / (maxValue - minValue)).clamp(0.0, 1.0);
    final gaugeColor = color ?? _getDefaultColor(normalized);

    return SizedBox(
      height: 90,
      width: 90,
      child: CustomPaint(
        painter: _GaugePainter(progress: normalized, color: gaugeColor),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: gaugeColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getDefaultColor(double normalized) {
    if (normalized < 0.3) return Colors.orange;
    if (normalized < 0.7) return Colors.green;
    return Colors.blue;
  }
}

class _GaugePainter extends CustomPainter {
  final double progress;
  final Color color;

  _GaugePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    final bgPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
