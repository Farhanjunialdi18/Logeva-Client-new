// ============================================================
// minta_kata_sandi_dialog.dart
// Dialog kecil meminta KATA SANDI POSKO untuk membuka file terkunci
// (misal cadangan di HP pengganti). Hasil null = dibatalkan.
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MintaKataSandiDialog {
  MintaKataSandiDialog._();

  static const String pesanPosko = 'File ini dikunci. Masukkan kata sandi posko '
      'yang dibuat supervisor di HP Induk.';

  /// [pesan] & [judul] = kata sandi mana yang diminta (bawaan: kata sandi posko).
  static Future<String?> show(BuildContext context,
      {String? pesanSalah, String pesan = pesanPosko, String judul = 'Kata sandi posko'}) {
    final teks = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierColor: const Color(0xB3000000),
      builder: (ctx) {
        final p = AppPalette.of(ctx);
        void kirim() {
          if (teks.text.isNotEmpty) Navigator.of(ctx).pop(teks.text);
        }

        return AlertDialog(
          backgroundColor: p.surface,
          title: Text(judul, style: AppTextStyles.cardTitle(p)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pesan, style: AppTextStyles.small(p)),
              if (pesanSalah != null) ...[
                const SizedBox(height: 8),
                Text(pesanSalah,
                    style: AppTextStyles.small(p).copyWith(color: AppColors.error)),
              ],
              const SizedBox(height: 12),
              TextField(
                controller: teks,
                autofocus: true,
                obscureText: true,
                style: AppTextStyles.input(p),
                onSubmitted: (_) => kirim(),
                decoration: InputDecoration(hintText: judul),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('BATAL'),
            ),
            TextButton(onPressed: kirim, child: const Text('BUKA')),
          ],
        );
      },
    );
  }
}
