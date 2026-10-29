import 'package:flutter/material.dart';

import '../../app/theme.dart';

/// App bar brand: app icon + MoneyBee wordmark.
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

/// MoneyBee mark — same asset as the launcher icon.
class BeeMark extends StatelessWidget {
  final double size;

  const BeeMark({super.key, this.size = 32});

  static const String assetPath = 'assets/icon/app_icon.png';

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => Container(
          width: size,
          height: size,
          color: BeeColors.honey,
          alignment: Alignment.center,
          child: Icon(Icons.hive_outlined, size: size * 0.55, color: BeeColors.charcoal),
        ),
      ),
    );
  }
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