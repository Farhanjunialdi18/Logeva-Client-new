// ============================================================
// status_dot.dart
// Titik hijau "Aktif" / titik abu-abu "Nonaktif".
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class StatusDot extends StatelessWidget {
  final bool aktif;
  final double fontSize;

  const StatusDot({super.key, required this.aktif, this.fontSize = 11.5});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = aktif ? AppColors.success : p.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          aktif ? 'Aktif' : 'Nonaktif',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: aktif ? p.textPrimary : p.textSecondary,
          ),
        ),
      ],
    );
  }
}
