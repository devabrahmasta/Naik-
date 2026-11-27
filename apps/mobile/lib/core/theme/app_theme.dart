import 'package:flutter/material.dart';

/// Token visual HikeNav v0.2 berdasarkan docs/design.md.
/// Mode terang saja, bernuansa camp outdoor dengan kontras tinggi (WCAG AA+).
class AppColors {
  const AppColors._();

  static const Color bg = Color(0xFFF6F4EE);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1F2A1C);
  static const Color ink2 = Color(0xFF5B6555);
  static const Color primary = Color(0xFF5A7834);
  static const Color primaryText = Color(0xFF4E6B2F);
  static const Color tonal = Color(0xFFE4EBD3);
  static const Color accent = Color(0xFFB8570F);
  static const Color accentText = Color(0xFF8A3F08);
  static const Color warnBg = Color(0xFFFCE9D2);
  static const Color danger = Color(0xFFB3261E);
  static const Color route = Color(0xFF3E8E3A);
  static const Color track = Color(0xFF2563C9);
  static const Color divider = Color(0xFFE3E1D6);
}

class AppShadows {
  const AppShadows._();

  /// Bayangan kartu lembut (y 6, blur 20, hitam kehijauan 7%).
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x121F2A1C),
      offset: Offset(0, 6),
      blurRadius: 20,
    ),
  ];

  /// Bayangan elemen melayang (y 10, blur 28, hitam kehijauan 12%).
  static const List<BoxShadow> float = [
    BoxShadow(
      color: Color(0x1F1F2A1C),
      offset: Offset(0, 10),
      blurRadius: 28,
    ),
  ];
}

class AppTypography {
  const AppTypography._();

  static const TextStyle display = TextStyle(
    fontSize: 32,
    height: 38 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.64,
    color: AppColors.ink,
  );

  static const TextStyle title = TextStyle(
    fontSize: 24,
    height: 30 / 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.36,
    color: AppColors.ink,
  );

  static const TextStyle headline = TextStyle(
    fontSize: 17,
    height: 24 / 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.085,
    color: AppColors.ink,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
    color: AppColors.ink,
  );

  static const TextStyle label = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    color: AppColors.ink,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w500,
    color: AppColors.ink2,
  );

  /// Menambahkan angka tabular untuk metrik statistik agar lebar kolom stabil.
  static TextStyle tabular(TextStyle base) {
    return base.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.tonal,
        onSecondary: AppColors.ink,
        surface: AppColors.surface,
        onSurface: AppColors.ink,
        error: AppColors.danger,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppTypography.headline,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 52),
          shape: const StadiumBorder(),
          textStyle: AppTypography.label.copyWith(color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryText,
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          side: BorderSide.none,
          backgroundColor: AppColors.tonal,
          textStyle: AppTypography.label.copyWith(color: AppColors.primaryText),
        ),
      ),
    );
  }
}
