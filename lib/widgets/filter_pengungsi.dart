// ============================================================
// filter_pengungsi.dart
// FILTER DAFTAR PENGUNGSI (relawan & admin):
//  - Keberadaan: Di posko (bawaan) / Sudah keluar / Semua
//  - Filter lanjutan (bisa dibuka-tutup): kelompok rentan, jenis kelamin,
//    kondisi kesehatan. Contoh: "lansia yang perlu perhatian medis".
// ============================================================

import 'package:flutter/material.dart';

import '../core/data_options.dart';
import '../models/pengungsi.dart';
import '../services/kebutuhan_service.dart';
import '../theme/app_colors.dart';
import 'app_dropdown_field.dart';
import 'segmented_choice.dart';

class SaringPengungsi {
  static const String diPosko = 'di_posko';
  static const String keluar = 'keluar';
  static const String semua = 'semua';

  static const String semuaPilihan = 'Semua';
  static const String sehat = 'Sehat';
  static const String perluPerhatian = 'Perlu perhatian medis';

  final String keberadaan;
  final String rentan;
  final String jenisKelamin;
  final String kesehatan;

  const SaringPengungsi({
    this.keberadaan = diPosko,
    this.rentan = semuaPilihan,
    this.jenisKelamin = semuaPilihan,
    this.kesehatan = semuaPilihan,
  });

  SaringPengungsi salin({
    String? keberadaan,
    String? rentan,
    String? jenisKelamin,
    String? kesehatan,
  }) =>
      SaringPengungsi(
        keberadaan: keberadaan ?? this.keberadaan,
        rentan: rentan ?? this.rentan,
        jenisKelamin: jenisKelamin ?? this.jenisKelamin,
        kesehatan: kesehatan ?? this.kesehatan,
      );

  /// Jumlah filter lanjutan yang sedang dipakai.
  int get jumlahLanjutan => [rentan, jenisKelamin, kesehatan]
      .where((v) => v != semuaPilihan)
      .length;

  bool get adaFilter => keberadaan != diPosko || jumlahLanjutan > 0;

  bool cocok(Pengungsi e) {
    final cocokKeberadaan = switch (keberadaan) {
      diPosko => e.masihDiPosko,
      keluar => !e.masihDiPosko,
      _ => true,
    };
    final cocokRentan = rentan == semuaPilihan || e.kelompokRentan == rentan;
    final cocokJk = jenisKelamin == semuaPilihan || e.jenisKelamin == jenisKelamin;
    final cocokSehat = switch (kesehatan) {
      sehat => !KebutuhanService.isSakit(e),
      perluPerhatian => KebutuhanService.isSakit(e),
      _ => true,
    };
    return cocokKeberadaan && cocokRentan && cocokJk && cocokSehat;
  }
}

class FilterPengungsi extends StatefulWidget {
  final SaringPengungsi nilai;
  final ValueChanged<SaringPengungsi> onChanged;

  const FilterPengungsi({super.key, required this.nilai, required this.onChanged});

  @override
  State<FilterPengungsi> createState() => _FilterPengungsiState();
}

class _FilterPengungsiState extends State<FilterPengungsi> {
  late bool _buka = widget.nilai.jumlahLanjutan > 0;

  @override
  Widget build(BuildContext context) {
    final n = widget.nilai;
    final lanjutan = n.jumlahLanjutan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedChoice(
          label: 'KEBERADAAN',
          options: const {
            SaringPengungsi.diPosko: 'Di posko',
            SaringPengungsi.keluar: 'Keluar',
            SaringPengungsi.semua: 'Semua',
          },
          selected: n.keberadaan,
          onChanged: (v) => widget.onChanged(n.salin(keberadaan: v)),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() => _buka = !_buka),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 8)),
            icon: Icon(
              _buka ? Icons.expand_less_rounded : Icons.tune_rounded,
              size: 18,
              color: AppColors.primary,
            ),
            label: Text(
              lanjutan > 0 ? 'Filter lanjutan ($lanjutan aktif)' : 'Filter lanjutan',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        if (_buka) ...[
          AppDropdownField(
            label: 'KELOMPOK RENTAN',
            value: n.rentan,
            items: [SaringPengungsi.semuaPilihan, ...DataOptions.kelompokRentan],
            onChanged: (v) => widget.onChanged(n.salin(rentan: v)),
          ),
          const SizedBox(height: 12),
          AppDropdownField(
            label: 'JENIS KELAMIN',
            value: n.jenisKelamin,
            items: [SaringPengungsi.semuaPilihan, ...DataOptions.jenisKelamin],
            onChanged: (v) => widget.onChanged(n.salin(jenisKelamin: v)),
          ),
          const SizedBox(height: 12),
          AppDropdownField(
            label: 'KONDISI KESEHATAN',
            value: n.kesehatan,
            items: const [
              SaringPengungsi.semuaPilihan,
              SaringPengungsi.sehat,
              SaringPengungsi.perluPerhatian,
            ],
            onChanged: (v) => widget.onChanged(n.salin(kesehatan: v)),
          ),
          if (lanjutan > 0)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => widget.onChanged(
                    SaringPengungsi(keberadaan: n.keberadaan)),
                child: const Text('Hapus filter lanjutan'),
              ),
            ),
        ],
      ],
    );
  }
}
