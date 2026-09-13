import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/board_constants.dart';

/// Draws the entire Ludo board onto a canvas, cell by cell, using a
/// logical 15x15 grid (see [BoardConstants.gridSize]).
///
/// This version renders every surface with a light-lit gradient (top
/// -left highlight, bottom-right shadow) so that — combined with the
/// slight perspective tilt applied by [LudoBoard] — the whole board
/// reads as a raised, glossy game piece rather than a flat drawing.
class BoardPainter extends CustomPainter {
  final double cellSize;
  final double glowT;

  BoardPainter({required this.cellSize, this.glowT = 0});

  @override
  void paint(Canvas canvas, Size size) {
    _drawBaseShadow(canvas, size);
    _drawYards(canvas);
    _drawPathCells(canvas);
    _drawHomeLanes(canvas);
    _drawStartCells(canvas);
    _drawStarCells(canvas);
    _drawCenterTriangle(canvas);
    _drawGridLines(canvas);
    _drawArrows(canvas);
  }

  void _drawBaseShadow(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(cellSize * 0.5),
    );
    canvas.drawRRect(rrect, Paint()..color = AppColors.boardBackground);
  }

  // ---------------------------------------------------------------------
  // Yards
  // ---------------------------------------------------------------------
  void _drawYards(Canvas canvas) {
    BoardConstants.yardBounds.forEach((colorKey, bounds) {
      final color = AppColors.fromKey(colorKey);
      final dark = AppColors.darkFromKey(colorKey);
      final light = AppColors.lightFromKey(colorKey);
      final rect = _rectFromBounds(bounds);
      final radius = Radius.circular(cellSize * 0.7);

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.shift(Offset(0, cellSize * 0.08)), radius),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cellSize * 0.2),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, radius),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [light, color, dark],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(rect),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(cellSize * 0.04), radius),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cellSize * 0.05
          ..color = Colors.white.withValues(alpha: 0.35),
      );

      final inset = cellSize * 0.78;
      final innerRect = Rect.fromLTRB(
        rect.left + inset,
        rect.top + inset,
        rect.right - inset,
        rect.bottom - inset,
      );
      final innerRRect =
          RRect.fromRectAndRadius(innerRect, Radius.circular(cellSize * 0.55));

      canvas.drawRRect(
        innerRRect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: const [Color(0xFFF2EEE1), Colors.white],
          ).createShader(innerRect),
      );
      canvas.drawRRect(
        innerRRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = cellSize * 0.06
          ..color = Colors.black.withValues(alpha: 0.12),
      );

      for (final frac in BoardConstants.yardTokenSlots) {
        final c = Offset(
          innerRect.left + frac[0] * innerRect.width,
          innerRect.top + frac[1] * innerRect.height,
        );
        canvas.drawCircle(
          c,
          cellSize * 0.62,
          Paint()
            ..color = color.withValues(alpha: 0.14)
            ..style = PaintingStyle.stroke
            ..strokeWidth = cellSize * 0.09,
        );
      }
    });
  }

  // ---------------------------------------------------------------------
  // Cross-shaped path (background cells)
  // ---------------------------------------------------------------------
  void _drawPathCells(Canvas canvas) {
    for (int row = 0; row < BoardConstants.gridSize; row++) {
      for (int col = 0; col < BoardConstants.gridSize; col++) {
        if (_isCrossCell(row, col)) {
          final rect = _cellRect(row, col);
          canvas.drawRect(
            rect,
            Paint()
              ..shader = const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFFFFF), Color(0xFFF3EEDF)],
              ).createShader(rect),
          );
        }
      }
    }
  }

  bool _isCrossCell(int row, int col) {
    final inMiddleCols = col >= 6 && col <= 8;
    final inMiddleRows = row >= 6 && row <= 8;
    return inMiddleCols || inMiddleRows;
  }

  // ---------------------------------------------------------------------
  // Colored home lanes
  // ---------------------------------------------------------------------
  void _drawHomeLanes(Canvas canvas) {
    BoardConstants.homeLaneCells.forEach((colorKey, cells) {
      final color = AppColors.fromKey(colorKey);
      final light = AppColors.lightFromKey(colorKey);
      for (final cell in cells) {
        final rect = _cellRect(cell[0], cell[1]);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [light.withValues(alpha: 0.9), color],
            ).createShader(rect),
        );
      }
    });
  }

  // ---------------------------------------------------------------------
  // Colored + safe starting cells
  // ---------------------------------------------------------------------
  void _drawStartCells(Canvas canvas) {
    BoardConstants.startCells.forEach((colorKey, cell) {
      final color = AppColors.fromKey(colorKey);
      final rect = _cellRect(cell[0], cell[1]);
      canvas.drawRect(rect, Paint()..color = color.withValues(alpha: 0.22));
      _drawStar(canvas, rect.center, cellSize * 0.34, color, glossy: true);
    });
  }

  void _drawStarCells(Canvas canvas) {
    for (final cell in BoardConstants.starCells) {
      final rect = _cellRect(cell[0], cell[1]);
      _drawStar(canvas, rect.center, cellSize * 0.34, AppColors.gold, glossy: true);
    }
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color,
      {bool glossy = false}) {
    const int points = 5;
    final path = Path();
    final double innerRadius = radius * 0.45;

    for (int i = 0; i < points * 2; i++) {
      final double r = i.isEven ? radius : innerRadius;
      final double angle = (i * math.pi / points) - math.pi / 2;
      final double x = center.dx + r * math.cos(angle);
      final double y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    canvas.drawPath(
      path.shift(const Offset(0.6, 0.9)),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    if (glossy) {
      canvas.drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(-0.4, -0.5),
            colors: [Color.lerp(color, Colors.white, 0.6)!, color],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    } else {
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.85));
    }
  }

  // ---------------------------------------------------------------------
  // Center triangle ("home")
  // ---------------------------------------------------------------------
  void _drawCenterTriangle(Canvas canvas) {
    final Rect centerRect = _rectFromBounds([6, 8, 6, 8]);
    final Offset topLeft = centerRect.topLeft;
    final Offset topRight = centerRect.topRight;
    final Offset bottomLeft = centerRect.bottomLeft;
    final Offset bottomRight = centerRect.bottomRight;
    final Offset middle = centerRect.center;

    _fillTriangle(canvas, [topLeft, bottomLeft, middle], AppColors.red, AppColors.redDark);
    _fillTriangle(canvas, [topLeft, topRight, middle], AppColors.green, AppColors.greenDark);
    _fillTriangle(canvas, [topRight, bottomRight, middle], AppColors.blue, AppColors.blueDark);
    _fillTriangle(canvas, [bottomLeft, bottomRight, middle], AppColors.yellow, AppColors.yellowDark);

    final glowRadius = centerRect.width * (0.22 + 0.06 * glowT);
    canvas.drawCircle(
      middle,
      glowRadius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0.55 * (0.5 + 0.5 * glowT)),
            AppColors.gold.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: middle, radius: glowRadius)),
    );
    canvas.drawCircle(
      middle,
      centerRect.width * 0.09,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.4, -0.5),
          colors: [Colors.white, AppColors.gold],
        ).createShader(Rect.fromCircle(center: middle, radius: centerRect.width * 0.09)),
    );
  }

  void _fillTriangle(Canvas canvas, List<Offset> points, Color color, Color dark) {
    final path = Path()
      ..moveTo(points[0].dx, points[0].dy)
      ..lineTo(points[1].dx, points[1].dy)
      ..lineTo(points[2].dx, points[2].dy)
      ..close();
    final bounds = path.getBounds();
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(color, Colors.white, 0.35)!, color, dark],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bounds),
    );
  }

  // ---------------------------------------------------------------------
  // Directional arrows at each color's entrance cell
  // ---------------------------------------------------------------------
  void _drawArrows(Canvas canvas) {
    final arrows = <List<dynamic>>[
      [BoardConstants.startCells['red']!, 1.0, 0.0, AppColors.red],
      [BoardConstants.startCells['green']!, 0.0, 1.0, AppColors.green],
      [BoardConstants.startCells['blue']!, -1.0, 0.0, AppColors.blue],
      [BoardConstants.startCells['yellow']!, 0.0, -1.0, AppColors.yellow],
    ];
    for (final a in arrows) {
      final cell = a[0] as List<int>;
      final dx = a[1] as double;
      final dy = a[2] as double;
      final color = a[3] as Color;
      final rect = _cellRect(cell[0], cell[1]);
      final center = rect.center;
      final len = cellSize * 0.26;
      final tip = center + Offset(dx * len, dy * len);
      final baseA = center + Offset(-dy * len * 0.55, dx * len * 0.55) - Offset(dx * len * 0.3, dy * len * 0.3);
      final baseB = center + Offset(dy * len * 0.55, -dx * len * 0.55) - Offset(dx * len * 0.3, dy * len * 0.3);
      final path = Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(baseA.dx, baseA.dy)
        ..lineTo(baseB.dx, baseB.dy)
        ..close();
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: 0.55));
    }
  }

  // ---------------------------------------------------------------------
  // Grid lines
  // ---------------------------------------------------------------------
  void _drawGridLines(Canvas canvas) {
    final paint = Paint()
      ..color = AppColors.cellBorder.withValues(alpha: 0.7)
      ..strokeWidth = 0.7
      ..style = PaintingStyle.stroke;

    for (int row = 0; row < BoardConstants.gridSize; row++) {
      for (int col = 0; col < BoardConstants.gridSize; col++) {
        if (_isCrossCell(row, col)) {
          canvas.drawRect(_cellRect(row, col), paint);
        }
      }
    }

    final outerRect = Rect.fromLTWH(
      0,
      0,
      BoardConstants.gridSize * cellSize,
      BoardConstants.gridSize * cellSize,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(outerRect, Radius.circular(cellSize * 0.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = cellSize * 0.09
        ..color = AppColors.boardOuterBorder,
    );
  }

  // ---------------------------------------------------------------------
  // Geometry helpers
  // ---------------------------------------------------------------------
  Rect _cellRect(int row, int col) {
    return Rect.fromLTWH(col * cellSize, row * cellSize, cellSize, cellSize);
  }

  Rect _rectFromBounds(List<int> bounds) {
    final rowStart = bounds[0];
    final rowEnd = bounds[1];
    final colStart = bounds[2];
    final colEnd = bounds[3];
    return Rect.fromLTWH(
      colStart * cellSize,
      rowStart * cellSize,
      (colEnd - colStart + 1) * cellSize,
      (rowEnd - rowStart + 1) * cellSize,
    );
  }

  @override
  bool shouldRepaint(covariant BoardPainter oldDelegate) {
    return oldDelegate.cellSize != cellSize || oldDelegate.glowT != glowT;
  }
}
