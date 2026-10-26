// ============================================================
// kotak_peringatan.dart
// Peringatan di DALAM aplikasi (selalu terlihat walau izin notifikasi
// ditolak): posko hampir/sudah penuh dan stok kurang dari 7 hari.
// Memuat ulang sendiri setiap kali data berubah. Tidak ada peringatan
// = tidak tampil apa-apa.
// ============================================================

import 'package:flutter/material.dart';

import '../data/data_events.dart';
import '../services/peringatan_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class KotakPeringatan extends StatefulWidget {
  /// null = semua posko (admin); diisi = satu posko (relawan / form).
  final int? poskoId;

  /// false = hanya peringatan kapasitas (misal di form tambah pengungsi).
  final bool tampilStok;

  /// Jarak di bawah kotak (hanya dipakai kalau ada peringatan).
  final double jarakBawah;

  const KotakPeringatan({
    super.key,
    this.poskoId,
    this.tampilStok = true,
    this.jarakBawah = 16,
  });

  @override
  State<KotakPeringatan> createState() => _KotakPeringatanState();
}

class _KotakPeringatanState extends State<KotakPeringatan> {
  List<PeringatanPosko> _data = [];

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
    final data = await PeringatanService.keadaan(poskoId: widget.poskoId);
    if (!mounted) return;
    setState(() => _data = data);
  }

  @override
  Widget build(BuildContext context) {
    final baris = <Widget>[];
    for (final w in _data) {
      if (w.adaKapasitas) {
        baris.add(_Baris(
          parah: w.tingkatIsi == TingkatIsi.penuh,
          ikon: Icons.groups_rounded,
          judul: w.judulKapasitas,
          isi: w.isiKapasitas,
        ));
      }
      if (widget.tampilStok && w.adaStok) {
        baris.add(_Baris(
          parah: w.stok.any((s) => s.habis),
          ikon: Icons.inventory_2_rounded,
          judul: w.judulStok,
          isi: w.isiStok,
        ));
      }
    }
    if (baris.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: widget.jarakBawah),
      child: Column(
        children: [
          for (var i = 0; i < baris.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            baris[i],
          ],
        ],
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  final bool parah;
  final IconData ikon;
  final String judul;
  final String isi;

  const _Baris({
    required this.parah,
    required this.ikon,
    required this.judul,
    required this.isi,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final warna = parah ? AppColors.error : AppColors.sun;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warna.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: warna, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  judul,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(isi, style: AppTextStyles.small(p).copyWith(color: p.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
