// ============================================================
// terima_penyiapan_screen.dart
// SIAPKAN HP INI DARI HP INDUK (di HP Anggota): pilih File Penyiapan
// yang diterima lewat Bluetooth / Quick Share / flashdisk, periksa
// isinya, lalu terapkan. Tanpa internet sama sekali.
// ============================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/berkas_masuk_service.dart';
import '../../services/file_service.dart';
import '../../services/gabung_paket_service.dart';
import '../../services/penyiapan_service.dart';
import '../../services/perangkat_service.dart';
import '../../services/session_service.dart';
import '../../services/sinkron_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/app_background.dart';
import '../../widgets/info_card.dart';
import '../../widgets/langkah_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';

class TerimaPenyiapanScreen extends StatefulWidget {
  const TerimaPenyiapanScreen({super.key});

  @override
  State<TerimaPenyiapanScreen> createState() => _TerimaPenyiapanScreenState();
}

class _TerimaPenyiapanScreenState extends State<TerimaPenyiapanScreen> {
  FilePenyiapan? _file;
  Uint8List? _bytes;
  /// Data posko yang ikut di file (null = file lama, hanya akun).
  ({int pengungsi, int masuk, int keluar})? _isiData;
  String? _namaFile;
  String? _ditolak; // alasan file tidak bisa dipakai di HP ini
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    final masuk = BerkasMasukService.ambil(JenisBerkas.penyiapan);
    if (masuk != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pilih(masuk));
    }
  }

  /// [masuk] = file dari "Buka dengan LOGEVA"; kosong = pilih file.
  Future<void> _pilih([BerkasMasuk? masuk]) async {
    setState(() => _sibuk = true);
    try {
      final f = masuk ?? await FileService.pickZip();
      if (f == null) return;
      final file = PenyiapanService.baca(f.bytes);
      final alasan = await PenyiapanService.cekBoleh(file);
      if (!mounted) return;
      setState(() {
        _file = file;
        _bytes = f.bytes;
        _isiData = SinkronService.ringkasanIsi(f.bytes);
        _namaFile = f.name;
        _ditolak = alasan;
      });
    } on PenyiapanException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message, isError: true);
    } on FileServiceException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _terapkan() async {
    final file = _file;
    if (file == null) return;
    setState(() => _sibuk = true);
    try {
      var pesan = await PenyiapanService.terapkan(file);
      // Data posko yang ikut di file langsung digabung ke HP ini.
      final bytes = _bytes;
      if (_isiData != null && bytes != null) {
        try {
          final hasil = await GabungPaketService.terapkan(bytes);
          pesan = '$pesan Data posko tersinkron (${hasil.ringkasan}).';
        } on GabungException catch (e) {
          pesan = '$pesan Data posko belum masuk: ${e.message} Coba kirim '
              'ulang file dari HP Induk.';
        }
      }
      await PerangkatService.muat();
      if (!mounted) return;
      AppSnackbar.show(context, '$pesan Hapus file penyiapan dari HP ini.',
          duration: const Duration(seconds: 8));
      // Akun di HP ini sudah berganti: sesi lama (misal admin bawaan) ditutup,
      // lalu relawan langsung login dengan PIN-nya.
      SessionService.instance.clear();
      final nav = Navigator.of(context);
      nav.pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
      nav.pushNamed(AppRoutes.relawanLogin);
    } on PenyiapanException catch (e) {
      if (!mounted) return;
      setState(() => _sibuk = false);
      AppSnackbar.show(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final file = _file;

    return Scaffold(
      body: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Siapkan dari HP Induk',
              subtitle: 'Untuk HP relawan (HP Anggota)',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            const LangkahCard(
              title: 'CARA PAKAI',
              langkah: [
                'Di HP Induk (admin): Data Posko → pilih posko → SIAPKAN HP '
                    'ANGGOTA → Bagikan lewat Bluetooth / Quick Share.',
                'Di HP ini, ketuk file yang diterima (notifikasi Quick Share, '
                    'WhatsApp, atau aplikasi File) lalu pilih Buka dengan LOGEVA. '
                    'Atau tekan PILIH FILE di bawah.',
                'Periksa isinya, lalu tekan SIAPKAN & SINKRONKAN.',
                'Login dengan PIN dari admin; data posko langsung muncul.',
              ],
              note: 'Tidak perlu internet. Setelah diterapkan, HP ini menjadi '
                  'HP Anggota posko tersebut.',
            ),
            const SizedBox(height: 16),
            SecondaryButton(
              text: file == null ? 'PILIH FILE PENYIAPAN' : 'PILIH FILE LAIN',
              icon: Icons.folder_open_rounded,
              height: 54,
              isLoading: _sibuk && file == null,
              onPressed: _sibuk ? null : _pilih,
            ),
            if (file != null) ...[
              const SizedBox(height: 16),
              InfoCard(
                title: 'ISI FILE',
                rows: {
                  'File': _namaFile ?? '-',
                  'Posko': file.namaPosko,
                  'Dibuat': '${file.dibuatPada} WIB'
                      '${file.dibuatOleh.isEmpty ? '' : ' oleh ${file.dibuatOleh}'}',
                  'Relawan': '${file.relawan.length} akun',
                  'Admin': '${file.admin.length} akun',
                  'Master barang': '${file.barang.length} barang',
                  if (_isiData != null)
                    'Data posko': '${_isiData!.pengungsi} pengungsi, '
                        '${_isiData!.masuk} barang masuk, '
                        '${_isiData!.keluar} barang keluar',
                },
              ),
              const SizedBox(height: 14),
              if (_ditolak != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                  ),
                  child: Text(_ditolak!,
                      style:
                          AppTextStyles.small(p).copyWith(color: p.textPrimary)),
                )
              else
                PrimaryButton(
                  text: _isiData != null ? 'SIAPKAN & SINKRONKAN' : 'TERAPKAN',
                  isLoading: _sibuk,
                  onPressed: _terapkan,
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
