// ============================================================
// pengingat_setor.dart
// PENGINGAT SETOR DATA (HP relawan / HP Anggota): setiap kali data
// pengungsi atau logistik bertambah/berubah, pesan "tersimpan" ikut
// mengingatkan berapa perubahan yang BELUM disetor ke admin.
// Di HP Induk (admin) hanya pesan biasa.
// ============================================================

import 'package:flutter/material.dart';

import '../services/perangkat_service.dart';
import '../services/sinkron_service.dart';
import 'app_snackbar.dart';

class PengingatSetor {
  PengingatSetor._();

  /// Teks pengingat; null kalau semua sudah disetor.
  static String? teks(int belum) => belum <= 0
      ? null
      : 'Jangan lupa setor ke admin: $belum perubahan belum disetor '
          '(tombol KIRIM DATA KE ADMIN).';

  /// Tampilkan [pesan] + pengingat setor. Panggil SEBELUM Navigator.pop.
  static Future<void> setelahSimpan(BuildContext context, String pesan) async {
    var belum = 0;
    if (PerangkatService.isAnggota) {
      try {
        belum = (await SinkronService.statusKirim()).belumTerkirim;
      } catch (_) {
        // pengingat tidak boleh menggagalkan penyimpanan
      }
    }
    if (!context.mounted) return;
    final ingat = teks(belum);
    AppSnackbar.show(
      context,
      ingat == null ? pesan : '$pesan\n$ingat',
      duration: Duration(seconds: ingat == null ? 4 : 7),
    );
  }
}
