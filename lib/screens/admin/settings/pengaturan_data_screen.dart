// ============================================================
// pengaturan_data_screen.dart
// PENGATURAN DATA: penjelasan format CSV untuk import/export
// (harus sama dengan Logeva Web) + unduh template CSV kosong.
// ============================================================

import 'package:flutter/material.dart';

import '../../../services/csv_service.dart';
import '../../../services/file_service.dart';
import '../../../services/master_barang_csv.dart';
import '../../../services/pengungsi_csv.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/app_snackbar.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/secondary_button.dart';

class PengaturanDataScreen extends StatefulWidget {
  const PengaturanDataScreen({super.key});

  @override
  State<PengaturanDataScreen> createState() => _PengaturanDataScreenState();
}

class _PengaturanDataScreenState extends State<PengaturanDataScreen> {
  String? _sedangMenyimpan; // nama file yang sedang disimpan

  /// Simpan file CSV berisi baris judul kolom saja (template).
  Future<void> _unduhTemplate(String fileName, List<String> headers) async {
    setState(() => _sedangMenyimpan = fileName);
    try {
      final saved = await FileService.saveCsv(
        fileName,
        CsvService.encode(headers, const []),
      );
      if (!mounted) return;
      if (saved) AppSnackbar.show(context, 'Template $fileName disimpan.');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, 'Gagal menyimpan template: $e', isError: true);
    } finally {
      if (mounted) setState(() => _sedangMenyimpan = null);
    }
  }

  Widget _formatCard({
    required String judul,
    required List<String> headers,
    required String fileName,
  }) {
    final p = AppPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judul, style: AppTextStyles.cardTitle(p)),
          const SizedBox(height: 10),
          Text('Urutan kolom:', style: AppTextStyles.small(p)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final h in headers)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: p.surfaceAlt,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: p.border),
                  ),
                  child: Text(
                    h,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: p.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          SecondaryButton(
            text: 'UNDUH TEMPLATE CSV',
            icon: Icons.file_download_outlined,
            height: 48,
            isLoading: _sedangMenyimpan == fileName,
            onPressed: _sedangMenyimpan != null
                ? null
                : () => _unduhTemplate(fileName, headers),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Pengaturan Data',
              subtitle: 'Format import dan export CSV',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),

            const InfoCard(
              title: 'ATURAN FILE CSV',
              rows: {
                'Export': 'Pemisah koma ( , )',
                'Import': 'Koma ( , ) atau titik koma ( ; )',
                'Encoding': 'UTF-8',
                'Tanggal lahir': 'TAHUN-BULAN-TANGGAL (1990-07-25)',
                'Jenis kelamin': 'Laki-laki / Perempuan',
                'Kelompok rentan': 'Tidak, Ibu Hamil, Lansia, Bayi, '
                    'Disabilitas, Sakit',
              },
              note: 'Baris pertama file harus berisi nama kolom. File '
                  'pengungsi berlaku untuk satu posko. Kalau ada baris yang '
                  'salah, tidak ada data yang disimpan (sama dengan website).',
            ),
            const SizedBox(height: 14),

            _formatCard(
              judul: 'DATA PENGUNGSI',
              headers: PengungsiCsv.headers,
              fileName: 'template_pengungsi.csv',
            ),
            const SizedBox(height: 14),
            _formatCard(
              judul: 'MASTER BARANG',
              headers: MasterBarangCsv.headers,
              fileName: 'template_master_barang.csv',
            ),
            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    size: 16, color: AppColors.accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Nama kolom harus sama dengan tabel di Logeva Web agar '
                    'file bisa dipindahkan bolak-balik tanpa diubah.',
                    style: AppTextStyles.small(p),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
