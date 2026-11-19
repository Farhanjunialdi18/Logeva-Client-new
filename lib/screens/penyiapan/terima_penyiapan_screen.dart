// ============================================================
// terima_penyiapan_screen.dart
// BUKA FILE DARI HP ADMIN (di HP relawan). Tidak ada fitur penyiapan
// terpisah: file sinkron dari HP admin (Relawan -> BAGIKAN KE HP RELAWAN,
// atau Sinkron -> KIRIM KE HP ANGGOTA) sekaligus memasang akun & data posko.
// Cara utama TANPA mencari file: ketuk file -> Buka dengan LOGEVA.
// Halaman ini hanya petunjuk + jalan cadangan memilih file manual.
// Proses sebenarnya ada di widgets/sinkron_otomatis.dart.
// ============================================================

import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/berkas_masuk_service.dart';
import '../../services/file_service.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/app_background.dart';
import '../../widgets/langkah_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/sinkron_otomatis.dart';

class TerimaPenyiapanScreen extends StatefulWidget {
  const TerimaPenyiapanScreen({super.key});

  @override
  State<TerimaPenyiapanScreen> createState() => _TerimaPenyiapanScreenState();
}

class _TerimaPenyiapanScreenState extends State<TerimaPenyiapanScreen> {
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    final masuk = BerkasMasukService.ambil(JenisBerkas.penyiapan);
    if (masuk != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _proses(masuk));
    }
  }

  /// [masuk] = file dari "Buka dengan LOGEVA"; kosong = pilih file manual.
  Future<void> _proses([BerkasMasuk? masuk]) async {
    setState(() => _sibuk = true);
    try {
      final f = masuk ?? await FileService.pickZip();
      if (f == null || !mounted) return;
      final siap = await SinkronOtomatis.penyiapan(context, f.bytes);
      if (!siap || !mounted) return;
      SessionService.instance.clear();
      final nav = Navigator.of(context);
      nav.pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
      nav.pushNamed(AppRoutes.relawanLogin);
    } on FileServiceException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      body: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Buka File dari HP Admin',
              subtitle: 'Untuk HP relawan (HP Anggota)',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            const LangkahCard(
              title: 'CARA PAKAI (TANPA CARI FILE)',
              langkah: [
                'Nyalakan Bluetooth di HP ini.',
                'Minta admin mengirim file: Relawan → pilih nama Anda → BAGIKAN '
                    'KE HP RELAWAN (atau Sinkron → KIRIM KE HP ANGGOTA) → '
                    'Bluetooth / Quick Share → pilih HP ini.',
                'Terima file di HP ini, lalu KETUK NOTIFIKASI file yang masuk '
                    '→ Buka dengan LOGEVA.',
                'Tekan YA, SINKRONKAN, tunggu sampai selesai, lalu login '
                    'dengan PIN dari admin.',
              ],
              note: 'Tidak perlu internet dan tidak perlu mencari file. Kalau HP '
                  'ini sudah berisi data lain, LOGEVA menawarkan untuk '
                  'mengosongkannya (cadangan dibuat otomatis).',
            ),
            const SizedBox(height: 16),
            Text(
              'Notifikasinya terlewat? Minta admin mengirim ulang lewat Quick '
              'Share atau Bluetooth, lalu langsung ketuk notifikasi yang muncul.',
              style: AppTextStyles.small(p),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: _sibuk ? null : () => _proses(),
                icon: _sibuk
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open_rounded,
                        size: 18, color: AppColors.primary),
                label: const Text('Pilih file yang sudah diterima'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
