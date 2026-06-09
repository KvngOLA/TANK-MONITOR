// import 'package:flutter/material.dart';

// class TankPainter extends CustomPainter {
//   final double level; // 0.0 - 1.0
//   final double wavePhase; // animation phase

//   TankPainter({required this.level, required this.wavePhase});
//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..color = Colors.grey.shade300
//       ..style = PaintingStyle.stroke
//       ..strokeWidth = 4.0;

//     // Draw tank outline (rectangle)
//     final rect = Rect.fromLTWH(0, 0, size.width, size.height);
//     canvas.drawRect(rect, paint);

//     // Fill level
//     final fillPaint = Paint()
//       ..color = Colors.blueAccent
//       ..style = PaintingStyle.fill;
//     final fillHeight = size.height * (1 - level);
//     final fillRect = Rect.fromLTWH(0, fillHeight, size.width, size.height - fillHeight);
//     canvas.drawRect(fillRect, fillPaint);
//   }

//   @override
//   bool shouldRepaint(covariant TankPainter oldDelegate) => oldDelegate.level != level;
// }

import 'dart:math' as math;
import 'package:flutter/material.dart';

class TankPainter extends CustomPainter {
  final double level; // Value between 0.0 and 1.0
  final double wavePhase;

  TankPainter({required this.level, required this.wavePhase});

  @override
  void paint(Canvas canvas, Size size) {
    final paintFill = Paint()..style = PaintingStyle.fill;
    final paintOutline = Paint()
      ..color = Colors.grey[400]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    // Draw background tank container casing
    final tankRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(16),
    );
    canvas.drawRRect(tankRect, paintOutline);

    // If level is 0, don't draw liquid contents
    if (level <= 0) return;

    // Calculate fluid top boundary line height
    final waterHeight = size.height * level;
    final topY = size.height - waterHeight;

    // Dynamic wave path construction
    final path = Path();
    path.moveTo(0, topY);

    for (double x = 0; x <= size.width; x++) {
      final y = topY + 6 * math.sin((x / size.width * 2 * math.pi) + wavePhase);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    // Fluid coloring gradient (Teal theme matching active pump setup)
    paintFill.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.teal[300]!, Colors.teal[800]!],
    ).createShader(Rect.fromLTWH(0, topY, size.width, waterHeight));

    // Clip fluid rendering inside the inner bounds of the tank design layout
    canvas.save();
    canvas.clipRRect(tankRect);
    canvas.drawPath(path, paintFill);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TankPainter oldDelegate) {
    return oldDelegate.level != level || oldDelegate.wavePhase != wavePhase;
  }
}