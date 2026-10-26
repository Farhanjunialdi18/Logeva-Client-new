// ============================================================
// pengungsi_dobel_screen.dart
// KEMUNGKINAN PENGUNGSI DOBEL (HP Induk): orang yang sama dicatat di
// beberapa HP. Supervisor memilih data yang dipakai (GABUNGKAN) atau
// menandai BUKAN ORANG YANG SAMA. Hasilnya ikut ke HP Anggota & pusat.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../models/pengungsi.dart';
import '../../../services/dobel_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/date_formatter.dart';
import '../../../utils/tanggal.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/secondary_button.dart';

class PengungsiDobelScreen extends StatefulWidget {
  const PengungsiDobelScreen({super.key});

  @override
  State<PengungsiDobelScreen> createState() => _PengungsiDobelScreenState();
}

class _PengungsiDobelScreenState extends State<PengungsiDobelScreen> {
  List<GrupDobel> _grup = [];
  bool _loading = true;
  bool _sibuk = false;

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
    final grup = await DobelService.cari();
    if (!mounted) return;
    setState(() {
      _grup = grup;
      _loading = false;
    });
  }

  Future<void> _pakai(GrupDobel grup, Pengungsi pilihan) async {
    final yakin = await ConfirmDialog.show(
      context,
      title: 'Gabungkan data?',
      message: 'Data yang dipakai: ${pilihan.nama}, dicatat '
          '${DateFormatter.full(pilihan.dibuatPada)}'
          '${pilihan.dicatatOleh.isEmpty ? '' : ' oleh ${pilihan.dicatatOleh}'}. '
          '${grup.data.length - 1} data lainnya dihapus (ikut terhapus di HP '
          'Anggota & pusat setelah sinkron). Isian yang kosong dilengkapi dari '
          'data lainnya.',
      confirmText: 'GABUNGKAN',
    );
    if (!yakin || !mounted) return;
    setState(() => _sibuk = true);
    await DobelService.gabungkan(grup, pilihan);
    if (!mounted) return;
    setState(() => _sibuk = false);
    AppSnackbar.show(context, 'Data ${pilihan.nama} digabung. Kirim sinkron ke HP Anggota.');
  }

  Future<void> _bukanSama(GrupDobel grup) async {
    setState(() => _sibuk = true);
    await DobelService.bukanOrangYangSama(grup);
    if (!mounted) return;
    setState(() => _sibuk = false);
    AppSnackbar.show(context, 'Ditandai bukan orang yang sama.');
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Kemungkinan Dobel',
              subtitle: 'Orang yang sama dari beberapa HP',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            Text(
              'Nama dan tanggal lahirnya sama di posko yang sama, tetapi dicatat '
              'di HP berbeda. Pilih data yang paling benar, atau tandai bukan '
              'orang yang sama.',
              style: AppTextStyles.small(p),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_grup.isEmpty)
              const EmptyState(
                icon: Icons.verified_user_outlined,
                message: 'Tidak ada kemungkinan pengungsi dobel.',
              )
            else
              for (final g in _grup) ...[
                _KartuGrup(
                  grup: g,
                  sibuk: _sibuk,
                  onPakai: (pilihan) => _pakai(g, pilihan),
                  onBukanSama: () => _bukanSama(g),
                ),
                const SizedBox(height: 14),
              ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _KartuGrup extends StatelessWidget {
  final GrupDobel grup;
  final bool sibuk;
  final ValueChanged<Pengungsi> onPakai;
  final VoidCallback onBukanSama;

  const _KartuGrup({
    required this.grup,
    required this.sibuk,
    required this.onPakai,
    required this.onBukanSama,
  });

  static String _isi(String t) => t.trim().isEmpty ? '-' : t;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.sun.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(grup.nama, style: AppTextStyles.cardTitle(p)),
          const SizedBox(height: 2),
          Text(
            '${Tanggal.tampil(grup.data.first.tanggalLahir!)} · ${grup.posko} · '
            '${grup.data.length} data',
            style: AppTextStyles.small(p),
          ),
          for (final (i, d) in grup.data.indexed) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Data ${i + 1}',
                      style: AppTextStyles.small(p).copyWith(
                          color: p.textPrimary, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    'Asal: ${_isi(d.asal)} · ${d.jenisKelamin}\n'
                    'Nomor KK: ${d.nomorKk.isEmpty ? 'belum diketahui' : d.nomorKk}\n'
                    'Kondisi: ${d.kondisiKesehatan}'
                    '${d.isRentan ? ' · ${d.kelompokRentan}' : ''}'
                    '${d.riwayatPenyakit.isEmpty ? '' : ' · Riwayat: ${d.riwayatPenyakit}'}\n'
                    'Dicatat ${DateFormatter.full(d.dibuatPada)}'
                    '${d.dicatatOleh.isEmpty ? '' : ' oleh ${d.dicatatOleh}'}',
                    style: AppTextStyles.small(p),
                  ),
                  const SizedBox(height: 8),
                  SecondaryButton(
                    text: 'PAKAI DATA ${i + 1}',
                    icon: Icons.check_rounded,
                    height: 44,
                    onPressed: sibuk ? null : () => onPakai(d),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          SecondaryButton(
            text: 'BUKAN ORANG YANG SAMA',
            icon: Icons.people_outline_rounded,
            height: 44,
            onPressed: sibuk ? null : onBukanSama,
          ),
        ],
      ),
    );
  }
}

/// Kotak kuning yang bisa diketuk: "N kemungkinan pengungsi dobel".
/// Dipakai di Data Pengungsi admin & layar Sinkron (HP Induk).
class KotakKemungkinanDobel extends StatelessWidget {
  final int jumlah;

  const KotakKemungkinanDobel({super.key, required this.jumlah});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = BorderRadius.circular(14);
    return Material(
      color: AppColors.sun.withValues(alpha: 0.12),
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PengungsiDobelScreen()),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.sun.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              const Icon(Icons.people_alt_outlined, color: AppColors.sun),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$jumlah kemungkinan pengungsi dobel dari beberapa HP. '
                  'Ketuk untuk memeriksa.',
                  style: AppTextStyles.small(p).copyWith(color: p.textPrimary),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: p.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
