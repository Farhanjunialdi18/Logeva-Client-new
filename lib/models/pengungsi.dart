// ============================================================
// pengungsi.dart
// Bentuk data PENGUNGSI + cara mengubahnya ke/dari database & CSV.
// ============================================================

import 'model_utils.dart';

class Pengungsi {
  final int? id;
  final String nama;
  final String nik; // boleh kosong
  final String jenisKelamin; // 'L' atau 'P'
  final int usia;
  final String kondisi;
  final String domisili;
  final String posko;
  final DateTime dibuatPada;

  const Pengungsi({
    this.id,
    required this.nama,
    this.nik = '',
    required this.jenisKelamin,
    required this.usia,
    required this.kondisi,
    required this.domisili,
    required this.posko,
    required this.dibuatPada,
  });

  String get jenisKelaminLabel => jenisKelamin == 'P' ? 'Perempuan' : 'Laki-laki';

  // ---------------- DATABASE ----------------

  Map<String, Object?> toMap() => {
        'id': id,
        'nama': nama,
        'nik': nik,
        'jenis_kelamin': jenisKelamin,
        'usia': usia,
        'kondisi': kondisi,
        'domisili': domisili,
        'posko': posko,
        'dibuat_pada': dibuatPada.toIso8601String(),
      };

  factory Pengungsi.fromMap(Map<String, Object?> map) => Pengungsi(
        id: asInt(map['id']),
        nama: asText(map['nama']),
        nik: asText(map['nik']),
        jenisKelamin: asText(map['jenis_kelamin']) == 'P' ? 'P' : 'L',
        usia: asInt(map['usia']) ?? 0,
        kondisi: asText(map['kondisi']),
        domisili: asText(map['domisili']),
        posko: asText(map['posko']),
        dibuatPada: asDate(map['dibuat_pada']),
      );

  // ---------------- CSV ----------------
  // PENTING: samakan nama kolom ini dengan tabel di Logeva Web.

  static const List<String> csvHeaders = [
    'nama',
    'nik',
    'jenis_kelamin',
    'usia',
    'kondisi',
    'domisili',
    'posko',
    'dibuat_pada',
  ];

  List<String> toCsvRow() => [
        nama,
        nik,
        jenisKelamin,
        '$usia',
        kondisi,
        domisili,
        posko,
        dibuatPada.toIso8601String(),
      ];

  /// Baca satu baris CSV. Hasil null = baris tidak valid (dilewati).
  static Pengungsi? fromCsv(Map<String, String> row, String defaultPosko) {
    final nama = asText(row['nama']);
    final usia = asInt(row['usia']);
    if (nama.isEmpty || usia == null) return null;

    final jk = asText(row['jenis_kelamin']).toUpperCase();
    final posko = asText(row['posko']);

    return Pengungsi(
      nama: nama,
      nik: asText(row['nik']),
      jenisKelamin: jk.startsWith('P') ? 'P' : 'L',
      usia: usia,
      kondisi: asText(row['kondisi']).isEmpty ? 'Sehat' : asText(row['kondisi']),
      domisili: asText(row['domisili']),
      posko: posko.isEmpty ? defaultPosko : posko,
      dibuatPada: asDate(row['dibuat_pada']),
    );
  }
}
