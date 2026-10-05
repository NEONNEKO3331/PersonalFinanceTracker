import 'package:flutter/material.dart';

/// MoneyBee visual identity — honey accents work in both light and dark.
class BeeColors {
  BeeColors._();

  static const honey = Color(0xFFF5A623);
  static const amberDeep = Color(0xFFE8910C);
  static const cream = Color(0xFFFFF8E7);
  static const pollen = Color(0xFFFFE082);
  static const charcoal = Color(0xFF2C2416);
  static const hiveBrown = Color(0xFF5D4037);
  static const surfaceWarm = Color(0xFFFFFBF3);
  static const nectarGreen = Color(0xFF2E7D32);
  static const stingRed = Color(0xFFC62828);

  /// Dark-mode surfaces
  static const darkSurface = Color(0xFF1C1814);
  static const darkCard = Color(0xFF2A241C);
}

class AppTheme {
  static const seed = BeeColors.honey;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: BeeColors.honey,
      onPrimary: BeeColors.charcoal,
      secondary: BeeColors.hiveBrown,
      onSecondary: Colors.white,
      surface: BeeColors.surfaceWarm,
      onSurface: BeeColors.charcoal,
      error: BeeColors.stingRed,
    );

    return _base(scheme, scaffoldBg: BeeColors.cream);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      primary: BeeColors.honey,
      onPrimary: BeeColors.charcoal,
      secondary: BeeColors.pollen,
      onSecondary: BeeColors.charcoal,
      surface: BeeColors.darkCard,
      onSurface: const Color(0xFFF5F0E8),
      error: const Color(0xFFEF9A9A),
    );

    return _base(scheme, scaffoldBg: BeeColors.darkSurface);
  }

  static ThemeData _base(ColorScheme scheme, {required Color scaffoldBg}) {
    final isDark = scheme.brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: scaffoldBg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? BeeColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: BeeColors.honey.withValues(alpha: isDark ? 0.28 : 0.22),
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: BeeColors.honey,
        foregroundColor: BeeColors.charcoal,
        elevation: 3,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return BeeColors.honey.withValues(alpha: isDark ? 0.45 : 0.35);
            }
            return isDark ? BeeColors.darkCard : Colors.white;
          }),
          foregroundColor: WidgetStateProperty.all(scheme.onSurface),
          side: WidgetStateProperty.all(
            BorderSide(color: BeeColors.honey.withValues(alpha: 0.45)),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        selectedColor: BeeColors.honey.withValues(alpha: 0.4),
        backgroundColor: isDark ? BeeColors.darkCard : Colors.white,
        side: BorderSide(color: BeeColors.honey.withValues(alpha: 0.35)),
        labelStyle: TextStyle(color: scheme.onSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? BeeColors.darkCard : Colors.white,
        labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75)),
        hintStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.45)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: BeeColors.honey.withValues(alpha: 0.35)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: BeeColors.honey.withValues(alpha: 0.35)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: BeeColors.honey, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: BeeColors.honey,
          foregroundColor: BeeColors.charcoal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface.withValues(alpha: 0.85),
        textColor: scheme.onSurface,
        subtitleTextStyle: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.7),
          fontSize: 13,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? const Color(0xFF3E3428) : BeeColors.charcoal,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: DividerThemeData(
        color: BeeColors.honey.withValues(alpha: isDark ? 0.2 : 0.25),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? BeeColors.darkCard : Colors.white,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: scheme.onSurface.withValues(alpha: 0.85),
        ),
      ),
    );
  }
}