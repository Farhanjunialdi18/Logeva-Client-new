// ============================================================
// pengungsi_detail_sheet.dart
// Panel bawah berisi detail satu pengungsi + tombol EDIT & HAPUS.
// Hapus = ditandai dihapus, supaya penghapusan ikut terkirim ke pusat.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/repositories/pengungsi_repository.dart';
import '../../../models/pengungsi.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/date_formatter.dart';
import '../../../utils/tanggal.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/detail_sheet.dart';
import 'pengungsi_form_screen.dart';

class PengungsiDetailSheet {
  PengungsiDetailSheet._();

  static String _isi(String teks) => teks.trim().isEmpty ? '-' : teks;

  static Future<void> show(BuildContext context, Pengungsi data) async {
    final aksi = await DetailSheet.show(
      context,
      title: data.nama,
      rows: {
        'Tanggal lahir': data.tanggalLahir == null
            ? 'Belum diisi (perlu dilengkapi)'
            : Tanggal.tampil(data.tanggalLahir!),
        'Usia': '${data.usia} tahun',
        'Jenis kelamin': data.jenisKelamin,
        'Asal': _isi(data.asal),
        'Nomor KK': data.nomorKk.isEmpty ? 'Belum diketahui' : data.nomorKk,
        'Kondisi kesehatan': data.kondisiKesehatan,
        'Kelompok rentan': data.kelompokRentan,
        'Riwayat penyakit': _isi(data.riwayatPenyakit),
        'Posko': _isi(data.posko),
        'Dicatat': [
          DateFormatter.full(data.dibuatPada),
          if (data.dicatatOleh.isNotEmpty) 'oleh ${data.dicatatOleh}',
        ].join(' '),
      },
    );
    if (!context.mounted || aksi == null) return;

    if (aksi == DetailAction.edit) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PengungsiFormScreen(existing: data)),
      );
      return;
    }

    // aksi == hapus
    final yakin = await ConfirmDialog.show(
      context,
      title: 'Hapus data ini?',
      message: 'Data pengungsi "${data.nama}" akan dihapus dari daftar. '
          'Penghapusan ini ikut terkirim ke pusat saat Paket Data Posko '
          'diekspor.',
      confirmText: 'HAPUS',
    );
    if (!yakin) return;

    await PengungsiRepository.instance.hapus(data);
    if (context.mounted) AppSnackbar.show(context, 'Data pengungsi dihapus.');
  }
}
