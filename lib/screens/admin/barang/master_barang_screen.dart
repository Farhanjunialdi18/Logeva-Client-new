// ============================================================
// master_barang_screen.dart
// MASTER BARANG (tab Data -> Master Barang, khusus admin):
// daftar barang + kebutuhan harian, tambah, cari, dan import dari
// file Export Master Logistik website.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/barang_repository.dart';
import '../../../models/barang.dart';
import '../../../services/master_barang_csv.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/account_tile.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/search_field.dart';
import '../../../widgets/secondary_button.dart';
import '../../../widgets/summary_card.dart';
import '../../../widgets/transfer_result_dialog.dart';
import '../../../services/perangkat_service.dart';
import '../../../widgets/dikelola_induk_banner.dart';
import 'barang_form_screen.dart';

class MasterBarangScreen extends StatefulWidget {
  const MasterBarangScreen({super.key});

  @override
  State<MasterBarangScreen> createState() => _MasterBarangScreenState();
}

class _MasterBarangScreenState extends State<MasterBarangScreen> {
  List<Barang> _semua = [];
  bool _loading = true;
  bool _importing = false;
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
    final list = await BarangRepository.instance.getAll();
    if (!mounted) return;
    setState(() {
      _semua = list;
      _loading = false;
    });
  }

  List<Barang> get _hasilCari {
    final q = _kataCari.trim().toLowerCase();
    if (q.isEmpty) return _semua;
    return _semua
        .where((b) =>
            b.namaItem.toLowerCase().contains(q) ||
            b.kategori.toLowerCase().contains(q))
        .toList();
  }

  void _buka([Barang? barang]) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => BarangFormScreen(existing: barang)),
    );
  }

  Future<void> _import() async {
    setState(() => _importing = true);
    final result = await MasterBarangCsv.import();
    if (!mounted) return;
    setState(() => _importing = false);
    await TransferResultDialog.show(
      context,
      result: result,
      aksi: 'Import',
      jenisData: 'master barang',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final list = _hasilCari;

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Master Barang',
              subtitle: 'Daftar barang & kebutuhan per orang per hari',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),

            SummaryCard(
              label: 'Jumlah barang',
              value: _loading ? '...' : '${_semua.length} Barang',
            ),
            const SizedBox(height: 16),

            if (PerangkatService.isAnggota)
              const DikelolaIndukBanner()
            else ...[
              PrimaryButton(text: '+ TAMBAH BARANG', onPressed: _buka),
              const SizedBox(height: 12),
              SecondaryButton(
                text: 'IMPORT DARI WEBSITE (CSV)',
                icon: Icons.file_download_outlined,
                height: 50,
                isLoading: _importing,
                onPressed: _import,
              ),
              const SizedBox(height: 8),
              Text(
                'Di website, Master Logistik → "Export CSV (Aplikasi)", lalu '
                'import file itu di sini supaya nama barang dan kebutuhan '
                'harian sama dengan pusat.',
                style: AppTextStyles.small(p),
              ),
            ],
            const SizedBox(height: 14),

            SearchField(
              hint: 'Cari barang atau kategori...',
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
                icon: Icons.category_outlined,
                message: _kataCari.isEmpty
                    ? 'Belum ada barang.'
                    : 'Tidak ada barang yang cocok.',
              )
            else
              for (final b in list) ...[
                AccountTile(
                  icon: Icons.category_rounded,
                  iconColor:
                      b.isPokok ? AppColors.accentAmber : AppColors.accentBlue,
                  title: b.namaItem,
                  lines: ['${b.kategori} · ${b.satuan}', b.kebutuhanLabel],
                  // HP Anggota: hanya lihat (master dikelola di HP Induk).
                  onTap: PerangkatService.isAnggota ? () {} : () => _buka(b),
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
