// ============================================================
// admin_logistik_screen.dart
// DATA LOGISTIK versi ADMIN: seluruh posko.
// Total, cari, filter kategori & posko, daftar kartu, import/export CSV.
// Ketuk kartu -> panel detail (EDIT / HAPUS) milik halaman relawan.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/data_options.dart';
import '../../../data/data_events.dart';
import '../../../data/repositories/logistik_repository.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../models/logistik.dart';
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
import '../../relawan/logistik/logistik_detail_sheet.dart';

class AdminLogistikScreen extends StatefulWidget {
  const AdminLogistikScreen({super.key});

  @override
  State<AdminLogistikScreen> createState() => _AdminLogistikScreenState();
}

class _AdminLogistikScreenState extends State<AdminLogistikScreen> {
  static const String _semuaPosko = 'Semua Posko';

  List<Logistik> _semua = [];
  List<String> _daftarPosko = [];
  bool _loading = true;
  String _kataCari = '';
  String _filterKategori = DataOptions.semuaKategori;
  String _filterPosko = _semuaPosko;
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
    final data = await LogistikRepository.instance.getAll();
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

  List<String> get _pilihanKategori => {
        DataOptions.semuaKategori,
        ...DataOptions.kategoriLogistik,
        ..._semua.map((e) => e.kategori).where((k) => k.isNotEmpty),
      }.toList();

  List<Logistik> get _hasilFilter {
    final q = _kataCari.trim().toLowerCase();
    return _semua.where((e) {
      final cocokKategori = _filterKategori == DataOptions.semuaKategori ||
          e.kategori == _filterKategori;
      final cocokPosko = _filterPosko == _semuaPosko || e.posko == _filterPosko;
      final cocokCari = q.isEmpty || e.namaBarang.toLowerCase().contains(q);
      return cocokKategori && cocokPosko && cocokCari;
    }).toList();
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    // Baris CSV tanpa kolom posko diisi posko yang sedang dipilih di filter.
    final result = await TransferService.importLogistik(
      defaultPosko: _filterPosko == _semuaPosko ? '-' : _filterPosko,
    );
    if (!mounted) return;
    setState(() => _importing = false);
    await TransferResultDialog.show(
      context,
      result: result,
      aksi: 'Import',
      jenisData: 'data logistik',
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final result = await TransferService.exportLogistik();
    if (!mounted) return;
    setState(() => _exporting = false);
    await TransferResultDialog.show(
      context,
      result: result,
      aksi: 'Export',
      jenisData: 'data logistik',
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _hasilFilter;
    final adaFilter = _kataCari.isNotEmpty ||
        _filterPosko != _semuaPosko ||
        _filterKategori != DataOptions.semuaKategori;

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Data Logistik',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),

            SummaryCard(
              label: 'Data Logistik',
              value: _loading ? '...' : '${_semua.length} Item',
            ),
            const SizedBox(height: 14),

            SearchField(
              hint: 'Cari barang...',
              onChanged: (v) => setState(() => _kataCari = v),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: AppDropdownField(
                    value: _filterKategori,
                    items: _pilihanKategori,
                    onChanged: (v) => setState(
                      () => _filterKategori = v ?? DataOptions.semuaKategori,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppDropdownField(
                    value: _filterPosko,
                    items: [_semuaPosko, ..._daftarPosko],
                    onChanged: (v) =>
                        setState(() => _filterPosko = v ?? _semuaPosko),
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
                icon: Icons.inventory_2_rounded,
                message: adaFilter
                    ? 'Tidak ada barang yang cocok.'
                    : 'Belum ada data logistik.',
              )
            else
              for (final e in list) ...[
                AccountTile(
                  icon: Icons.inventory_2_rounded,
                  iconColor: AppColors.accentAmber,
                  title: e.namaBarang,
                  lines: [
                    e.kategori,
                    '${e.jumlah} ${e.satuan} · ${e.posko}',
                  ],
                  onTap: () => LogistikDetailSheet.show(context, e),
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
