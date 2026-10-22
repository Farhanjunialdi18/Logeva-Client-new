// ============================================================
// pin_dots.dart
// Enam bulatan penanda jumlah digit PIN yang sudah diketik.
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class PinDots extends StatelessWidget {
  final int length; // total digit (6)
  final int filled; // digit yang sudah diisi
  final bool hasError;

  const PinDots({
    super.key,
    required this.length,
    required this.filled,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final isFilled = i < filled;
        final borderColor = hasError
            ? AppColors.error
            : (isFilled ? AppColors.primary : p.textSecondary);

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled
                ? (hasError ? AppColors.error : AppColors.primary)
                : Colors.transparent,
            border: Border.all(color: borderColor, width: 1.5),
          ),
        );
      }),
    );
  }
}
