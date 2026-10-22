// ============================================================
// app_snackbar.dart
// Pesan singkat di bawah layar (berhasil / gagal).
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppSnackbar {
  AppSnackbar._();

  static void show(BuildContext context, String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? AppColors.primaryPressed : const Color(0xFF1F7A4D),
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
