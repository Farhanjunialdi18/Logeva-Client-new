// ============================================================
// grafik.dart
// Grafik sederhana untuk Dashboard, digambar dengan widget Flutter
// (tanpa package tambahan, tetap 100% offline):
//  - KartuGrafik    : kartu berjudul pembungkus grafik
//  - GrafikBatang   : batang mendatar (kelompok usia, keterisian, stok)
//  - GrafikTumpuk   : satu batang bertumpuk + keterangan (L/P, sehat/sakit)
//  - GrafikDonat    : donat + keterangan (status stok)
//  - GrafikKolom    : kolom per hari, 1 atau 2 seri (tren 7 hari)
// Semua tahan teks diperbesar & layar 360 px (teks memakai ellipsis /
// FittedBox, keterangan memakai Wrap).
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Satu nilai di grafik.
class ItemGrafik {
  final String label;
  final num nilai;
  final Color warna;

  /// Teks angka di samping batang; kosong = [nilai].
  final String? teks;

  const ItemGrafik(this.label, this.nilai, this.warna, {this.teks});
}

String _angka(num n) =>
    n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(1).replaceAll('.', ',');

// ---------------- KARTU ----------------

class KartuGrafik extends StatelessWidget {
  final String judul;
  final String? keterangan;
  final Widget child;

  const KartuGrafik({
    super.key,
    required this.judul,
    this.keterangan,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(judul, style: AppTextStyles.cardTitle(p)),
          if (keterangan != null) ...[
            const SizedBox(height: 4),
            Text(keterangan!, style: AppTextStyles.small(p)),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Teks "Belum ada data" di dalam kartu grafik.
class GrafikKosong extends StatelessWidget {
  final String pesan;

  const GrafikKosong({super.key, this.pesan = 'Belum ada data.'});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(pesan, style: AppTextStyles.small(AppPalette.of(context))),
      );
}

// ---------------- KETERANGAN WARNA ----------------

class _Keterangan extends StatelessWidget {
  final List<ItemGrafik> items;
  final num total;

  const _Keterangan({required this.items, required this.total});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final i in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: i.warna, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              // Flexible: keterangan panjang turun ke baris berikutnya,
              // tidak keluar dari kartu.
              Flexible(
                child: Text(
                  '${i.label} ${i.teks ?? _angka(i.nilai)}'
                  '${total > 0 ? ' (${(i.nilai * 100 / total).round()}%)' : ''}',
                  style: AppTextStyles.small(p).copyWith(color: p.textPrimary),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ---------------- BATANG MENDATAR ----------------

class GrafikBatang extends StatelessWidget {
  final List<ItemGrafik> items;

  /// Nilai penuh batang; kosong = nilai terbesar.
  final num? maks;

  const GrafikBatang({super.key, required this.items, this.maks});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final penuh = maks ?? items.fold<num>(0, (a, i) => math.max(a, i.nilai));

    return Column(
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        i.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body(p),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      i.teks ?? _angka(i.nilai),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 10,
                    color: p.surfaceAlt,
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: penuh <= 0
                          ? 0
                          : (i.nilai / penuh).clamp(0, 1).toDouble(),
                      child: Container(color: i.warna),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ---------------- BATANG BERTUMPUK ----------------

class GrafikTumpuk extends StatelessWidget {
  final List<ItemGrafik> items;

  const GrafikTumpuk({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final total = items.fold<num>(0, (a, i) => a + i.nilai);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 18,
            child: total <= 0
                ? Container(color: p.surfaceAlt)
                : Row(
                    children: [
                      for (final i in items)
                        if (i.nilai > 0)
                          Expanded(
                            flex: math.max(1, (i.nilai * 1000 / total).round()),
                            child: Container(color: i.warna),
                          ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 10),
        _Keterangan(items: items, total: total),
      ],
    );
  }
}

// ---------------- DONAT ----------------

class GrafikDonat extends StatelessWidget {
  final List<ItemGrafik> items;

  /// Angka besar di tengah donat dan teks kecil di bawahnya.
  final String tengah;
  final String subTengah;

  const GrafikDonat({
    super.key,
    required this.items,
    required this.tengah,
    required this.subTengah,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final total = items.fold<num>(0, (a, i) => a + i.nilai);

    return Column(
      children: [
        SizedBox(
          width: 150,
          height: 150,
          child: CustomPaint(
            painter: _DonatPainter(items: items, latar: p.surfaceAlt),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tengah,
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: p.textPrimary,
                        ),
                      ),
                      Text(subTengah, style: AppTextStyles.small(p)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: _Keterangan(items: items, total: total),
        ),
      ],
    );
  }
}

class _DonatPainter extends CustomPainter {
  final List<ItemGrafik> items;
  final Color latar;

  _DonatPainter({required this.items, required this.latar});

  @override
  void paint(Canvas canvas, Size size) {
    const tebal = 18.0;
    final rect = Rect.fromLTWH(
        tebal / 2, tebal / 2, size.width - tebal, size.height - tebal);
    final cat = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = tebal;

    final total = items.fold<num>(0, (a, i) => a + i.nilai);
    if (total <= 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, cat..color = latar);
      return;
    }
    // Celah kecil antar bagian supaya warna mudah dibedakan.
    final bagian = items.where((i) => i.nilai > 0).toList();
    final celah = bagian.length > 1 ? 0.04 : 0.0;
    var mulai = -math.pi / 2;
    for (final i in bagian) {
      final sudut = math.pi * 2 * i.nilai / total;
      canvas.drawArc(rect, mulai + celah / 2,
          math.max(0.0, sudut - celah), false, cat..color = i.warna);
      mulai += sudut;
    }
  }

  @override
  bool shouldRepaint(_DonatPainter old) =>
      old.items != items || old.latar != latar;
}

// ---------------- KOLOM PER HARI ----------------

/// Satu kolom (misal satu hari) dengan 1 atau 2 nilai.
class KolomGrafik {
  final String label;
  final List<num> nilai;

  const KolomGrafik(this.label, this.nilai);
}

class GrafikKolom extends StatelessWidget {
  final List<KolomGrafik> kolom;

  /// Warna & nama tiap seri (panjangnya sama dengan [KolomGrafik.nilai]).
  final List<ItemGrafik> seri;
  final double tinggi;

  const GrafikKolom({
    super.key,
    required this.kolom,
    required this.seri,
    this.tinggi = 120,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final maks = kolom.fold<num>(
        0, (a, k) => k.nilai.fold<num>(a, (b, n) => math.max(b, n)));

    Widget batang(num n, Color warna) => Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (n > 0)
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _angka(n),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                ),
              const SizedBox(height: 2),
              Container(
                height: maks <= 0 ? 2 : math.max(2, (tinggi - 26) * n / maks),
                decoration: BoxDecoration(
                  color: n > 0 ? warna : p.border,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: tinggi,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final k in kolom)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (var i = 0; i < k.nilai.length; i++) ...[
                          if (i > 0) const SizedBox(width: 2),
                          batang(k.nilai[i], seri[i].warna),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(height: 1, color: p.border),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final k in kolom)
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(k.label, style: AppTextStyles.small(p)),
                ),
              ),
          ],
        ),
        if (seri.length > 1) ...[
          const SizedBox(height: 10),
          _Keterangan(
            items: [
              for (var i = 0; i < seri.length; i++)
                ItemGrafik(
                  seri[i].label,
                  kolom.fold<num>(0, (a, k) => a + k.nilai[i]),
                  seri[i].warna,
                ),
            ],
            total: 0,
          ),
        ],
      ],
    );
  }
}
