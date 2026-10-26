// ============================================================
// dikelola_induk_banner.dart
// Kotak keterangan di HP Anggota, menggantikan tombol tambah/ubah/hapus
// pada data yang dikelola HP Induk (akun, posko, master barang).
// ============================================================

import 'package:flutter/material.dart';

import '../services/perangkat_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class DikelolaIndukBanner extends StatelessWidget {
  final String? pesan;

  const DikelolaIndukBanner({super.key, this.pesan});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accentBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accentBlue.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.phonelink_lock_outlined, color: AppColors.accentBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pesan ?? PerangkatService.pesanDikelolaInduk,
              style: AppTextStyles.small(p).copyWith(color: p.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
