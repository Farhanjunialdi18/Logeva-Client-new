// ============================================================
// transfer_result_dialog.dart
// Popup hasil IMPORT / EXPORT CSV: "Import Berhasil" / "Import Gagal",
// keterangan, catatan riwayat, dan tombol SELESAI.
// ============================================================

import 'package:flutter/material.dart';

import '../services/transfer_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'primary_button.dart';

class TransferResultDialog {
  TransferResultDialog._();

  /// [aksi]: 'Import' / 'Export'. [jenisData]: misal 'data pengungsi'.
  /// Hasil "dibatalkan" tidak menampilkan popup.
  static Future<void> show(
    BuildContext context, {
    required TransferResult result,
    required String aksi,
    required String jenisData,
  }) async {
    if (result.status == TransferStatus.cancelled) return;

    await showDialog<void>(
      context: context,
      barrierColor: const Color(0xB3000000),
      builder: (_) => _TransferResultView(
        berhasil: !result.isError,
        judul: '$aksi ${result.isError ? 'Gagal' : 'Berhasil'}',
        keterangan: result.isError
            ? result.message
            : '$aksi $jenisData berhasil diproses.\n${result.message}',
      ),
    );
  }
}

class _TransferResultView extends StatelessWidget {
  final bool berhasil;
  final String judul;
  final String keterangan;

  const _TransferResultView({
    required this.berhasil,
    required this.judul,
    required this.keterangan,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: p.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                berhasil ? Icons.check_rounded : Icons.close_rounded,
                size: 64,
                color: berhasil ? AppColors.success : AppColors.error,
              ),
              const SizedBox(height: 12),
              Text(
                judul,
                textAlign: TextAlign.center,
                style: AppTextStyles.pageTitle(p).copyWith(fontSize: 26),
              ),
              const SizedBox(height: 10),
              Text(
                keterangan,
                textAlign: TextAlign.center,
                style: AppTextStyles.body(p),
              ),
              const SizedBox(height: 18),

              // Catatan: setiap import/export (berhasil atau gagal) tercatat.
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: p.surfaceAlt,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: p.border),
                ),
                child: Text(
                  'Riwayat transaksi telah diperbarui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              PrimaryButton(
                text: 'SELESAI',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
