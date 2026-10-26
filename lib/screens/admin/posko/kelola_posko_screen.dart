// ============================================================
// kelola_posko_screen.dart
// HALAMAN KELOLA POSKO (tab Data -> Data Posko):
// jumlah posko, tombol tambah, pencarian, daftar posko.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../models/posko.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/account_tile.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/search_field.dart';
import '../../../widgets/summary_card.dart';
import '../../../services/perangkat_service.dart';
import '../../../widgets/dikelola_induk_banner.dart';
import 'posko_detail_screen.dart';
import 'posko_form_screen.dart';

class KelolaPoskoScreen extends StatefulWidget {
  const KelolaPoskoScreen({super.key});

  @override
  State<KelolaPoskoScreen> createState() => _KelolaPoskoScreenState();
}

class _KelolaPoskoScreenState extends State<KelolaPoskoScreen> {
  List<Posko> _semua = [];
  bool _loading = true;
  String _kataCari = '';

  @override
  void initState() {
    super.initState();
    _load();
    DataEvents.instance.addListener(_load);
  }

  @override
  void dispose() {
    DataEvents.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final posko = await PoskoRepository.instance.getAll();
    posko.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _semua = posko;
      _loading = false;
    });
  }

  List<Posko> get _hasilFilter {
    final q = _kataCari.trim().toLowerCase();
    if (q.isEmpty) return _semua;
    return _semua
        .where((p) =>
            p.nama.toLowerCase().contains(q) ||
            p.namaDesa.toLowerCase().contains(q))
        .toList();
  }

  void _tambah() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PoskoFormScreen()),
    );
  }

  void _bukaDetail(Posko posko) {
    if (posko.id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PoskoDetailScreen(poskoId: posko.id!)),
    );
  }

  static List<String> _baris(Posko p) {
    final hari = p.hariKe();
    return [
      [
        if (p.namaDesa.isNotEmpty) p.namaDesa,
        p.kapasitas > 0 ? 'Kapasitas ${p.kapasitas} orang' : 'Kapasitas -',
      ].join(' · '),
      hari == null ? p.statusLabel : '${p.statusLabel} · Hari ke-$hari',
      if (!p.lengkap) '⚠ Data belum lengkap untuk ekspor',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final list = _hasilFilter;

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Data Posko',
              subtitle: 'Kelola posko dan status operasionalnya',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),

            SummaryCard(
              label: 'Jumlah posko',
              value: _loading ? '...' : '${_semua.length} Posko',
            ),
            const SizedBox(height: 16),

            if (PerangkatService.isAnggota)
              const DikelolaIndukBanner()
            else
              PrimaryButton(text: '+ TAMBAH POSKO', onPressed: _tambah),
            const SizedBox(height: 14),

            SearchField(
              hint: 'Cari nama posko atau desa...',
              onChanged: (v) => setState(() => _kataCari = v),
            ),
            const SizedBox(height: 14),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (list.isEmpty)
              EmptyState(
                icon: Icons.home_work_rounded,
                message: _kataCari.isNotEmpty
                    ? 'Tidak ada posko yang cocok.'
                    : 'Belum ada posko.\nTekan "+ TAMBAH POSKO" untuk membuat posko.',
              )
            else
              for (final posko in list) ...[
                AccountTile(
                  icon: Icons.home_work_rounded,
                  iconColor: posko.isBeroperasi
                      ? AppColors.success
                      : AppColors.primary,
                  title: posko.nama,
                  lines: _baris(posko),
                  onTap: () => _bukaDetail(posko),
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
