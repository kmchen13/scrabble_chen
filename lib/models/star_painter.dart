// lib/widgets/star_painter.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class StarPainter extends CustomPainter {
  final int number;
  final double textSize;
  final Color textColor;
  final Color starColor;
  final Color backgroundColor;

  const StarPainter({
    required this.number,
    required this.textSize,
    this.textColor = const Color(0xFF006400),
    this.starColor = const Color(0xFFFFD700),
    this.backgroundColor = Colors.black,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Fond
    final bgPaint =
        Paint()
          ..color = backgroundColor
          ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Bordure circulaire (optionnelle)
    final borderPaint =
        Paint()
          ..color = starColor.withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
    canvas.drawCircle(center, radius, borderPaint);

    // 3. Étoile
    final starPaint =
        Paint()
          ..color = starColor
          ..style = PaintingStyle.fill;

    final path = Path();
    final outerRadius = radius * 0.7;
    final innerRadius = radius * 0.3;
    final points = 5;
    final startAngle = -math.pi / 2;

    for (int i = 0; i < points * 2; i++) {
      final angle = startAngle + (i * math.pi) / points;
      final r = i.isEven ? outerRadius : innerRadius;
      final x = center.dx + r * math.cos(angle);
      final y = center.dy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, starPaint);

    // 4. Nombre au centre
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$number',
        style: TextStyle(
          fontSize: textSize,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final textOffset = Offset(
      (size.width - textPainter.width) / 2,
      (size.height - textPainter.height) / 2,
    );

    canvas.save();
    canvas.translate(textOffset.dx, textOffset.dy);
    textPainter.paint(canvas, Offset.zero);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant StarPainter oldDelegate) {
    return oldDelegate.number != number ||
        oldDelegate.textSize != textSize ||
        oldDelegate.textColor != textColor ||
        oldDelegate.starColor != starColor ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

/// Widget réutilisable pour le bouton étoile de bonus
class StarBonusButton extends StatelessWidget {
  final int starBonus;
  final VoidCallback? onTap;
  final double size;
  final bool enabled;

  const StarBonusButton({
    super.key,
    required this.starBonus,
    this.onTap,
    this.size = 48,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (starBonus <= 0) return const SizedBox.shrink();

    return Tooltip(
      message:
          enabled
              ? 'Changer les lettres ($starBonus disponible${starBonus > 1 ? 's' : ''})'
              : 'Attendez votre tour pour changer les lettres',
      preferBelow: false,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: StarPainter(
                number: starBonus,
                textSize: size * 0.4,
                textColor:
                    enabled ? const Color(0xFF006400) : Colors.grey.shade600,
                starColor:
                    enabled ? const Color(0xFFFFD700) : Colors.grey.shade500,
                backgroundColor: enabled ? Colors.black : Colors.grey.shade900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
