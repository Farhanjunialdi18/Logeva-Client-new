// ============================================================
// penyimpanan_screen.dart
// PENYIMPANAN: informasi database lokal di perangkat
// (jenis penyimpanan, versi, dan jumlah data per tabel).
// ============================================================

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../data/database_tables.dart';
import '../../../data/local_database.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/offline_badge.dart';

class PenyimpananScreen extends StatefulWidget {
  const PenyimpananScreen({super.key});

  @override
  State<PenyimpananScreen> createState() => _PenyimpananScreenState();
}

class _PenyimpananScreenState extends State<PenyimpananScreen> {
  /// Label tampilan -> nama tabel.
  static const Map<String, String> _tabel = {
    'Pengungsi': DatabaseTables.pengungsi,
    'Master barang': DatabaseTables.barang,
    'Barang masuk': DatabaseTables.barangMasuk,
    'Barang keluar': DatabaseTables.barangKeluar,
    'Riwayat transaksi': DatabaseTables.riwayat,
    'Relawan': DatabaseTables.relawan,
    'Admin': DatabaseTables.admin,
    'Posko': DatabaseTables.posko,
  };

  Map<String, String>? _jumlah;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hasil = <String, String>{};
    var total = 0;
    for (final entry in _tabel.entries) {
      final n = await LocalDatabase.store.count(entry.value);
      total += n;
      hasil[entry.key] = '$n data';
    }
    hasil['Total'] = '$total data';
    if (!mounted) return;
    setState(() => _jumlah = hasil);
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
              title: 'Penyimpanan',
              subtitle: 'Informasi penyimpanan lokal',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 12),
            const OfflineBadge(),
            const SizedBox(height: 16),

            InfoCard(
              title: 'DATABASE',
              rows: {
                'Jenis': kIsWeb
                    ? 'Memori (mode coba di browser)'
                    : 'SQLite di perangkat',
                'Nama file': DatabaseTables.databaseName,
                'Versi struktur': '${DatabaseTables.version}',
              },
            ),
            const SizedBox(height: 14),

            if (_jumlah == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              InfoCard(title: 'JUMLAH DATA', rows: _jumlah!),
            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  kIsWeb ? Icons.warning_amber_rounded : Icons.info_outline,
                  size: 16,
                  color: kIsWeb ? AppColors.accentAmber : AppColors.accentBlue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kIsWeb
                        ? 'Di browser, data hanya tersimpan sementara dan '
                            'hilang saat halaman di-refresh.'
                        : 'Data tersimpan di perangkat ini saja dan ikut terhapus '
                            'jika aplikasi di-uninstall. Buat cadangan secara '
                            'berkala (Settings → Cadangan & Pemulihan) dan kirim '
                            'Paket Data Posko ke pusat.',
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
