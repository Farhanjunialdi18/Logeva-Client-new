// ============================================================
// square_icon_button.dart
// Tombol kotak kecil (tombol tema & tombol lihat password).
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;
  final double size;
  final String? tooltip;

  const SquareIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.size = 44,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = BorderRadius.circular(12);

    final button = Material(
      color: p.surfaceAlt,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onPressed,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: p.border),
          ),
          child: Icon(icon, size: 20, color: iconColor ?? p.textPrimary),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
