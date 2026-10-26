// ============================================================
// terima_penyiapan_screen.dart
// SIAPKAN HP INI DARI HP INDUK (di HP Anggota): pilih File Penyiapan
// yang diterima lewat Bluetooth / Quick Share / flashdisk, periksa
// isinya, lalu terapkan. Tanpa internet sama sekali.
// ============================================================

import 'package:flutter/material.dart';

import '../../services/file_service.dart';
import '../../services/penyiapan_service.dart';
import '../../services/perangkat_service.dart';
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
  String? _namaFile;
  String? _ditolak; // alasan file tidak bisa dipakai di HP ini
  bool _sibuk = false;

  Future<void> _pilih() async {
    setState(() => _sibuk = true);
    try {
      final f = await FileService.pickZip();
      if (f == null) return;
      final file = PenyiapanService.baca(f.bytes);
      final alasan = await PenyiapanService.cekBoleh(file);
      if (!mounted) return;
      setState(() {
        _file = file;
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
      final pesan = await PenyiapanService.terapkan(file);
      await PerangkatService.muat();
      if (!mounted) return;
      AppSnackbar.show(context, '$pesan Hapus file penyiapan dari HP ini.');
      Navigator.of(context).pop();
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
                'Terima file di HP ini, lalu tekan PILIH FILE di bawah.',
                'Periksa isinya, lalu tekan TERAPKAN.',
              ],
              note: 'Tidak perlu internet. Setelah diterapkan, HP ini menjadi '
                  'HP Anggota: relawan login dengan PIN dari admin.',
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
                  text: 'TERAPKAN',
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
