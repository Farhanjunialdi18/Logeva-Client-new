// ============================================================
// logistik_posko_panel.dart
// ISI HALAMAN LOGISTIK untuk satu posko (dipakai relawan & admin):
// ringkasan, tombol BARANG MASUK / KELUAR, tabel stok, dan catatan
// terbaru. Stok dihitung dari catatan; catatan tidak bisa diubah.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/data_options.dart';
import '../../../data/data_events.dart';
import '../../../data/repositories/barang_repository.dart';
import '../../../data/repositories/logistik_repository.dart';
import '../../../data/repositories/pengungsi_repository.dart';
import '../../../models/barang.dart';
import '../../../models/catatan_logistik.dart';
import '../../../models/posko.dart';
import '../../../services/kebutuhan_service.dart';
import '../../../services/perangkat_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/date_formatter.dart';
import '../../../utils/tanggal.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/data_table_card.dart';
import '../../../widgets/detail_sheet.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/search_field.dart';
import '../../../widgets/secondary_button.dart';
import '../../../widgets/summary_card.dart';
import 'barang_keluar_form_screen.dart';
import 'barang_masuk_form_screen.dart';

class LogistikPoskoPanel extends StatefulWidget {
  final Posko posko;

  const LogistikPoskoPanel({super.key, required this.posko});

  @override
  State<LogistikPoskoPanel> createState() => _LogistikPoskoPanelState();
}

class _LogistikPoskoPanelState extends State<LogistikPoskoPanel> {
  static const int _jumlahCatatanAwal = 10;

  List<KebutuhanBarang> _stok = [];
  List<CatatanLogistik> _catatan = [];
  Map<int, Barang> _barang = {};
  Map<int?, DateTime?> _terakhir = {};
  bool _loading = true;
  bool _semuaCatatan = false;
  String _kataCari = '';
  String _kategori = DataOptions.semuaKategori;

  @override
  void initState() {
    super.initState();
    _load();
    DataEvents.instance.addListener(_load);
  }

  @override
  void didUpdateWidget(LogistikPoskoPanel old) {
    super.didUpdateWidget(old);
    if (old.posko.id != widget.posko.id) _load();
  }

  @override
  void dispose() {
    DataEvents.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.posko.id;
    // Barang pokok ikut walau stok 0, supaya kekurangan terlihat.
    final mentah =
        await LogistikRepository.instance.getStok(id, termasukPokok: true);
    final stok = KebutuhanService.hitung(
      mentah,
      await PengungsiRepository.instance.count(poskoId: id),
    );
    final terakhir = {for (final s in mentah) s.barang.id: s.terakhirDiperbarui};
    final catatan = await LogistikRepository.instance.getCatatan(poskoId: id);
    final barang = {
      for (final b in await BarangRepository.instance.getAll()) b.id!: b,
    };
    if (!mounted) return;
    setState(() {
      _stok = stok;
      _terakhir = terakhir;
      _catatan = catatan;
      _barang = barang;
      _loading = false;
    });
  }

  List<KebutuhanBarang> get _stokFilter {
    final q = _kataCari.trim().toLowerCase();
    return _stok.where((s) {
      final cocokKategori = _kategori == DataOptions.semuaKategori ||
          s.barang.kategori == _kategori;
      final cocokCari =
          q.isEmpty || s.barang.namaItem.toLowerCase().contains(q);
      return cocokKategori && cocokCari;
    }).toList();
  }

  void _buka(Widget halaman) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => halaman));
  }

  void _detailStok(KebutuhanBarang s) {
    final terakhir = _terakhir[s.barang.id];
    DetailSheet.show(
      context,
      title: s.barang.namaItem,
      rows: {
        'Kategori': s.barang.kategori,
        'Stok': '${s.jumlahStok} ${s.barang.satuan}',
        'Kebutuhan': s.barang.kebutuhanLabel,
        'Status': StatusStok.label(s.status),
        if (s.cukupHari != null)
          'Cukup untuk': KebutuhanService.teksHari(s.cukupHari),
        if (s.perluDikirim)
          'Perlu dikirim': '±${s.kekurangan} ${s.barang.satuan} '
              '(${KebutuhanService.targetHari} hari)',
        'Diperbarui':
            terakhir == null ? 'Belum pernah ada' : DateFormatter.full(terakhir),
      },
      catatan: 'Stok hanya berubah lewat catatan barang masuk dan keluar.',
    );
  }

  void _detailCatatan(CatatanLogistik c) {
    final b = _barang[c.barangId];
    final satuan = b?.satuan ?? '';
    DetailSheet.show(
      context,
      title: '${c.isMasuk ? 'Masuk' : 'Keluar'}: ${b?.namaItem ?? '-'}',
      rows: {
        'Jumlah': '${c.isMasuk ? '+' : '−'}${c.jumlah} $satuan',
        'Tanggal': Tanggal.tampil(c.tanggal),
        if (c is BarangMasuk) 'Sumber': c.sumberBantuan,
        if (c is BarangKeluar) 'Untuk': c.tujuanLabel,
        if (c is BarangKeluar && c.penerima.isNotEmpty) 'Penerima': c.penerima,
        if (c.keterangan.isNotEmpty) 'Keterangan': c.keterangan,
        'Dicatat': [
          DateFormatter.full(c.dibuatPada),
          if (c.dicatatOleh.isNotEmpty) 'oleh ${c.dicatatOleh}',
        ].join(' '),
      },
      catatan: 'Catatan tidak bisa diubah atau dihapus. Kalau ada kesalahan, '
          'buat catatan baru sebagai koreksi.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final stok = _stokFilter;
    final tersedia = _stok.where((s) => s.jumlahStok > 0).length;
    final minus = _stok.where((s) => s.jumlahStok < 0).toList();
    final catatan =
        _semuaCatatan ? _catatan : _catatan.take(_jumlahCatatanAwal).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (minus.isNotEmpty) ...[
          _PeringatanMinus(minus: minus),
          const SizedBox(height: 16),
        ],
        SummaryCard(
          label: 'Jenis barang tersedia',
          value: _loading ? '...' : '$tersedia Barang',
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: PrimaryButton(
                text: '+ MASUK',
                onPressed: () =>
                    _buka(BarangMasukFormScreen(posko: widget.posko)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SecondaryButton(
                text: '− KELUAR',
                height: 54,
                onPressed: () =>
                    _buka(BarangKeluarFormScreen(posko: widget.posko)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Text('STOK', style: AppTextStyles.label(p)),
        const SizedBox(height: 10),
        SearchField(
          hint: 'Cari barang...',
          onChanged: (v) => setState(() => _kataCari = v),
        ),
        const SizedBox(height: 12),
        AppDropdownField(
          value: _kategori,
          items: [DataOptions.semuaKategori, ...DataOptions.kategoriLogistik],
          onChanged: (v) =>
              setState(() => _kategori = v ?? DataOptions.semuaKategori),
        ),
        const SizedBox(height: 12),
        DataTableCard(
          isLoading: _loading,
          emptyMessage: _stok.isEmpty
              ? 'Belum ada barang. Tekan "+ MASUK" untuk mencatat bantuan.'
              : 'Tidak ada barang yang cocok.',
          columns: const [
            TableColumnSpec('Barang', flex: 30),
            TableColumnSpec('Stok', flex: 22),
            TableColumnSpec('Cukup', flex: 24),
            TableColumnSpec('Status', flex: 24),
          ],
          rows: stok
              .map((s) => [
                    s.barang.namaItem,
                    '${s.jumlahStok} ${s.barang.satuan}',
                    KebutuhanService.teksHari(s.cukupHari),
                    StatusStok.label(s.status),
                  ])
              .toList(),
          onRowTap: (i) => _detailStok(stok[i]),
        ),
        const SizedBox(height: 20),

        Text('CATATAN TERBARU', style: AppTextStyles.label(p)),
        const SizedBox(height: 10),
        DataTableCard(
          isLoading: _loading,
          emptyMessage: 'Belum ada catatan barang masuk/keluar.',
          columns: const [
            TableColumnSpec('Tanggal', flex: 24),
            TableColumnSpec('Barang', flex: 28),
            TableColumnSpec('Jumlah', flex: 18),
            TableColumnSpec('Ket.', flex: 30),
          ],
          rows: catatan
              .map((c) => [
                    Tanggal.tampil(c.tanggal),
                    _barang[c.barangId]?.namaItem ?? '-',
                    '${c.isMasuk ? '+' : '−'}${c.jumlah}',
                    c.ringkasan,
                  ])
              .toList(),
          onRowTap: (i) => _detailCatatan(catatan[i]),
        ),
        if (_catatan.length > _jumlahCatatanAwal) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => setState(() => _semuaCatatan = !_semuaCatatan),
            child: Text(
              _semuaCatatan
                  ? 'Tampilkan lebih sedikit'
                  : 'Tampilkan semua (${_catatan.length} catatan)',
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ],
    );
  }
}

/// Kotak merah: barang yang stoknya minus (keluar > masuk yang tercatat).
class _PeringatanMinus extends StatelessWidget {
  final List<KebutuhanBarang> minus;

  const _PeringatanMinus({required this.minus});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Stok minus: ${minus.map(KebutuhanService.teksStokMinus).join(', ')}. '
              '${PerangkatService.isAnggota ? 'Mungkin barang masuknya dicatat di HP '
                  'lain. Sinkron dengan HP Induk.' : 'Barang keluar lebih banyak dari '
                  'barang masuk yang tercatat. Pastikan semua HP Anggota sudah '
                  'sinkron, lalu catat koreksi bila perlu.'}',
              style: AppTextStyles.small(p).copyWith(color: p.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
