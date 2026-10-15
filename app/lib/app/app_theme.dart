import 'package:flutter/material.dart';

abstract final class AppColors {
  static const surface = Color(0xFF131315);
  static const surfaceLowest = Color(0xFF0E0E10);
  static const surfaceLow = Color(0xFF1C1B1D);
  static const surfaceContainer = Color(0xFF201F22);
  static const surfaceHigh = Color(0xFF2A2A2C);
  static const surfaceHighest = Color(0xFF353437);
  static const surfaceBright = Color(0xFF39393B);
  static const onSurface = Color(0xFFE5E1E4);
  static const onSurfaceVariant = Color(0xFFC4C7C8);
  static const outline = Color(0xFF8E9192);
  static const onPrimary = Color(0xFF2F3131);
  static const hairline = Color(0x14FFFFFF);
}

abstract final class AppText {
  static const family = 'Geist';

  static TextStyle labelSm(
    Color color, {
    FontWeight weight = FontWeight.w600,
    double letterSpacing = 0.6,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: 10,
      height: 1.2,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle labelMd(
    Color color, {
    FontWeight weight = FontWeight.w500,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: 12,
      height: 1.33,
      fontWeight: weight,
      letterSpacing: 0.24,
      color: color,
    );
  }

  static TextStyle bodySm(Color color) {
    return TextStyle(
      fontFamily: family,
      fontSize: 12,
      height: 1.33,
      fontWeight: FontWeight.w400,
      color: color,
    );
  }

  static TextStyle bodyMd(
    Color color, {
    FontWeight weight = FontWeight.w400,
  }) {
    return TextStyle(
      fontFamily: family,
      fontSize: 14,
      height: 1.43,
      fontWeight: weight,
      letterSpacing: -0.07,
      color: color,
    );
  }

  static TextStyle headlineSm(Color color) {
    return TextStyle(
      fontFamily: family,
      fontSize: 18,
      height: 1.33,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.27,
      color: color,
    );
  }
}

abstract final class AppTheme {
  static ThemeData get dark {
    const scheme = ColorScheme.dark(
      primary: Colors.white,
      onPrimary: AppColors.onPrimary,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      outline: AppColors.outline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: AppText.family,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: scheme,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
