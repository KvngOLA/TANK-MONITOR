import 'package:flutter/material.dart';

class TankPainter extends CustomPainter {
  final double level; // 0.0 - 1.0
  final double wavePhase; // animation phase

  TankPainter({required this.level, required this.wavePhase});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;

    // Draw tank outline (rectangle)
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, paint);

    // Fill level
    final fillPaint = Paint()
      ..color = Colors.blueAccent
      ..style = PaintingStyle.fill;
    final fillHeight = size.height * (1 - level);
    final fillRect = Rect.fromLTWH(0, fillHeight, size.width, size.height - fillHeight);
    canvas.drawRect(fillRect, fillPaint);
  }

  @override
  bool shouldRepaint(covariant TankPainter oldDelegate) => oldDelegate.level != level;
}
