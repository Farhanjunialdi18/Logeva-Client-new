// ============================================================
// pengungsi_detail_sheet.dart
// Panel bawah berisi detail satu pengungsi + tombol EDIT & HAPUS.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/repositories/pengungsi_repository.dart';
import '../../../models/pengungsi.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/date_formatter.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/detail_sheet.dart';
import 'pengungsi_form_screen.dart';

class PengungsiDetailSheet {
  PengungsiDetailSheet._();

  static Future<void> show(BuildContext context, Pengungsi data) async {
    final aksi = await DetailSheet.show(
      context,
      title: data.nama,
      rows: {
        'NIK': data.nik.isEmpty ? '-' : data.nik,
        'Jenis kelamin': data.jenisKelaminLabel,
        'Usia': '${data.usia} tahun',
        'Kondisi': data.kondisi,
        'Domisili': data.domisili,
        'Posko': data.posko,
        'Dicatat': DateFormatter.full(data.dibuatPada),
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
      message: 'Data pengungsi "${data.nama}" akan dihapus dari perangkat.',
      confirmText: 'HAPUS',
    );
    if (!yakin || data.id == null) return;

    await PengungsiRepository.instance.delete(data.id!);
    if (context.mounted) AppSnackbar.show(context, 'Data pengungsi dihapus.');
  }
}
