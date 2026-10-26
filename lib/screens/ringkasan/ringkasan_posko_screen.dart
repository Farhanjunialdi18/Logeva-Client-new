// ============================================================
// ringkasan_posko_screen.dart
// KEBUTUHAN & KOMPOSISI satu posko (relawan & admin), sama isinya
// dengan panel posko beroperasi di website:
//  - status bantuan (segera / pantau / belum / tercukupi) + alasan
//  - kebutuhan logistik: stok, cukup untuk N hari, status, perlu dikirim
//  - komposisi pengungsi: jenis kelamin, kelompok usia, kelompok rentan
//  - daftar pengungsi yang perlu perhatian medis
//  - tugas hari ini & kebutuhan harian SPHERE (posko beroperasi)
// ============================================================

import 'package:flutter/material.dart';

import '../../data/data_events.dart';
import '../../models/posko.dart';
import '../../services/kebutuhan_service.dart';
import '../../services/ringkasan_posko_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/angka.dart';
import '../../widgets/app_background.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/status_bantuan_widgets.dart';
import '../relawan/pengungsi/pengungsi_detail_sheet.dart';

class RingkasanPoskoScreen extends StatefulWidget {
  final Posko posko;

  const RingkasanPoskoScreen({super.key, required this.posko});

  @override
  State<RingkasanPoskoScreen> createState() => _RingkasanPoskoScreenState();
}

class _RingkasanPoskoScreenState extends State<RingkasanPoskoScreen> {
  RingkasanPosko? _data;

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
    final data = await RingkasanPoskoService.muat(widget.posko);
    if (!mounted) return;
    setState(() => _data = data);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final data = _data;

    return Scaffold(
      body: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Kebutuhan & Komposisi',
              subtitle: widget.posko.label,
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            if (data == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (data.posko.isBeroperasi)
                KartuStatusBantuan(ringkasan: data)
              else
                Text(
                  'Posko berstatus ${data.posko.statusLabel}. Status bantuan '
                  'hanya dihitung saat posko beroperasi (sama dengan website).',
                  style: AppTextStyles.small(p).copyWith(color: AppColors.sun),
                ),
              const SizedBox(height: 20),
              if (data.posko.isBeroperasi) ...[
                Text('TUGAS HARI INI (${data.tugas.length})',
                    style: AppTextStyles.label(p)),
                const SizedBox(height: 6),
                Text(
                  'Disusun otomatis dari data stok & pengungsi.',
                  style: AppTextStyles.small(p),
                ),
                const SizedBox(height: 10),
                DaftarTugas(tugas: data.tugas),
                const SizedBox(height: 12),
              ],
              ..._kebutuhan(context, data),
              if (data.posko.isBeroperasi) ...[
                const SizedBox(height: 20),
                _sphere(data),
              ],
              const SizedBox(height: 20),
              ..._komposisi(data),
              const SizedBox(height: 20),
              ..._medis(context, data),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ---------------- KEBUTUHAN LOGISTIK ----------------

  List<Widget> _kebutuhan(BuildContext context, RingkasanPosko data) {
    final p = AppPalette.of(context);
    final stok = data.stok;
    return [
      Text('KEBUTUHAN LOGISTIK', style: AppTextStyles.label(p)),
      const SizedBox(height: 6),
      Text(
        'Dihitung dari ${data.komposisi.total} pengungsi × kebutuhan per orang '
        'per hari. "Perlu dikirim" = supaya cukup '
        '${KebutuhanService.targetHari} hari.',
        style: AppTextStyles.small(p),
      ),
      const SizedBox(height: 10),
      if (stok.isEmpty)
        const EmptyState(
          icon: Icons.inventory_2_outlined,
          message: 'Belum ada barang di posko ini.',
        )
      else
        for (final k in stok) ...[
          _BarisKebutuhan(item: k),
          const SizedBox(height: 8),
        ],
    ];
  }

  // ---------------- SPHERE ----------------

  Widget _sphere(RingkasanPosko data) {
    final s = data.sphere;
    return InfoCard(
      title: 'KEBUTUHAN HARIAN AKTUAL (SPHERE)',
      rows: {
        'Total air': '${Angka.ribuan(s.airTotal)} L',
        'Air minum': '${Angka.ribuan(s.airMinum)} L',
        'Kalori': '${Angka.ribuan(s.kalori)} kkal',
        'Toilet minimal': '${s.toilet} unit',
      },
      note: data.komposisi.total == 0
          ? 'Belum ada pengungsi yang tercatat, jadi kebutuhan masih 0.'
          : 'Dihitung dari ${data.komposisi.total} pengungsi yang tercatat '
              'saat ini, bukan dari kapasitas. Standar per orang per hari: '
              'air 15 L (3 L untuk minum), 2.100 kkal; 1 toilet untuk 20 orang.',
    );
  }

  // ---------------- KOMPOSISI ----------------

  List<Widget> _komposisi(RingkasanPosko data) {
    final k = data.komposisi;
    return [
      InfoCard(
        title: 'KOMPOSISI PENGUNGSI',
        rows: {
          'Total': '${k.total} orang',
          if (k.kapasitas > 0) ...{
            'Kapasitas': '${k.kapasitas} orang',
            'Keterisian': '${k.persenIsi}%',
            'Sisa tempat': '${k.sisaTempat} orang',
          },
          'Laki-laki': '${k.lakiLaki}',
          'Perempuan': '${k.perempuan}',
          for (final e in k.usia.entries) e.key: '${e.value}',
        },
      ),
      const SizedBox(height: 14),
      InfoCard(
        title: 'KELOMPOK RENTAN (${k.totalRentan})',
        rows: k.rentan.isEmpty
            ? const {'-': 'Tidak ada pengungsi kelompok rentan'}
            : {for (final e in k.rentan.entries) e.key: '${e.value} orang'},
        note: data.bantuan.rentan.isEmpty
            ? null
            : data.bantuan.rentan.entries
                .map((e) => '${e.key}: ${e.value.$2}')
                .join('\n'),
      ),
    ];
  }

  // ---------------- PERHATIAN MEDIS ----------------

  List<Widget> _medis(BuildContext context, RingkasanPosko data) {
    final p = AppPalette.of(context);
    final list = data.perhatianMedis;
    return [
      Text('PERHATIAN MEDIS (${list.length})', style: AppTextStyles.label(p)),
      const SizedBox(height: 6),
      Text(
        'Pengungsi yang sakit, punya riwayat penyakit, atau termasuk kelompok '
        'rentan. Yang sakit di urutan atas.',
        style: AppTextStyles.small(p),
      ),
      const SizedBox(height: 10),
      if (list.isEmpty)
        const EmptyState(
          icon: Icons.health_and_safety_outlined,
          message: 'Tidak ada pengungsi yang perlu perhatian medis.',
        )
      else
        for (final e in list) ...[
          Material(
            color: p.surface,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => PengungsiDetailSheet.show(context, e),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${e.nama} · ${e.usia} th · ${e.jenisKelamin}',
                            style: AppTextStyles.cardTitle(p)
                                .copyWith(fontSize: 14),
                          ),
                        ),
                        if (KebutuhanService.isSakit(e))
                          const StatusChip(text: 'Sakit', color: AppColors.error),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        e.kondisiKesehatan,
                        if (e.isRentan) e.kelompokRentan,
                        if (e.riwayatPenyakit.isNotEmpty)
                          'Riwayat: ${e.riwayatPenyakit}',
                      ].join(' · '),
                      style: AppTextStyles.small(p),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
    ];
  }
}

/// Satu baris barang: nama, stok, cukup berapa hari, status, perlu dikirim.
class _BarisKebutuhan extends StatelessWidget {
  final KebutuhanBarang item;

  const _BarisKebutuhan({required this.item});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final b = item.barang;
    final warna = warnaStatusStok(item.status, p);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(b.namaItem,
                    style: AppTextStyles.cardTitle(p).copyWith(fontSize: 14)),
              ),
              StatusChip(text: StatusStok.label(item.status), color: warna),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              'Stok ${item.jumlahStok} ${b.satuan}',
              if (b.isPokok)
                'butuh ${Angka.tampil(item.kebutuhanHariIni)} ${b.satuan}/hari',
              if (item.cukupHari != null)
                item.cukupHari! >= 1
                    ? 'cukup ${KebutuhanService.teksHari(item.cukupHari)}'
                    : KebutuhanService.teksHari(item.cukupHari),
              if (!b.isPokok) 'kebutuhan harian belum diatur',
            ].join(' · '),
            style: AppTextStyles.small(p),
          ),
          if (item.perluDikirim) ...[
            const SizedBox(height: 4),
            Text(
              item.belumPernahMasuk
                  ? 'Belum pernah ada di posko · perlu dikirim '
                      '±${item.kekurangan} ${b.satuan}'
                  : 'Perlu dikirim ±${item.kekurangan} ${b.satuan}',
              style: TextStyle(
                color: item.mendesak ? warna : p.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
