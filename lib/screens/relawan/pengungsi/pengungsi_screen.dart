// ============================================================
// pengungsi_screen.dart
// HALAMAN DATA PENGUNGSI:
// total, tombol tambah, pencarian, import/export CSV, dan tabel.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/pengungsi_repository.dart';
import '../../../models/pengungsi.dart';
import '../../../services/session_service.dart';
import '../../../services/transfer_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/app_snackbar.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/data_table_card.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/search_field.dart';
import '../../../widgets/secondary_button.dart';
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
    if (!mounted) return;
    setState(() {
      _semua = data;
      _loading = false;
    });
  }

  List<Pengungsi> get _hasilCari {
    final q = _kataCari.trim().toLowerCase();
    if (q.isEmpty) return _semua;
    return _semua
        .where((e) =>
            e.nama.toLowerCase().contains(q) ||
            e.domisili.toLowerCase().contains(q) ||
            e.nik.contains(q))
        .toList();
  }

  void _tambah() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PengungsiFormScreen()),
    );
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    final result = await TransferService.importPengungsi();
    if (!mounted) return;
    setState(() => _importing = false);
    if (result.status != TransferStatus.cancelled) {
      AppSnackbar.show(context, result.message, isError: result.isError);
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final result = await TransferService.exportPengungsi();
    if (!mounted) return;
    setState(() => _exporting = false);
    if (result.status != TransferStatus.cancelled) {
      AppSnackbar.show(context, result.message, isError: result.isError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final list = _hasilCari;

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
            label: 'Total Pengungsi',
            value: _loading ? '...' : '${_semua.length} Orang',
          ),
          const SizedBox(height: 16),

          PrimaryButton(text: '+ TAMBAH PENGUNGSI', onPressed: _tambah),
          const SizedBox(height: 14),

          SearchField(
            hint: 'Cari nama pengungsi...',
            onChanged: (v) => setState(() => _kataCari = v),
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
            emptyMessage: _kataCari.isEmpty
                ? 'Belum ada data pengungsi.'
                : 'Tidak ditemukan "$_kataCari".',
            columns: const [
              TableColumnSpec('Nama', flex: 30),
              TableColumnSpec('JK', flex: 10),
              TableColumnSpec('Usia', flex: 14),
              TableColumnSpec('Kondisi', flex: 22),
              TableColumnSpec('Domisili', flex: 24),
            ],
            rows: list
                .map((e) => [
                      e.nama,
                      e.jenisKelamin,
                      '${e.usia} th',
                      e.kondisi,
                      e.domisili,
                    ])
                .toList(),
            onRowTap: (i) => PengungsiDetailSheet.show(context, list[i]),
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
