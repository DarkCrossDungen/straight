import 'dart:math' as math;

import 'package:flutter/material.dart';

class BackgroundShapes extends StatefulWidget {
  final Color color;
  final Color blockColor;
  final double cellSize;
  final double strokeWidth;
  final double opacity;

  const BackgroundShapes({
    super.key,
    required this.color,
    required this.blockColor,
    this.cellSize = 22,
    this.strokeWidth = 2,
    this.opacity = 1,
  });

  @override
  State<BackgroundShapes> createState() => _BackgroundShapesState();
}

class _BackgroundShapesState extends State<BackgroundShapes>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 9),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: _BackgroundShapesPainter(
              color: widget.color.withValues(alpha: widget.opacity),
              blockColor: widget.blockColor.withValues(alpha: widget.opacity),
              cellSize: widget.cellSize,
              strokeWidth: widget.strokeWidth,
              tick: _controller.value,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _BackgroundShapesPainter extends CustomPainter {
  final Color color;
  final Color blockColor;
  final double cellSize;
  final double strokeWidth;
  final double tick;

  const _BackgroundShapesPainter({
    required this.color,
    required this.blockColor,
    required this.cellSize,
    required this.strokeWidth,
    required this.tick,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;
    final fillPaint = Paint()
      ..color = blockColor
      ..style = PaintingStyle.fill;
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final startX = size.width * 0.18;
    final endX = size.width * 0.82;
    final startY = size.height * 0.12;
    final endY = size.height * 0.88;

    for (double y = startY; y < endY; y += cellSize) {
      for (double x = startX; x < endX; x += cellSize) {
        final shape = _shapeFor(x, y);
        final phase = ((_hash(x, y) % 100) / 100 + tick) % 1;
        final shouldShift = phase > 0.82;
        _drawShape(
          canvas,
          Rect.fromLTWH(x, y, cellSize, cellSize),
          shouldShift ? (shape + 1) % 7 : shape,
          paint,
          fillPaint,
          dotPaint,
        );
      }
    }
  }

  int _shapeFor(double x, double y) {
    final weighted = [0, 1, 2, 3, 4, 5, 5, 5, 5, 5, 6, 6, 6];
    return weighted[_hash(x, y) % weighted.length];
  }

  int _hash(double x, double y) {
    final ix = (x / cellSize).floor();
    final iy = (y / cellSize).floor();
    return (ix * 73856093 ^ iy * 19349663).abs();
  }

  void _drawShape(
    Canvas canvas,
    Rect cell,
    int shape,
    Paint paint,
    Paint fillPaint,
    Paint dotPaint,
  ) {
    final inset = cellSize * 0.28;
    final rect = cell.deflate(inset);
    switch (shape) {
      case 0:
        canvas.drawCircle(
          cell.center,
          math.max(1.4, cellSize * 0.07),
          dotPaint,
        );
        break;
      case 1:
        for (var i = 0; i < 3; i++) {
          final y = rect.top + i * rect.height / 2;
          canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), paint);
        }
        break;
      case 2:
        canvas.drawLine(rect.topLeft, rect.bottomRight, paint);
        canvas.drawLine(rect.bottomLeft, rect.topRight, paint);
        break;
      case 3:
        canvas.drawRect(rect, paint);
        break;
      case 4:
        canvas.drawLine(rect.bottomLeft, rect.topRight, paint);
        break;
      case 6:
        canvas.drawRect(cell.deflate(cellSize * 0.18), fillPaint);
        break;
      case 5:
      default:
        break;
    }
  }

  @override
  bool shouldRepaint(_BackgroundShapesPainter oldDelegate) {
    return oldDelegate.tick != tick ||
        oldDelegate.color != color ||
        oldDelegate.blockColor != blockColor ||
        oldDelegate.cellSize != cellSize ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
