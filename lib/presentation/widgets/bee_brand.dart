import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// App bar brand: honeycomb bee mark + MoneyBee wordmark.
class BeeAppTitle extends StatelessWidget {
  final String subtitle;

  const BeeAppTitle({super.key, this.subtitle = ''});

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.72);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BeeMark(size: 30),
        const SizedBox(width: 10),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MoneyBee',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                letterSpacing: -0.3,
                color: onSurface,
                height: 1.1,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: muted,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Honeycomb + bee glyph (no image asset required).
class BeeMark extends StatelessWidget {
  final double size;

  const BeeMark({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _BeeMarkPainter()),
    );
  }
}

class _BeeMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    final hex = Path();
    final r = w * 0.46;
    for (var i = 0; i < 6; i++) {
      final angle = (i * 60.0 - 30.0) * math.pi / 180.0;
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        hex.moveTo(x, y);
      } else {
        hex.lineTo(x, y);
      }
    }
    hex.close();

    canvas.drawPath(hex, Paint()..color = BeeColors.honey);
    canvas.drawPath(
      hex,
      Paint()
        ..color = BeeColors.amberDeep
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, cy + h * 0.04),
        width: w * 0.34,
        height: h * 0.42,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(body, Paint()..color = BeeColors.charcoal);

    canvas.save();
    canvas.clipRRect(body);
    final stripePaint = Paint()..color = BeeColors.pollen;
    for (var i = 0; i < 3; i++) {
      final y = cy - h * 0.08 + i * h * 0.12;
      canvas.drawRect(
        Rect.fromLTWH(cx - w * 0.2, y, w * 0.4, h * 0.05),
        stripePaint,
      );
    }
    canvas.restore();

    canvas.drawCircle(
      Offset(cx, cy - h * 0.18),
      w * 0.12,
      Paint()..color = BeeColors.charcoal,
    );

    final wingPaint = Paint()..color = Colors.white.withValues(alpha: 0.88);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx - w * 0.22, cy - h * 0.02),
        width: w * 0.22,
        height: h * 0.28,
      ),
      wingPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx + w * 0.22, cy - h * 0.02),
        width: w * 0.22,
        height: h * 0.28,
      ),
      wingPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Section title with honey accent bar.
class BeeSectionTitle extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const BeeSectionTitle({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: BeeColors.honey,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: onSurface,
                ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// Honey gradient panel for primary summary.
class HoneyBanner extends StatelessWidget {
  final Widget child;

  const HoneyBanner({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? const [
                  Color(0xFF5D4A1E),
                  Color(0xFFC48A1A),
                  Color(0xFFF5A623),
                ]
              : const [
                  Color(0xFFFFF3D0),
                  Color(0xFFFFE082),
                  Color(0xFFF5A623),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: BeeColors.honey.withValues(alpha: isDark ? 0.25 : 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}