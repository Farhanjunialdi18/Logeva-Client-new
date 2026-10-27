// ============================================================
// laporan_harian_screen.dart
// LAPORAN HARIAN (teks): pratinjau + SALIN / BAGIKAN. Bisa dikirim lewat
// SMS (tanpa internet, cukup sinyal telepon), Bluetooth, atau dibacakan
// lewat radio/HT.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/file_service.dart';
import '../../services/laporan_harian_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/app_background.dart';
import '../../widgets/page_header.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';

class LaporanHarianScreen extends StatefulWidget {
  /// null = semua posko.
  final int? poskoId;

  const LaporanHarianScreen({super.key, this.poskoId});

  @override
  State<LaporanHarianScreen> createState() => _LaporanHarianScreenState();
}

class _LaporanHarianScreenState extends State<LaporanHarianScreen> {
  String? _teks;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final teks = await LaporanHarianService.buat(
      poskoId: widget.poskoId,
      oleh: SessionService.instance.namaPencatat,
    );
    if (mounted) setState(() => _teks = teks);
  }

  Future<void> _salin() async {
    await Clipboard.setData(ClipboardData(text: _teks!));
    if (mounted) AppSnackbar.show(context, 'Laporan disalin. Tempel di SMS / pesan.');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final teks = _teks;

    return Scaffold(
      body: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Laporan Harian',
              subtitle: 'Teks singkat untuk SMS / radio',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            Text(
              'Kirim lewat SMS (tetap jalan tanpa internet selama ada sinyal '
              'telepon), Bluetooth, atau bacakan lewat radio/HT ke posko induk.',
              style: AppTextStyles.small(p),
            ),
            const SizedBox(height: 14),
            if (teks == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: p.border),
                ),
                child: SelectableText(
                  teks,
                  style: TextStyle(fontSize: 13, height: 1.45, color: p.textPrimary),
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(text: 'SALIN TEKS', onPressed: _salin),
              const SizedBox(height: 10),
              SecondaryButton(
                text: 'BAGIKAN (SMS / BLUETOOTH)',
                icon: Icons.share_rounded,
                onPressed: () => FileService.bagikanTeks(teks, judul: 'Laporan harian LOGEVA'),
              ),
              const SizedBox(height: 8),
              Text('Laporan berisi angka ringkas, tanpa nama pengungsi.',
                  style: AppTextStyles.small(p).copyWith(color: AppColors.success)),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
