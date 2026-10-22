// ============================================================
// theme_toggle_button.dart
// Tombol matahari / bulan di pojok kanan atas.
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/theme_controller.dart';
import 'square_icon_button.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;

    // Dibungkus ValueListenableBuilder agar ikon ikut berganti
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller.mode,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return SquareIconButton(
          icon: isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded,
          iconColor: isDark ? AppColors.sun : const Color(0xFF475569),
          tooltip: isDark ? 'Mode terang' : 'Mode gelap',
          onPressed: controller.toggle,
        );
      },
    );
  }
}
