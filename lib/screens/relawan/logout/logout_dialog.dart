// ============================================================
// logout_dialog.dart
// Popup "Keluar dari akun?" dengan tombol BATAL & LOGOUT.
// ============================================================

import 'package:flutter/material.dart';

import '../../../routes/app_routes.dart';
import '../../../services/session_service.dart';
import '../../../widgets/confirm_dialog.dart';

class LogoutDialog {
  LogoutDialog._();

  /// Tampilkan popup. Kalau pilih LOGOUT -> kembali ke pilih peran.
  static Future<void> show(BuildContext context) async {
    final yakin = await ConfirmDialog.show(
      context,
      title: 'Keluar dari akun?',
      message: 'Anda akan kembali ke halaman pemilihan role.',
      confirmText: 'LOGOUT',
    );
    if (!yakin || !context.mounted) return;

    SessionService.instance.clear();
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.roleSelection,
      (route) => false,
    );
  }
}
