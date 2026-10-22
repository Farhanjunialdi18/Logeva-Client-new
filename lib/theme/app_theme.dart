// ============================================================
// app_theme.dart
// Tema global aplikasi (mode gelap & terang).
// ============================================================

import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark, AppPalette.dark);
  static ThemeData get light => _build(Brightness.light, AppPalette.light);

  static ThemeData _build(Brightness brightness, AppPalette p) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: p.backgroundBottom,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
      ),
      // Kalau nanti menambahkan font (misal DM Sans) di pubspec.yaml,
      // aktifkan baris berikut:
      // fontFamily: 'DMSans',
    );
  }
}
