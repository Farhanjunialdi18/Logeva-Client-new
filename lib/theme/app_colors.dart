// ============================================================
// app_colors.dart
// Semua WARNA aplikasi ada di sini (mirip file CSS variabel).
// Kalau mau ganti warna, cukup ubah di file ini saja.
// ============================================================

import 'package:flutter/material.dart';

/// Warna yang sama di mode gelap maupun terang.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFD63A3F); // merah GMLS
  static const Color primaryPressed = Color(0xFFB92F34);
  static const Color primarySoft = Color(0x26D63A3F); // merah 15% (latar ikon)
  static const Color primaryGlow = Color(0x40D63A3F); // merah 25% (efek cahaya)
  static const Color success = Color(0xFF4ADE80); // hijau "MODE OFFLINE"
  static const Color successSoft = Color(0x1F4ADE80);
  static const Color error = Color(0xFFF87171);
  static const Color sun = Color(0xFFFBBF24);

  // Warna ikon menu
  static const Color accentPurple = Color(0xFF8B7CF6); // pengungsi
  static const Color accentAmber = Color(0xFFE8A04C); // logistik
  static const Color accentBlue = Color(0xFF60A5FA); // riwayat
}

/// Warna yang berbeda antara mode gelap dan terang.
class AppPalette {
  final Color backgroundTop;
  final Color backgroundBottom;
  final Color surface; // kartu besar
  final Color surfaceAlt; // tombol / kartu kecil
  final Color inputFill; // kolom isian
  final Color border;
  final Color textPrimary;
  final Color textSecondary;

  const AppPalette({
    required this.backgroundTop,
    required this.backgroundBottom,
    required this.surface,
    required this.surfaceAlt,
    required this.inputFill,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
  });

  static const AppPalette dark = AppPalette(
    backgroundTop: Color(0xFF161C27),
    backgroundBottom: Color(0xFF07090D),
    surface: Color(0xFF1A1F29),
    surfaceAlt: Color(0xFF252C38),
    inputFill: Color(0xFF151A23),
    border: Color(0xFF353D4B),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF9AA3B2),
  );

  static const AppPalette light = AppPalette(
    backgroundTop: Color(0xFFF8F9FB),
    backgroundBottom: Color(0xFFE8EBF0),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F3F6),
    inputFill: Color(0xFFF7F8FA),
    border: Color(0xFFD7DCE3),
    textPrimary: Color(0xFF111827),
    textSecondary: Color(0xFF5B6475),
  );

  /// Ambil palet sesuai tema yang sedang aktif.
  static AppPalette of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}
