// ============================================================
// cadangan_screen.dart
// CADANGAN & PEMULIHAN DATA HP (tanpa internet).
//  - Dari Settings admin : cadangkan + pulihkan.
//  - Dari layar awal     : hanya pulihkan, dan hanya di HP yang masih
//    kosong (supaya orang yang belum login tidak bisa menimpa data).
// Setelah dipulihkan, semua orang harus login ulang.
// ============================================================

import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/cadangan_service.dart';
import '../../services/file_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/waktu_wib.dart';
import '../../widgets/app_background.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/info_card.dart';
import '../../widgets/langkah_card.dart';
import '../../widgets/minta_kata_sandi_dialog.dart';
import '../../widgets/page_header.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';

class CadanganScreen extends StatefulWidget {
  /// true = dibuka dari layar awal (belum login): hanya pemulihan di HP kosong.
  final bool dariLayarAwal;

  const CadanganScreen({super.key, this.dariLayarAwal = false});

  @override
  State<CadanganScreen> createState() => _CadanganScreenState();
}

class _CadanganScreenState extends State<CadanganScreen> {
  bool _membuat = false;
  bool _sibuk = false;
  FileCadangan? _file;
  String? _namaFile;
  String? _ditolak;

  Future<void> _cadangkan({required bool bagikan}) async {
    final lanjut = await ConfirmDialog.show(
      context,
      title: 'Data pribadi & akun',
      message: 'File cadangan berisi SELURUH data HP ini, termasuk data pribadi '
          'pengungsi dan akun (PIN relawan). Simpan di flashdisk/HP yang aman, '
          'jangan dibagikan ke orang lain.',
      confirmText: 'LANJUTKAN',
    );
    if (!lanjut || !mounted) return;
    setState(() => _membuat = true);
    try {
      final (nama, bytes) = await CadanganService.buat();
      final ok = bagikan
          ? await FileService.bagikan(nama, bytes, judul: 'Kirim cadangan')
          : await FileService.saveBytes(nama, bytes, dialogTitle: 'Simpan cadangan');
      if (mounted && ok) AppSnackbar.show(context, 'Cadangan $nama dibuat.');
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Cadangan gagal dibuat: $e', isError: true);
    } finally {
      if (mounted) setState(() => _membuat = false);
    }
  }

  Future<void> _pilih() async {
    setState(() => _sibuk = true);
    try {
      final f = await FileService.pickZip();
      if (f == null) return;
      final file = await _bacaDenganKataSandi(f.bytes);
      if (file == null) return;
      final kosong = await CadanganService.hpKosong();
      if (!mounted) return;
      setState(() {
        _file = file;
        _namaFile = f.name;
        _ditolak = widget.dariLayarAwal && !kosong
            ? 'HP ini sudah berisi data. Pemulihan dari layar awal hanya untuk HP '
                'yang baru dipasang. Login sebagai admin, lalu buka Settings → '
                'Cadangan & Pemulihan.'
            : null;
      });
    } on CadanganException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message, isError: true);
    } on FileServiceException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  /// Baca cadangan; kalau terkunci, minta kata sandi posko (boleh ulang
  /// kalau salah). null = dibatalkan.
  Future<FileCadangan?> _bacaDenganKataSandi(List<int> bytes) async {
    String? kataSandi;
    String? salah;
    while (true) {
      try {
        return CadanganService.baca(bytes, kataSandi: kataSandi);
      } on CadanganException catch (e) {
        if (!e.perluKataSandi || !mounted) rethrow;
        if (kataSandi != null) salah = e.message;
        kataSandi = await MintaKataSandiDialog.show(context, pesanSalah: salah);
        if (kataSandi == null) return null;
      }
    }
  }

  Future<void> _pulihkan() async {
    final file = _file;
    if (file == null) return;
    final lanjut = await ConfirmDialog.show(
      context,
      title: 'Ganti semua data HP ini?',
      message: 'SELURUH data di HP ini (posko, pengungsi, logistik, akun) akan '
          'DIGANTI dengan isi cadangan. Data yang belum dicadangkan akan hilang. '
          'Setelah itu semua orang login ulang.',
      confirmText: 'PULIHKAN',
    );
    if (!lanjut || !mounted) return;
    setState(() => _sibuk = true);
    try {
      await CadanganService.pulihkan(file);
      SessionService.instance.clear();
      if (!mounted) return;
      AppSnackbar.show(context,
          'Data dipulihkan. Login dengan akun dari cadangan. Jangan pakai HP lama '
          'dan HP ini bersamaan sebagai HP Induk.');
      Navigator.of(context)
          .pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
    } on CadanganException catch (e) {
      if (!mounted) return;
      setState(() => _sibuk = false);
      AppSnackbar.show(context, e.message, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final file = _file;
    final dibuat = file?.dibuatPada;

    return Scaffold(
      body: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: widget.dariLayarAwal ? 'Pulihkan dari Cadangan' : 'Cadangan & Pemulihan',
              subtitle: 'Tanpa internet',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),

            if (!widget.dariLayarAwal) ...[
              Text('CADANGKAN DATA', style: AppTextStyles.label(p)),
              const SizedBox(height: 10),
              Text(
                'Buat cadangan secara berkala (misal setiap sore) dan simpan di '
                'flashdisk atau HP lain. Jika HP ini rusak/hilang, HP pengganti '
                'bisa dipulihkan dari file ini.',
                style: AppTextStyles.small(p),
              ),
              const SizedBox(height: 12),
              PrimaryButton(
                text: 'SIMPAN CADANGAN KE FILE',
                isLoading: _membuat,
                onPressed: _membuat ? null : () => _cadangkan(bagikan: false),
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                text: 'KIRIM KE HP LAIN (BLUETOOTH)',
                icon: Icons.share_rounded,
                onPressed: _membuat ? null : () => _cadangkan(bagikan: true),
              ),
              const SizedBox(height: 28),
            ],

            Text('PULIHKAN DARI CADANGAN', style: AppTextStyles.label(p)),
            const SizedBox(height: 10),
            const LangkahCard(
              title: 'UNTUK HP PENGGANTI',
              langkah: [
                'Pasang aplikasi LOGEVA di HP pengganti.',
                'Pilih file cadangan_logeva_....zip terbaru, periksa isinya.',
                'Tekan PULIHKAN, lalu login dengan akun yang sama seperti di HP lama.',
              ],
              note: 'HP pengganti menjadi sama persis dengan HP lama (termasuk peran '
                  'HP Induk/Anggota), jadi HP Anggota tetap bisa sinkron dengannya.',
            ),
            const SizedBox(height: 14),
            SecondaryButton(
              text: file == null ? 'PILIH FILE CADANGAN' : 'PILIH FILE LAIN',
              icon: Icons.folder_open_rounded,
              height: 54,
              isLoading: _sibuk && file == null,
              onPressed: _sibuk ? null : _pilih,
            ),
            if (file != null) ...[
              const SizedBox(height: 16),
              InfoCard(
                title: 'ISI CADANGAN',
                rows: {
                  'File': _namaFile ?? '-',
                  'Dibuat': dibuat == null ? '-' : '${WaktuWib.tanggalWaktu(dibuat)} WIB',
                  'Dari': file.dariAnggota ? 'HP Anggota' : 'HP Induk',
                  'Posko': file.namaPosko.isEmpty ? '-' : file.namaPosko.join(', '),
                  'Pengungsi': '${file.jumlahPengungsiAktif} orang',
                  'Relawan': '${file.jumlah('relawan')} akun',
                  'Admin': '${file.jumlah('admin')} akun',
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
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                  ),
                  child: Text(_ditolak!,
                      style: AppTextStyles.small(p).copyWith(color: p.textPrimary)),
                )
              else
                PrimaryButton(
                  text: 'PULIHKAN',
                  isLoading: _sibuk,
                  onPressed: _sibuk ? null : _pulihkan,
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
