// ============================================================
// admin_pengungsi_screen.dart
// DATA PENGUNGSI versi ADMIN: seluruh posko.
// Total, cari, filter posko & kelompok rentan, daftar kartu,
// import/export CSV (per posko, sama dengan website).
// Ketuk kartu -> panel detail (EDIT / HAPUS) milik halaman relawan.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/pengungsi_repository.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../models/pengungsi.dart';
import '../../../models/posko.dart';
import '../../../services/dobel_service.dart';
import '../../../services/perangkat_service.dart';
import '../../../services/transfer_service.dart';
import '../../../utils/app_snackbar.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/account_tile.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/filter_pengungsi.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/search_field.dart';
import '../../../widgets/secondary_button.dart';
import '../../../widgets/summary_card.dart';
import '../../../widgets/transfer_result_dialog.dart';
import '../../relawan/pengungsi/pengungsi_detail_sheet.dart';
import 'pengungsi_dobel_screen.dart';

class AdminPengungsiScreen extends StatefulWidget {
  const AdminPengungsiScreen({super.key});

  @override
  State<AdminPengungsiScreen> createState() => _AdminPengungsiScreenState();
}

class _AdminPengungsiScreenState extends State<AdminPengungsiScreen> {
  static const String _semuaPosko = 'Semua Posko';
  static const String _tanpaPosko = 'Tanpa posko';

  List<Pengungsi> _semua = [];
  int _dobel = 0; // grup kemungkinan dobel (HP Induk)
  List<Posko> _daftarPosko = [];
  bool _loading = true;
  String _kataCari = '';
  String _filterPosko = _semuaPosko;
  SaringPengungsi _saring = const SaringPengungsi();
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
    final posko = await PoskoRepository.instance.getAll()
      ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    // Orang yang sama dari beberapa HP diputuskan supervisor di HP Induk.
    final dobel = PerangkatService.isAnggota ? 0 : await DobelService.jumlah();

    if (!mounted) return;
    setState(() {
      _dobel = dobel;
      _semua = data;
      _daftarPosko = posko;
      _loading = false;
    });
  }

  /// Posko yang dipilih di filter (null = Semua Posko / Tanpa posko).
  Posko? get _poskoTerpilih {
    for (final p in _daftarPosko) {
      if (p.nama == _filterPosko) return p;
    }
    return null;
  }

  bool get _adaTanpaPosko => _semua.any((e) => e.poskoId == null);

  List<Pengungsi> get _hasilFilter {
    final q = _kataCari.trim().toLowerCase();
    final posko = _poskoTerpilih;
    return _semua.where((e) {
      final cocokPosko = switch (_filterPosko) {
        _semuaPosko => true,
        _tanpaPosko => e.poskoId == null,
        _ => e.poskoId == posko?.id,
      };
      final cocokCari = q.isEmpty ||
          e.nama.toLowerCase().contains(q) ||
          e.nomorKk.contains(q);
      return cocokPosko && _saring.cocok(e) && cocokCari;
    }).toList();
  }

  /// Import/export CSV selalu untuk SATU posko (sama dengan website).
  Posko? _cekPosko() {
    final posko = _poskoTerpilih;
    if (posko == null) {
      AppSnackbar.show(
        context,
        'Pilih satu posko di filter dulu: file CSV pengungsi berlaku '
        'untuk satu posko.',
        isError: true,
      );
    }
    return posko;
  }

  Future<void> _import() async {
    final posko = _cekPosko();
    if (posko == null) return;
    setState(() => _importing = true);
    final result = await TransferService.importPengungsi(posko);
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
    final posko = _cekPosko();
    if (posko == null) return;
    setState(() => _exporting = true);
    final result = await TransferService.exportPengungsi(posko);
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
        _saring.adaFilter;
    final diPosko = _semua.where((e) => e.masihDiPosko).length;

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
              label: 'Pengungsi di Posko',
              value: _loading ? '...' : '$diPosko Orang',
            ),
            if (_semua.length > diPosko) ...[
              const SizedBox(height: 6),
              Text(
                '${_semua.length - diPosko} orang sudah keluar posko '
                '(pulang/pindah/dirujuk).',
                style: AppTextStyles.small(AppPalette.of(context)),
              ),
            ],
            const SizedBox(height: 14),
            if (_dobel > 0) ...[
              KotakKemungkinanDobel(jumlah: _dobel),
              const SizedBox(height: 14),
            ],

            SearchField(
              hint: 'Cari nama pengungsi...',
              onChanged: (v) => setState(() => _kataCari = v),
            ),
            const SizedBox(height: 14),

            AppDropdownField(
              value: _filterPosko,
              items: [
                _semuaPosko,
                ..._daftarPosko.map((p) => p.nama),
                if (_adaTanpaPosko) _tanpaPosko,
              ],
              onChanged: (v) => setState(() => _filterPosko = v ?? _semuaPosko),
            ),
            const SizedBox(height: 14),
            FilterPengungsi(
              nilai: _saring,
              onChanged: (v) => setState(() => _saring = v),
            ),
            const SizedBox(height: 6),

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
                  title: e.perluDilengkapi ? '⚠ ${e.nama}' : e.nama,
                  lines: [
                    '${e.jenisKelamin} • ${e.usia} tahun'
                        '${e.isRentan ? ' • ${e.kelompokRentan}' : ''}',
                    '${e.kondisiKesehatan} · '
                        '${e.posko.isEmpty ? _tanpaPosko : e.posko}',
                    if (!e.masihDiPosko) '↗ ${e.labelKeberadaan}',
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
