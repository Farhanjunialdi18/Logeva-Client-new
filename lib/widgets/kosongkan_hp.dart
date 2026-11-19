// ============================================================
// kosongkan_hp.dart
// KOSONGKAN HP INI: menghapus posko, akun, data pengungsi, logistik &
// riwayat supaya HP bisa dipindahkan ke posko / orang lain.
//   - Admin  : Settings -> Kosongkan HP ini (password admin).
//   - Relawan: Info Posko & Akun -> Kosongkan HP ini (PIN relawan), HANYA
//              kalau semua data sudah disetor ke admin.
// Langkah pengaman:
//   1. ringkasan isi HP yang akan dihapus + konfirmasi;
//   2. password admin / PIN relawan diketik ulang;
//   3. cadangan seluruh data disimpan otomatis ke Download/LOGEVA (butuh
//      kata sandi posko; tanpa itu ada konfirmasi tambahan);
//   4. data dihapus, kembali ke layar awal (akun admin bawaan admin123).
// Penawaran otomatis saat menerima file dari HP admin posko lain tetap ada
// (widgets/sinkron_otomatis.dart).
// ============================================================

import 'package:flutter/material.dart';

import '../data/repositories/admin_repository.dart';
import '../data/repositories/pengaturan_repository.dart';
import '../data/repositories/relawan_repository.dart';
import '../models/admin.dart';
import '../models/relawan.dart';
import '../routes/app_routes.dart';
import '../services/cadangan_service.dart';
import '../services/file_service.dart';
import '../services/penyiapan_service.dart';
import '../services/perangkat_service.dart';
import '../services/session_service.dart';
import '../services/sinkron_service.dart';
import '../utils/app_snackbar.dart';
import '../utils/password_hasher.dart';
import 'confirm_dialog.dart';
import 'minta_kata_sandi_dialog.dart';

class KosongkanHp {
  KosongkanHp._();

  static Future<void> jalankan(BuildContext context) async {
    final sesi = SessionService.instance;
    final adminId = sesi.admin?.id;
    final Admin? admin =
        adminId == null ? null : await AdminRepository.instance.findById(adminId);
    final relawanId = sesi.relawan?.relawanId;
    final Relawan? relawan = admin != null || relawanId == null
        ? null
        : await RelawanRepository.instance.findById(relawanId);
    if ((admin == null && relawan == null) || !context.mounted) return;

    // Relawan: data yang belum disetor ke admin tidak boleh ikut terhapus.
    var peringatan = '';
    if (relawan != null) {
      final status = await SinkronService.statusKirim();
      if (!context.mounted) return;
      if (status.belumTerkirim > 0) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Setor data dulu'),
            content: Text('Masih ada ${status.belumTerkirim} perubahan yang BELUM '
                'disetor ke admin. Tekan KIRIM DATA KE ADMIN dulu, baru HP ini '
                'bisa dikosongkan.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(c).pop(),
                child: const Text('TUTUP'),
              ),
            ],
          ),
        );
        return;
      }
      if (status.terakhirKirim != null && !status.sudahDikonfirmasi) {
        peringatan = '\n\n⚠ Setoran terakhir Anda belum dikonfirmasi admin. '
            'Pastikan admin sudah menerima & menggabungkan file Anda.';
      }
    }

    // 1. Ringkasan & konfirmasi
    final isi = await PenyiapanService.isiHp();
    if (!context.mounted) return;
    final ya = await ConfirmDialog.show(
      context,
      title: 'Kosongkan HP ini?',
      message: 'SEMUA data di HP ini akan dihapus:\n'
          '• ${isi.posko} posko, ${isi.relawan} relawan, ${isi.admin} admin\n'
          '• ${isi.pengungsi} pengungsi, ${isi.logistik} catatan logistik\n\n'
          'Pastikan data sudah disetor / diekspor ke pusat. Cadangan dibuat '
          'otomatis ke Download/LOGEVA sebelum dihapus. Setelah itu HP kembali '
          'seperti baru.$peringatan',
      confirmText: 'LANJUTKAN',
      cancelText: 'BATAL',
    );
    if (!ya || !context.mounted) return;

    // 2. Password admin / PIN relawan
    String? salah;
    while (true) {
      final sandi = await MintaKataSandiDialog.show(
        context,
        judul: admin != null ? 'Password admin' : 'PIN relawan',
        pesan: admin != null
            ? 'Ketik password admin ${admin.nama} untuk mengosongkan HP ini.'
            : 'Ketik PIN Anda (${relawan!.nama}) untuk mengosongkan HP ini.',
        pesanSalah: salah,
      );
      if (sandi == null || !context.mounted) return;
      final cocok = admin != null
          ? PasswordHasher.verify(sandi, hash: admin.passwordHash, salt: admin.passwordSalt)
          : (await RelawanRepository.instance.findByPin(sandi))?.id == relawan!.id;
      if (!context.mounted) return;
      if (cocok) break;
      salah = admin != null ? 'Password salah.' : 'PIN salah.';
    }

    // 3. Cadangan (butuh kata sandi posko)
    final adaKataSandi =
        (await PengaturanRepository.instance.kataSandiBerkas()).isNotEmpty;
    String pesan = 'HP dikosongkan.';
    try {
      if (adaKataSandi) {
        final (nama, bytes) = await CadanganService.buat();
        final tersimpan = await FileService.saveBytes(nama, bytes,
            dialogTitle: 'Simpan cadangan sebelum dikosongkan');
        if (!tersimpan) return;
        pesan = 'HP dikosongkan. ${FileService.pesanTersimpan(nama)}';
      } else if (isi.pengungsi + isi.logistik > 0) {
        if (!context.mounted) return;
        final tetap = await ConfirmDialog.show(
          context,
          title: 'Kosongkan tanpa cadangan?',
          message: 'Kata sandi posko belum diatur, jadi cadangan tidak bisa dibuat. '
              '${isi.pengungsi} pengungsi dan ${isi.logistik} catatan logistik akan '
              'HILANG. Lanjutkan hanya kalau data itu sudah dikirim ke pusat atau '
              'hanya data uji coba.',
          confirmText: 'HAPUS',
          cancelText: 'BATAL',
        );
        if (!tetap) return;
      }

      // 4. Hapus & kembali ke layar awal
      await PenyiapanService.kosongkan();
      PengaturanRepository.instance.lupakanCache();
      await PerangkatService.muat();
      sesi.clear();
      if (!context.mounted) return;
      final nav = Navigator.of(context, rootNavigator: true);
      nav.pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
      final ctx = nav.context;
      if (ctx.mounted) {
        AppSnackbar.show(ctx, pesan, duration: const Duration(seconds: 6));
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackbar.show(context, 'HP tidak dikosongkan: $e', isError: true);
      }
    }
  }
}
