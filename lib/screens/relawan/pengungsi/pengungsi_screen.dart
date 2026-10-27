// ============================================================
// pengungsi_screen.dart
// HALAMAN DATA PENGUNGSI (relawan): hanya pengungsi di posko tugasnya.
// Total, tombol tambah, pencarian, dan tabel.
// Import/export CSV hanya di layar admin (HP Induk); data relawan berpindah
// lewat Sinkron Antar-HP dan Paket Data Posko.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/pengungsi_repository.dart';
import '../../../models/pengungsi.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/data_table_card.dart';
import '../../../widgets/filter_pengungsi.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/search_field.dart';
import '../../../widgets/summary_card.dart';
import 'pengungsi_detail_sheet.dart';
import 'pengungsi_form_screen.dart';

class PengungsiScreen extends StatefulWidget {
  final VoidCallback onBack;

  const PengungsiScreen({super.key, required this.onBack});

  @override
  State<PengungsiScreen> createState() => _PengungsiScreenState();
}

class _PengungsiScreenState extends State<PengungsiScreen> {
  List<Pengungsi> _semua = [];
  bool _loading = true;
  String _kataCari = '';
  SaringPengungsi _saring = const SaringPengungsi();

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
    final poskoId = SessionService.instance.poskoId;
    final data = poskoId == null
        ? <Pengungsi>[]
        : await PengungsiRepository.instance.getByPosko(poskoId);
    if (!mounted) return;
    setState(() {
      _semua = data;
      _loading = false;
    });
  }

  List<Pengungsi> get _hasilCari {
    final q = _kataCari.trim().toLowerCase();
    return _semua
        .where((e) =>
            _saring.cocok(e) &&
            (q.isEmpty ||
                e.nama.toLowerCase().contains(q) ||
                e.asal.toLowerCase().contains(q) ||
                e.nomorKk.contains(q)))
        .toList();
  }

  void _tambah() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PengungsiFormScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final list = _hasilCari;
    final perluDilengkapi = _semua.where((e) => e.perluDilengkapi).length;
    final diPosko = _semua.where((e) => e.masihDiPosko).length;
    final keluar = _semua.length - diPosko;

    return AppBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Data Pengungsi',
            subtitle: SessionService.instance.poskoLabel,
            showOfflineBadge: true,
            onBack: widget.onBack,
          ),
          const SizedBox(height: 16),

          SummaryCard(
            label: 'Pengungsi di Posko',
            value: _loading ? '...' : '$diPosko Orang',
          ),
          if (keluar > 0) ...[
            const SizedBox(height: 6),
            Text('$keluar orang sudah keluar posko (pulang/pindah/dirujuk).',
                style: AppTextStyles.small(p)),
          ],
          const SizedBox(height: 16),

          PrimaryButton(text: '+ TAMBAH PENGUNGSI', onPressed: _tambah),
          const SizedBox(height: 14),

          SearchField(
            hint: 'Cari nama pengungsi...',
            onChanged: (v) => setState(() => _kataCari = v),
          ),
          const SizedBox(height: 14),
          FilterPengungsi(
            nilai: _saring,
            onChanged: (v) => setState(() => _saring = v),
          ),
          const SizedBox(height: 6),

          if (perluDilengkapi > 0) ...[
            Text(
              '⚠ $perluDilengkapi pengungsi belum punya tanggal lahir '
              '(data versi lama). Ketuk baris bertanda ⚠ untuk melengkapi.',
              style: AppTextStyles.small(p).copyWith(color: AppColors.sun),
            ),
          ],
          const SizedBox(height: 14),

          DataTableCard(
            isLoading: _loading,
            emptyMessage: _kataCari.isNotEmpty
                ? 'Tidak ditemukan "$_kataCari".'
                : _saring.adaFilter
                    ? 'Tidak ada pengungsi yang cocok dengan filter.'
                    : 'Belum ada data pengungsi.',
            columns: const [
              TableColumnSpec('Nama', flex: 30),
              TableColumnSpec('JK', flex: 10),
              TableColumnSpec('Usia', flex: 14),
              TableColumnSpec('Rentan', flex: 22),
              TableColumnSpec('Asal', flex: 24),
            ],
            rows: list
                .map((e) => [
                      '${e.perluDilengkapi ? '⚠ ' : ''}'
                          '${e.masihDiPosko ? '' : '↗ '}${e.nama}',
                      e.isPerempuan ? 'P' : 'L',
                      '${e.usia} th',
                      e.isRentan ? e.kelompokRentan : '-',
                      e.asal,
                    ])
                .toList(),
            onRowTap: (i) => PengungsiDetailSheet.show(context, list[i]),
          ),
          if (list.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Ketuk baris untuk detail, edit, keluar posko, atau hapus.'
              '${list.any((e) => !e.masihDiPosko) ? ' ↗ = sudah keluar posko.' : ''}',
              style: AppTextStyles.small(p).copyWith(color: AppColors.success),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
