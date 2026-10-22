// ============================================================
// theme_controller.dart
// Mengatur pergantian mode gelap / terang (tombol matahari).
// ============================================================

import 'package:flutter/material.dart';

class ThemeController {
  ThemeController._();
  static final ThemeController instance = ThemeController._();

  /// Default: mode gelap (sesuai desain).
  final ValueNotifier<ThemeMode> mode = ValueNotifier(ThemeMode.dark);

  bool get isDark => mode.value == ThemeMode.dark;

  void toggle() {
    mode.value = isDark ? ThemeMode.light : ThemeMode.dark;
  }
}
