// ============================================================
// logistik_screen.dart
// HALAMAN DATA LOGISTIK:
// total, tombol tambah, cari, filter kategori, import/export, tabel.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/data_options.dart';
import '../../../data/data_events.dart';
import '../../../data/repositories/logistik_repository.dart';
import '../../../models/logistik.dart';
import '../../../services/session_service.dart';
import '../../../services/transfer_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/app_snackbar.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/data_table_card.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/search_field.dart';
import '../../../widgets/secondary_button.dart';
import '../../../widgets/summary_card.dart';
import 'logistik_detail_sheet.dart';
import 'logistik_form_screen.dart';

class LogistikScreen extends StatefulWidget {
  final VoidCallback onBack;

  const LogistikScreen({super.key, required this.onBack});

  @override
  State<LogistikScreen> createState() => _LogistikScreenState();
}

class _LogistikScreenState extends State<LogistikScreen> {
  List<Logistik> _semua = [];
  bool _loading = true;
  String _kataCari = '';
  String _kategori = DataOptions.semuaKategori;
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
    if (!mounted) return;
    setState(() {
      _semua = data;
      _loading = false;
    });
  }

  /// Pilihan filter: "Semua Kategori" + kategori bawaan + kategori dari data.
  List<String> get _pilihanKategori {
    final set = <String>{
      DataOptions.semuaKategori,
      ...DataOptions.kategoriLogistik,
      ..._semua.map((e) => e.kategori).where((k) => k.isNotEmpty),
    };
    return set.toList();
  }

  List<Logistik> get _hasilFilter {
    final q = _kataCari.trim().toLowerCase();
    return _semua.where((e) {
      final cocokKategori =
          _kategori == DataOptions.semuaKategori || e.kategori == _kategori;
      final cocokCari = q.isEmpty || e.namaBarang.toLowerCase().contains(q);
      return cocokKategori && cocokCari;
    }).toList();
  }

  void _tambah() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LogistikFormScreen()),
    );
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    final result = await TransferService.importLogistik();
    if (!mounted) return;
    setState(() => _importing = false);
    if (result.status != TransferStatus.cancelled) {
      AppSnackbar.show(context, result.message, isError: result.isError);
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final result = await TransferService.exportLogistik();
    if (!mounted) return;
    setState(() => _exporting = false);
    if (result.status != TransferStatus.cancelled) {
      AppSnackbar.show(context, result.message, isError: result.isError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final list = _hasilFilter;

    return AppBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Data Logistik',
            subtitle: SessionService.instance.poskoLabel,
            showOfflineBadge: true,
            onBack: widget.onBack,
          ),
          const SizedBox(height: 16),

          SummaryCard(
            label: 'Total Data Logistik',
            value: _loading ? '...' : '${_semua.length} Item',
          ),
          const SizedBox(height: 16),

          PrimaryButton(text: '+ TAMBAH LOGISTIK', onPressed: _tambah),
          const SizedBox(height: 14),

          SearchField(
            hint: 'Cari barang...',
            onChanged: (v) => setState(() => _kataCari = v),
          ),
          const SizedBox(height: 12),

          AppDropdownField(
            value: _kategori,
            items: _pilihanKategori,
            onChanged: (v) =>
                setState(() => _kategori = v ?? DataOptions.semuaKategori),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  text: 'IMPORT CSV',
                  icon: Icons.file_download_outlined,
                  isLoading: _importing,
                  onPressed: _exporting ? null : _import,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  text: 'EXPORT CSV',
                  icon: Icons.file_upload_outlined,
                  isLoading: _exporting,
                  onPressed: _importing ? null : _export,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Import CSV ke data lokal · Export data lokal ke CSV',
            style: AppTextStyles.small(p),
          ),
          const SizedBox(height: 14),

          DataTableCard(
            isLoading: _loading,
            emptyMessage: _semua.isEmpty
                ? 'Belum ada data logistik.'
                : 'Tidak ada barang yang cocok.',
            columns: const [
              TableColumnSpec('Barang', flex: 26),
              TableColumnSpec('Kategori', flex: 22),
              TableColumnSpec('Jumlah', flex: 15),
              TableColumnSpec('Satuan', flex: 15),
              TableColumnSpec('Posko', flex: 22),
            ],
            rows: list
                .map((e) => [
                      e.namaBarang,
                      e.kategori,
                      '${e.jumlah}',
                      e.satuan,
                      e.posko,
                    ])
                .toList(),
            onRowTap: (i) => LogistikDetailSheet.show(context, list[i]),
          ),
          if (list.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Ketuk baris untuk melihat detail, edit, atau hapus.',
              style: AppTextStyles.small(p).copyWith(color: AppColors.success),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
