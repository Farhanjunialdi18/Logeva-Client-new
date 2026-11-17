// ============================================================
// sinkron_otomatis.dart
// "BUKA DENGAN LOGEVA" -> langsung tanya "Sinkronkan data?" (YA / TIDAK).
// Kalau YA, data langsung digabung (tanpa dobel) dengan layar progres
// bertahap seperti update aplikasi di Play Store.
//
//   penyiapan : file dari HP Induk di HP relawan yang baru / belum login
//               -> pasang akun + gabung data posko -> login PIN.
//   sinkron   : file dari HP lain saat sudah login -> gabung data.
// ============================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/data_events.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/logistik_repository.dart';
import '../data/repositories/pengaturan_repository.dart';
import '../data/repositories/posko_repository.dart';
import '../data/repositories/riwayat_repository.dart';
import '../models/riwayat_transaksi.dart';
import '../services/cadangan_service.dart';
import '../services/dobel_service.dart';
import '../services/file_service.dart';
import '../services/session_service.dart';
import '../utils/app_snackbar.dart';
import '../utils/password_hasher.dart';
import 'minta_kata_sandi_dialog.dart';
import '../services/gabung_paket_service.dart';
import '../services/penyiapan_service.dart';
import '../services/perangkat_service.dart';
import '../services/sinkron_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'confirm_dialog.dart';
import 'primary_button.dart';

/// Satu tahap progres. Hasil string (boleh null) = catatan untuk ringkasan.
typedef TahapSinkron = ({String label, Future<String?> Function() jalankan});

class SinkronOtomatis {
  SinkronOtomatis._();

  static const String _label = 'Sinkron Antar-HP';

  static String _isi(({int pengungsi, int masuk, int keluar})? isi) => isi == null
      ? ''
      : '\n• ${isi.pengungsi} pengungsi, ${isi.masuk} barang masuk, '
          '${isi.keluar} barang keluar';

  // ---------------- PENYIAPAN (HP RELAWAN BARU) ----------------

  /// File dari HP Induk: siapkan HP ini + gabung data posko.
  /// Hasil true = selesai (HP siap, relawan tinggal login PIN).
  static Future<bool> penyiapan(BuildContext context, Uint8List bytes,
      {bool sudahSetuju = false}) async {
    final FilePenyiapan file;
    try {
      file = PenyiapanService.baca(bytes);
    } on PenyiapanException catch (e) {
      await _gagal(context, e.message);
      return false;
    }
    final ditolak = await PenyiapanService.cekBoleh(file);
    if (!context.mounted) return false;
    if (ditolak != null) {
      // HP sudah berisi data / milik posko lain: tawarkan kosongkan HP
      // (dengan cadangan otomatis) supaya tidak perlu hapus data aplikasi
      // lewat Settings Android.
      if (!await _kosongkanHp(context, ditolak, file.namaPosko)) return false;
      if (!context.mounted) return false;
      return penyiapan(context, bytes, sudahSetuju: true);
    }
    final isi = SinkronService.ringkasanIsi(bytes);

    final ya = sudahSetuju || await ConfirmDialog.show(
      context,
      title: 'Sinkronkan data?',
      message: 'File dari HP Induk posko ${file.namaPosko}'
          '${file.dibuatOleh.isEmpty ? '' : ' (dikirim ${file.dibuatOleh})'}:\n'
          '• ${file.relawan.length} akun relawan, ${file.admin.length} admin'
          '${_isi(isi)}\n\n'
          'Data digabung tanpa dobel. Setelah selesai, login dengan PIN dari admin.',
      confirmText: 'YA, SINKRONKAN',
      cancelText: 'TIDAK',
    );
    if (!ya || !context.mounted) return false;

    return _progres(
      context,
      judul: 'Menyinkronkan data',
      tombolSelesai: 'LOGIN DENGAN PIN',
      tahap: [
        (
          label: 'Memasang akun relawan & admin',
          jalankan: () async {
            await PenyiapanService.terapkan(file);
            return null;
          },
        ),
        if (isi != null)
          (
            label: 'Menggabungkan data posko',
            jalankan: () async {
              final hasil = await GabungPaketService.terapkan(bytes);
              await SinkronService.setelahGabung(bytes);
              return hasil.ringkasan;
            },
          ),
        (
          label: 'Menyelesaikan',
          jalankan: () async {
            await PerangkatService.muat();
            DataEvents.instance.notifyChanged();
            return 'HP ini sekarang HP Anggota ${file.namaPosko}. '
                'Hapus file ZIP dari HP ini.';
          },
        ),
      ],
    );
  }

  // ---------------- SINKRON (SUDAH LOGIN) ----------------

  /// File sinkron dari HP lain: periksa, tanya, lalu gabungkan.
  static Future<bool> sinkron(BuildContext context, Uint8List bytes,
      {String namaFile = ''}) async {
    final PratinjauSinkron cek;
    try {
      cek = await SinkronService.periksa(bytes);
    } on GabungException catch (e) {
      if (context.mounted) await _gagal(context, e.message);
      return false;
    }
    if (!context.mounted) return false;
    if (cek.ditolak != null) {
      await _gagal(context, cek.ditolak!);
      return false;
    }

    final d = cek.data;
    String n(Map<String, int> m) =>
        '${(m[BarisGabung.tambah] ?? 0)} baru, ${(m[BarisGabung.perbarui] ?? 0)} diperbarui';
    final ya = await ConfirmDialog.show(
      context,
      title: 'Sinkronkan data?',
      message: 'File dari ${d.dieksporOleh.isEmpty ? 'HP lain' : d.dieksporOleh} '
          '(${d.dibuatPada} WIB):\n'
          '• Pengungsi: ${n(d.ringkasanPengungsi)}\n'
          '• Barang masuk: ${n(d.ringkasanMasuk)}\n'
          '• Barang keluar: ${n(d.ringkasanKeluar)}'
          '${cek.akun != null ? '\n• Pembaruan akun dari HP Induk' : ''}'
          '${cek.peringatanJam != null ? '\n\n⚠ ${cek.peringatanJam}' : ''}\n\n'
          'Data digabung tanpa dobel.',
      confirmText: 'YA, SINKRONKAN',
      cancelText: 'TIDAK',
    );
    if (!ya || !context.mounted) return false;

    final akun = cek.akun;
    return _progres(
      context,
      judul: 'Menyinkronkan data',
      tombolSelesai: 'SELESAI',
      tahap: [
        if (akun != null)
          (
            label: 'Memperbarui akun dari HP Induk',
            jalankan: () async {
              await PenyiapanService.terapkan(akun);
              return null;
            },
          ),
        (
          label: 'Menggabungkan data',
          jalankan: () async {
            try {
              final hasil = await GabungPaketService.terapkan(bytes);
              await SinkronService.setelahGabung(bytes);
              await RiwayatRepository.instance.log(
                jenis: RiwayatTransaksi.jenisImport,
                jenisData: _label,
                berhasil: true,
                keterangan: '$namaFile: ${hasil.ringkasan}',
              );
              return hasil.ringkasan;
            } on GabungException catch (e) {
              await RiwayatRepository.instance.log(
                jenis: RiwayatTransaksi.jenisImport,
                jenisData: _label,
                berhasil: false,
                keterangan: e.message,
              );
              rethrow;
            }
          },
        ),
        (
          label: 'Menyelesaikan',
          jalankan: () async {
            await PerangkatService.muat();
            DataEvents.instance.notifyChanged();
            final catatan = <String>[];

            // Stok minus: barang keluar (dari beberapa HP) lebih banyak dari
            // barang masuk yang tercatat. Biasanya ada barang masuk yang
            // belum dicatat / belum terkirim dari HP lain.
            final daftarPosko = await PoskoRepository.instance.getAll();
            final minus = <String>[];
            for (final p in daftarPosko) {
              if (p.id == null) continue;
              for (final s in await LogistikRepository.instance.stokMinus(p.id!)) {
                minus.add('• ${s.barang.namaItem} −${-s.jumlah} ${s.barang.satuan}'
                    '${daftarPosko.length > 1 ? ' (${p.nama})' : ''}');
              }
            }
            if (minus.isNotEmpty) {
              catatan.add('⚠ STOK MINUS (barang keluar lebih banyak dari barang '
                  'masuk yang tercatat):\n${minus.join('\n')}\n'
                  'Periksa apakah ada barang masuk yang belum dicatat atau '
                  'belum dikirim dari HP lain.');
            }

            if (!PerangkatService.isAnggota) {
              final dobel = await DobelService.jumlah();
              if (dobel > 0) {
                catatan.add('⚠ Ada $dobel kemungkinan pengungsi dobel (nama & '
                    'tanggal lahir sama, dicatat di HP berbeda). Periksa di '
                    'Data → Sinkron Antar-HP.');
              }
            }
            catatan.add('Hapus file ZIP dari HP ini.');
            return catatan.join('\n\n');
          },
        ),
      ],
    );
  }

  // ---------------- KOSONGKAN HP ----------------

  /// HP ini tidak bisa langsung disiapkan ([alasan]). Tawarkan KOSONGKAN HP:
  ///  1. admin/relawan yang sedang login tidak boleh (HP sedang dipakai);
  ///  2. kalau ada admin dengan password sendiri, password itu diminta;
  ///  3. cadangan seluruh data disimpan otomatis ke Download/LOGEVA;
  ///  4. baru data dihapus. Hasil true = HP sudah kosong.
  static Future<bool> _kosongkanHp(
      BuildContext context, String alasan, String namaPosko) async {
    final sesi = SessionService.instance;
    final admin = sesi.admin;
    final sedangDipakai = sesi.relawan != null ||
        (admin != null && !AdminRepository.instance.masihPasswordBawaan(admin));
    if (sedangDipakai) {
      await _gagal(context, '$alasan\n\nLogout dulu kalau HP ini memang mau '
          'dipindahkan ke posko $namaPosko, lalu buka file ini lagi.');
      return false;
    }

    final isi = await PenyiapanService.isiHp();
    if (!context.mounted) return false;
    final ya = await ConfirmDialog.show(
      context,
      title: 'HP ini sudah berisi data',
      message: '$alasan\n\nSupaya bisa dipakai di posko $namaPosko, HP ini '
          'dikosongkan dulu:\n'
          '• ${isi.posko} posko, ${isi.relawan} relawan, ${isi.admin} admin\n'
          '• ${isi.pengungsi} pengungsi, ${isi.logistik} catatan logistik\n\n'
          'Cadangan seluruh data disimpan otomatis ke Download/LOGEVA sebelum '
          'dihapus.',
      confirmText: 'KOSONGKAN & SIAPKAN',
      cancelText: 'BATAL',
    );
    if (!ya || !context.mounted) return false;

    // Admin dengan password sendiri = HP ini mungkin HP Induk sungguhan.
    final adminRepo = AdminRepository.instance;
    final pemilik = (await adminRepo.getAll())
        .where((a) => !adminRepo.masihPasswordBawaan(a))
        .toList();
    if (pemilik.isNotEmpty) {
      String? salah;
      while (true) {
        if (!context.mounted) return false;
        final sandi = await MintaKataSandiDialog.show(
          context,
          judul: 'Password admin HP ini',
          pesan: 'HP ini punya akun admin sendiri. Masukkan password salah satu '
              'admin di HP ini untuk mengizinkan pengosongan.',
          pesanSalah: salah,
        );
        if (sandi == null) return false;
        if (pemilik.any((a) => PasswordHasher.verify(sandi,
            hash: a.passwordHash, salt: a.passwordSalt))) {
          break;
        }
        salah = 'Password salah.';
      }
    }

    try {
      final (nama, bytes) = await CadanganService.buat();
      final tersimpan = await FileService.saveBytes(nama, bytes,
          dialogTitle: 'Simpan cadangan sebelum dikosongkan');
      if (!tersimpan) return false;
      await PenyiapanService.kosongkan();
      PengaturanRepository.instance.lupakanCache();
      await PerangkatService.muat();
      sesi.clear();
      if (context.mounted) {
        AppSnackbar.show(context, 'HP dikosongkan. ${FileService.pesanTersimpan(nama)}',
            duration: const Duration(seconds: 6));
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        await _gagal(context, 'HP tidak dikosongkan karena cadangan gagal dibuat: $e');
      }
      return false;
    }
  }

  // ---------------- DIALOG ----------------

  static Future<void> _gagal(BuildContext context, String pesan) => showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('File tidak bisa disinkronkan'),
          content: Text(pesan),
          actions: [
            TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('TUTUP')),
          ],
        ),
      );

  static Future<bool> _progres(
    BuildContext context, {
    required String judul,
    required String tombolSelesai,
    required List<TahapSinkron> tahap,
  }) async {
    final hasil = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: const Color(0xB3000000),
      builder: (_) => _ProgresDialog(judul: judul, tombolSelesai: tombolSelesai, tahap: tahap),
    );
    return hasil ?? false;
  }
}

class _ProgresDialog extends StatefulWidget {
  final String judul;
  final String tombolSelesai;
  final List<TahapSinkron> tahap;

  const _ProgresDialog({
    required this.judul,
    required this.tombolSelesai,
    required this.tahap,
  });

  @override
  State<_ProgresDialog> createState() => _ProgresDialogState();
}

class _ProgresDialogState extends State<_ProgresDialog> {
  int _selesai = 0; // jumlah tahap yang sudah selesai
  String? _error;
  final List<String> _catatan = [];

  bool get _tuntas => _selesai == widget.tahap.length;

  @override
  void initState() {
    super.initState();
    _jalankan();
  }

  Future<void> _jalankan() async {
    for (final t in widget.tahap) {
      try {
        final c = await t.jalankan();
        if (c != null && c.isNotEmpty) _catatan.add(c);
      } catch (e) {
        if (!mounted) return;
        setState(() => _error = e is PenyiapanException
            ? e.message
            : e is GabungException
                ? e.message
                : '$e');
        return;
      }
      if (!mounted) return;
      setState(() => _selesai++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final total = widget.tahap.length;
    final persen = (_selesai / total * 100).round();

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: p.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: p.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _error != null
                      ? 'Sinkron gagal'
                      : _tuntas
                          ? 'Sinkron selesai'
                          : widget.judul,
                  style: AppTextStyles.sectionTitle(p).copyWith(fontSize: 20),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _error != null ? _selesai / total : (_tuntas ? 1 : null),
                    minHeight: 8,
                    color: _error != null ? AppColors.error : AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _tuntas ? '100%' : '$persen% · tahap ${_selesai + 1} dari $total',
                  style: AppTextStyles.small(p),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < total; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 22,
                          height: 22,
                          child: i < _selesai
                              ? const Icon(Icons.check_circle_rounded,
                                  color: AppColors.primary, size: 22)
                              : i == _selesai && _error != null
                                  ? const Icon(Icons.error_rounded,
                                      color: AppColors.error, size: 22)
                                  : i == _selesai
                                      ? const Padding(
                                          padding: EdgeInsets.all(3),
                                          child: CircularProgressIndicator(strokeWidth: 2.5),
                                        )
                                      : Icon(Icons.radio_button_unchecked_rounded,
                                          color: p.textSecondary, size: 22),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(widget.tahap[i].label, style: AppTextStyles.body(p)),
                        ),
                      ],
                    ),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: AppTextStyles.small(p).copyWith(color: AppColors.error)),
                ] else if (_tuntas && _catatan.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 240),
                    child: SingleChildScrollView(
                      child: Text(_catatan.join('\n\n'), style: AppTextStyles.small(p)),
                    ),
                  ),
                ],
                if (_error != null || _tuntas) ...[
                  const SizedBox(height: 20),
                  PrimaryButton(
                    text: _error != null ? 'TUTUP' : widget.tombolSelesai,
                    onPressed: () => Navigator.of(context).pop(_error == null),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
