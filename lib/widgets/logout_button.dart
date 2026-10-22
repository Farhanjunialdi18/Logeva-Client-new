// ============================================================
// logout_button.dart
// Tombol lebar "Logout" dengan teks merah (Beranda Admin).
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class LogoutButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const LogoutButton({
    super.key,
    required this.onPressed,
    this.text = 'Logout',
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return SizedBox(
      width: double.infinity,
      height: 64,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.logout_rounded, size: 20),
        label: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: p.surfaceAlt,
          foregroundColor: AppColors.error,
          side: BorderSide(color: p.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}
