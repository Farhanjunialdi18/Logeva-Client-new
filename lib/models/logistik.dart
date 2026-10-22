// ============================================================
// logistik.dart
// Bentuk data LOGISTIK + cara mengubahnya ke/dari database & CSV.
// ============================================================

import 'model_utils.dart';

class Logistik {
  final int? id;
  final String namaBarang;
  final String kategori;
  final int jumlah;
  final String satuan;
  final String posko;
  final DateTime dibuatPada;

  const Logistik({
    this.id,
    required this.namaBarang,
    required this.kategori,
    required this.jumlah,
    required this.satuan,
    required this.posko,
    required this.dibuatPada,
  });

  // ---------------- DATABASE ----------------

  Map<String, Object?> toMap() => {
        'id': id,
        'nama_barang': namaBarang,
        'kategori': kategori,
        'jumlah': jumlah,
        'satuan': satuan,
        'posko': posko,
        'dibuat_pada': dibuatPada.toIso8601String(),
      };

  factory Logistik.fromMap(Map<String, Object?> map) => Logistik(
        id: asInt(map['id']),
        namaBarang: asText(map['nama_barang']),
        kategori: asText(map['kategori']),
        jumlah: asInt(map['jumlah']) ?? 0,
        satuan: asText(map['satuan']),
        posko: asText(map['posko']),
        dibuatPada: asDate(map['dibuat_pada']),
      );

  // ---------------- CSV ----------------
  // PENTING: samakan nama kolom ini dengan tabel di Logeva Web.

  static const List<String> csvHeaders = [
    'nama_barang',
    'kategori',
    'jumlah',
    'satuan',
    'posko',
    'dibuat_pada',
  ];

  List<String> toCsvRow() => [
        namaBarang,
        kategori,
        '$jumlah',
        satuan,
        posko,
        dibuatPada.toIso8601String(),
      ];

  /// Baca satu baris CSV. Hasil null = baris tidak valid (dilewati).
  static Logistik? fromCsv(Map<String, String> row, String defaultPosko) {
    final nama = asText(row['nama_barang']);
    final jumlah = asInt(row['jumlah']);
    if (nama.isEmpty || jumlah == null) return null;

    final posko = asText(row['posko']);
    final kategori = asText(row['kategori']);

    return Logistik(
      namaBarang: nama,
      kategori: kategori.isEmpty ? 'Lainnya' : kategori,
      jumlah: jumlah,
      satuan: asText(row['satuan']),
      posko: posko.isEmpty ? defaultPosko : posko,
      dibuatPada: asDate(row['dibuat_pada']),
    );
  }
}
