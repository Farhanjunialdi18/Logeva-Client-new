// ============================================================
// kirim_ke_admin_button.dart
// Tombol KIRIM DATA KE ADMIN (di HP relawan / HP Anggota): satu tekan ->
// File Sinkron berisi data pengungsi & logistik posko -> menu Bagikan
// (Bluetooth / Quick Share). Di HP admin: ketuk file -> Buka dengan
// LOGEVA -> YA, SINKRONKAN (data digabung tanpa dobel).
// Tidak tampil di HP Induk (admin tidak perlu mengirim ke dirinya sendiri).
// ============================================================

import 'package:flutter/material.dart';

import '../data/data_events.dart';
import '../data/repositories/pengaturan_repository.dart';
import '../data/repositories/posko_repository.dart';
import '../data/repositories/riwayat_repository.dart';
import '../models/riwayat_transaksi.dart';
import '../services/file_service.dart';
import '../services/perangkat_service.dart';
import '../services/session_service.dart';
import '../services/sinkron_service.dart';
import '../utils/app_snackbar.dart';
import '../utils/waktu_wib.dart';
import 'confirm_dialog.dart';
import 'secondary_button.dart';

class KirimKeAdminButton extends StatefulWidget {
  const KirimKeAdminButton({super.key});

  @override
  State<KirimKeAdminButton> createState() => _KirimKeAdminButtonState();
}

class _KirimKeAdminButtonState extends State<KirimKeAdminButton> {
  bool _mengirim = false;

  Future<void> _kirim() async {
    final poskoId = SessionService.instance.poskoId;
    final posko = poskoId == null ? null : await PoskoRepository.instance.findById(poskoId);
    if (!mounted) return;
    if (posko == null) {
      AppSnackbar.show(context, 'Akun belum ditempatkan di posko. Hubungi admin.',
          isError: true);
      return;
    }

    final yakin = await ConfirmDialog.show(
      context,
      title: 'Kirim data ke admin?',
      message: 'Data pengungsi & logistik posko ${posko.nama} dikirim ke HP '
          'admin. Pilih Bluetooth atau Quick Share, lalu pilih HP admin.\n\n'
          'Di HP admin: ketuk file ZIP → Buka dengan LOGEVA → YA, SINKRONKAN.',
      confirmText: 'KIRIM',
    );
    if (!yakin || !mounted) return;

    setState(() => _mengirim = true);
    try {
      final waktu = DateTime.now();
      final (nama, bytes) = await SinkronService.buatFile(
        posko,
        dibuatOleh: SessionService.instance.namaPencatat,
        waktu: waktu,
        kodeRelawan: await SinkronService.kodeRelawanLogin(),
      );
      final ok = await FileService.bagikan(nama, bytes, judul: 'Kirim data ke admin');
      if (ok) {
        // Sama persis dengan dibuat_pada di file: dicocokkan dengan tanda
        // terima dari HP Induk.
        await PengaturanRepository.instance.tandaiTerkirim(WaktuWib.tanggalWaktu(waktu));
        DataEvents.instance.notifyChanged();
        await RiwayatRepository.instance.log(
          jenis: RiwayatTransaksi.jenisExport,
          jenisData: 'Sinkron Antar-HP',
          berhasil: true,
          // LOG SETOR DATA: apa yang disetor & nama filenya.
          keterangan: 'Setor ke admin: ${SinkronService.teksIsi(bytes)} · $nama',
        );
      }
      if (!mounted || !ok) return;
      AppSnackbar.show(
        context,
        'Data terkirim. Minta admin membuka file di HP-nya → Buka dengan '
        'LOGEVA → YA, SINKRONKAN.',
        duration: const Duration(seconds: 8),
      );
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Gagal mengirim: $e', isError: true);
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!PerangkatService.isAnggota) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SecondaryButton(
        text: 'KIRIM DATA KE ADMIN (BLUETOOTH)',
        icon: Icons.bluetooth_rounded,
        height: 54,
        isLoading: _mengirim,
        onPressed: _kirim,
      ),
    );
  }
}
