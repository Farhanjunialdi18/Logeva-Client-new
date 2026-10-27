// ============================================================
// pengungsi_detail_sheet.dart
// Panel bawah berisi detail satu pengungsi + tombol KELUAR DARI POSKO /
// KEMBALI KE POSKO, EDIT & HAPUS.
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
import 'catat_keluar_screen.dart';
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
        'Keberadaan': data.masihDiPosko
            ? data.labelKeberadaan
            : [
                data.labelKeberadaan,
                if (data.keluarPada != null) 'sejak ${Tanggal.tampil(data.keluarPada!)}',
                if (data.keteranganKeluar.isNotEmpty) '(${data.keteranganKeluar})',
              ].join(' '),
        'Dicatat': [
          DateFormatter.full(data.dibuatPada),
          if (data.dicatatOleh.isNotEmpty) 'oleh ${data.dicatatOleh}',
        ].join(' '),
      },
      teksAksiLain: data.masihDiPosko ? 'KELUAR DARI POSKO' : 'KEMBALI KE POSKO',
      ikonAksiLain:
          data.masihDiPosko ? Icons.directions_walk_rounded : Icons.home_rounded,
    );
    if (!context.mounted || aksi == null) return;

    if (aksi == DetailAction.lainnya) {
      if (data.masihDiPosko) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CatatKeluarScreen(pengungsi: data)));
      } else {
        await PengungsiRepository.instance.update(data.kembaliKePosko());
        if (context.mounted) {
          AppSnackbar.show(context, '${data.nama} kembali tercatat di posko.');
        }
      }
      return;
    }

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
