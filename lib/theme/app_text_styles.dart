// ============================================================
// app_text_styles.dart
// Semua gaya TEKS (ukuran, ketebalan, warna) ada di sini.
// ============================================================

import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static TextStyle appTitle(AppPalette p) => TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: p.textPrimary,
      );

  static TextStyle subtitle(AppPalette p) => TextStyle(
        fontSize: 12,
        height: 1.6,
        color: p.textSecondary,
      );

  static TextStyle pageTitle(AppPalette p) => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: p.textPrimary,
      );

  static TextStyle sectionTitle(AppPalette p) => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: p.textPrimary,
      );

  static TextStyle body(AppPalette p) => TextStyle(
        fontSize: 13,
        height: 1.4,
        color: p.textSecondary,
      );

  static TextStyle small(AppPalette p) => TextStyle(
        fontSize: 11.5,
        color: p.textSecondary,
      );

  static TextStyle label(AppPalette p) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: p.textPrimary,
      );

  static TextStyle cardTitle(AppPalette p) => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: p.textPrimary,
      );

  static TextStyle input(AppPalette p) => TextStyle(
        fontSize: 14,
        color: p.textPrimary,
      );

  static TextStyle pinKey(AppPalette p) => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w500,
        color: p.textPrimary,
      );

  static const TextStyle button = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    color: Colors.white,
  );

  static const TextStyle badge = TextStyle(
    fontSize: 10.5,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.6,
    color: AppColors.success,
  );
}
