import 'dart:math' as math;
import 'package:flutter/material.dart';

class MangaPanelPainter extends CustomPainter {
  final Color borderColor;
  final double borderWidth;
  final bool showScreentone;
  final Color screentoneColor;

  MangaPanelPainter({
    this.borderColor = Colors.black,
    this.borderWidth = 3.0,
    this.showScreentone = false,
    this.screentoneColor = Colors.black26,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter;

    // Draw irregular border (slight jitter for hand-drawn look)
    final path = Path();
    final random = math.Random(42); // Fixed seed for consistency

    double jitter() => (random.nextDouble() - 0.5) * 2.0;

    path.moveTo(jitter(), jitter());
    path.lineTo(size.width + jitter(), jitter());
    path.lineTo(size.width + jitter(), size.height + jitter());
    path.lineTo(jitter(), size.height + jitter());
    path.close();

    canvas.drawPath(path, paint);

    if (showScreentone) {
      _drawScreentone(canvas, size, path);
    }
  }

  void _drawScreentone(Canvas canvas, Size size, Path clipPath) {
    canvas.save();
    canvas.clipPath(clipPath);

    final dotPaint = Paint()..color = screentoneColor;
    const double spacing = 4.0;
    const double radius = 0.8;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        // Offset every other row for a hexagonal grid look
        double xPos = x + ((y / spacing).floor() % 2 == 0 ? 0 : spacing / 2);
        canvas.drawCircle(Offset(xPos, y), radius, dotPaint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MangaPanelPainter oldDelegate) => 
    oldDelegate.borderColor != borderColor || 
    oldDelegate.showScreentone != showScreentone;
}

class MangaPanel extends StatelessWidget {
  final Widget child;
  final bool hasScreentone;
  final double padding;

  const MangaPanel({
    super.key,
    required this.child,
    this.hasScreentone = false,
    this.padding = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: MangaPanelPainter(showScreentone: hasScreentone),
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: child,
      ),
    );
  }
}
