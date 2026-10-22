// ============================================================
// confirm_dialog.dart
// Popup konfirmasi dengan 2 tombol (BATAL & tombol merah).
// Dipakai untuk Logout dan Hapus data.
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'secondary_button.dart';

class ConfirmDialog {
  ConfirmDialog._();

  /// Hasil true = tombol merah ditekan, false = batal.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    String cancelText = 'BATAL',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: const Color(0xB3000000), // hitam 70%
      builder: (ctx) => _ConfirmDialogView(
        title: title,
        message: message,
        confirmText: confirmText,
        cancelText: cancelText,
      ),
    );
    return result ?? false;
  }
}

class _ConfirmDialogView extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;

  const _ConfirmDialogView({
    required this.title,
    required this.message,
    required this.confirmText,
    required this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.sectionTitle(p).copyWith(fontSize: 20),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(p),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      text: cancelText,
                      height: 50,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(confirmText, style: AppTextStyles.button),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
