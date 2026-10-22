// ============================================================
// admin_pengungsi_screen.dart
// DATA PENGUNGSI versi ADMIN: seluruh posko.
// Total, cari, filter posko & kondisi, daftar kartu, import/export CSV.
// Ketuk kartu -> panel detail (EDIT / HAPUS) milik halaman relawan.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/data_options.dart';
import '../../../data/data_events.dart';
import '../../../data/repositories/pengungsi_repository.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../models/pengungsi.dart';
import '../../../services/transfer_service.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/account_tile.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/search_field.dart';
import '../../../widgets/secondary_button.dart';
import '../../../widgets/summary_card.dart';
import '../../../widgets/transfer_result_dialog.dart';
import '../../relawan/pengungsi/pengungsi_detail_sheet.dart';

class AdminPengungsiScreen extends StatefulWidget {
  const AdminPengungsiScreen({super.key});

  @override
  State<AdminPengungsiScreen> createState() => _AdminPengungsiScreenState();
}

class _AdminPengungsiScreenState extends State<AdminPengungsiScreen> {
  static const String _semuaPosko = 'Semua Posko';
  static const String _semuaKondisi = 'Semua Kondisi';

  List<Pengungsi> _semua = [];
  List<String> _daftarPosko = [];
  bool _loading = true;
  String _kataCari = '';
  String _filterPosko = _semuaPosko;
  String _filterKondisi = _semuaKondisi;
  bool _importing = false;
  bool _exporting = false;

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
    final data = await PengungsiRepository.instance.getAll();
    final posko = {
      ...await PoskoRepository.instance.getNames(),
      ...data.map((e) => e.posko).where((n) => n.isNotEmpty),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (!mounted) return;
    setState(() {
      _semua = data;
      _daftarPosko = posko;
      _loading = false;
    });
  }

  List<String> get _pilihanKondisi => {
        _semuaKondisi,
        ...DataOptions.kondisiPengungsi,
        ..._semua.map((e) => e.kondisi).where((k) => k.isNotEmpty),
      }.toList();

  List<Pengungsi> get _hasilFilter {
    final q = _kataCari.trim().toLowerCase();
    return _semua.where((e) {
      final cocokPosko = _filterPosko == _semuaPosko || e.posko == _filterPosko;
      final cocokKondisi =
          _filterKondisi == _semuaKondisi || e.kondisi == _filterKondisi;
      final cocokCari = q.isEmpty ||
          e.nama.toLowerCase().contains(q) ||
          e.nik.contains(q);
      return cocokPosko && cocokKondisi && cocokCari;
    }).toList();
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    // Baris CSV tanpa kolom posko diisi posko yang sedang dipilih di filter.
    final result = await TransferService.importPengungsi(
      defaultPosko: _filterPosko == _semuaPosko ? '-' : _filterPosko,
    );
    if (!mounted) return;
    setState(() => _importing = false);
    await TransferResultDialog.show(
      context,
      result: result,
      aksi: 'Import',
      jenisData: 'data pengungsi',
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final result = await TransferService.exportPengungsi();
    if (!mounted) return;
    setState(() => _exporting = false);
    await TransferResultDialog.show(
      context,
      result: result,
      aksi: 'Export',
      jenisData: 'data pengungsi',
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _hasilFilter;
    final adaFilter = _kataCari.isNotEmpty ||
        _filterPosko != _semuaPosko ||
        _filterKondisi != _semuaKondisi;

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Data Pengungsi',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),

            SummaryCard(
              label: 'Total Pengungsi',
              value: _loading ? '...' : '${_semua.length} Orang',
            ),
            const SizedBox(height: 14),

            SearchField(
              hint: 'Cari nama pengungsi...',
              onChanged: (v) => setState(() => _kataCari = v),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: AppDropdownField(
                    value: _filterPosko,
                    items: [_semuaPosko, ..._daftarPosko],
                    onChanged: (v) =>
                        setState(() => _filterPosko = v ?? _semuaPosko),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppDropdownField(
                    value: _filterKondisi,
                    items: _pilihanKondisi,
                    onChanged: (v) =>
                        setState(() => _filterKondisi = v ?? _semuaKondisi),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (list.isEmpty)
              EmptyState(
                icon: Icons.groups_rounded,
                message: adaFilter
                    ? 'Tidak ada pengungsi yang cocok.'
                    : 'Belum ada data pengungsi.',
              )
            else
              for (final e in list) ...[
                AccountTile(
                  icon: Icons.groups_rounded,
                  iconColor: AppColors.accentPurple,
                  title: e.nama,
                  lines: [
                    '${e.jenisKelaminLabel} • ${e.usia} tahun',
                    '${e.kondisi} · ${e.posko}',
                  ],
                  onTap: () => PengungsiDetailSheet.show(context, e),
                ),
                const SizedBox(height: 12),
              ],
            const SizedBox(height: 4),

            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    text: 'IMPORT CSV',
                    icon: Icons.file_download_outlined,
                    height: 50,
                    isLoading: _importing,
                    onPressed: _exporting ? null : _import,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SecondaryButton(
                    text: 'EXPORT CSV',
                    icon: Icons.file_upload_outlined,
                    height: 50,
                    isLoading: _exporting,
                    onPressed: _importing ? null : _export,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
