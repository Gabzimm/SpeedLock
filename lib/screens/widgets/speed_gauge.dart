import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Reproduz o gauge SVG do mockup: um arco de 0 a [maxScale] km/h
/// (25 = velocidade máxima do modo Sport) com um marcador a indicar o
/// limite atual. Os ângulos vêm diretamente da matemática do SVG
/// original (raio 92, `rotate(288 ...)` para o marcador do limite = 20
/// de 25 = 288°, etc.) — não são valores inventados.
class SpeedGauge extends StatelessWidget {
  const SpeedGauge({
    super.key,
    required this.speedKmh,
    required this.speedLimit,
    required this.stateLabel,
    this.maxScale = 25,
  });

  final double speedKmh;
  final int speedLimit;
  final String stateLabel;
  final double maxScale;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 210,
      height: 210,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(210, 210),
            painter: _GaugePainter(
              fraction: (speedKmh / maxScale).clamp(0, 1),
              markerFraction: (speedLimit / maxScale).clamp(0, 1),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                speedKmh.round().toString(),
                style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontWeight: FontWeight.w700,
                  fontSize: 44,
                  color: SpeedLockColors.text1,
                  height: 1,
                ),
              ),
              const Text('km/h', style: TextStyle(color: SpeedLockColors.text2, fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(stateLabel, style: const TextStyle(color: SpeedLockColors.text2, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.fraction, required this.markerFraction});

  final double fraction;
  final double markerFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 92.0;
    const strokeWidth = 14.0;

    final track = Paint()
      ..color = SpeedLockColors.surface2
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);

    final fill = Paint()
      ..color = SpeedLockColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    // Começa no topo (-90°), tal como o `rotate(-90 105 105)` do SVG.
    const startAngle = -math.pi / 2;
    final sweep = 2 * math.pi * fraction;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, false, fill);

    // Marcador do limite: linha radial na posição `markerFraction` do
    // círculo, mesma referência de ângulo do arco acima.
    final markerAngle = startAngle + 2 * math.pi * markerFraction;
    final markerPaint = Paint()
      ..color = SpeedLockColors.text1
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final inner = Offset(
      center.dx + (radius - 8) * math.cos(markerAngle),
      center.dy + (radius - 8) * math.sin(markerAngle),
    );
    final outer = Offset(
      center.dx + (radius + 8) * math.cos(markerAngle),
      center.dy + (radius + 8) * math.sin(markerAngle),
    );
    canvas.drawLine(inner, outer, markerPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.fraction != fraction || oldDelegate.markerFraction != markerFraction;
  }
}
