// ============================================================
// logistik_detail_sheet.dart
// Panel bawah berisi detail satu barang logistik + EDIT & HAPUS.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/repositories/logistik_repository.dart';
import '../../../models/logistik.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/date_formatter.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/detail_sheet.dart';
import 'logistik_form_screen.dart';

class LogistikDetailSheet {
  LogistikDetailSheet._();

  static Future<void> show(BuildContext context, Logistik data) async {
    final aksi = await DetailSheet.show(
      context,
      title: data.namaBarang,
      rows: {
        'Kategori': data.kategori,
        'Jumlah': '${data.jumlah} ${data.satuan}',
        'Posko': data.posko,
        'Dicatat': DateFormatter.full(data.dibuatPada),
      },
    );
    if (!context.mounted || aksi == null) return;

    if (aksi == DetailAction.edit) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LogistikFormScreen(existing: data)),
      );
      return;
    }

    // aksi == hapus
    final yakin = await ConfirmDialog.show(
      context,
      title: 'Hapus data ini?',
      message: 'Data logistik "${data.namaBarang}" akan dihapus dari perangkat.',
      confirmText: 'HAPUS',
    );
    if (!yakin || data.id == null) return;

    await LogistikRepository.instance.delete(data.id!);
    if (context.mounted) AppSnackbar.show(context, 'Data logistik dihapus.');
  }
}
