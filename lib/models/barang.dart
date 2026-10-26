// ============================================================
// barang.dart
// MASTER BARANG, mengikuti tabel `logistiks` + `kategori_logistiks`
// website. Barang dianggap sama jika kategori + nama (tanpa beda huruf
// besar/kecil) sama, seperti import Master Logistik di website.
// ============================================================

import '../utils/angka.dart';
import 'model_utils.dart';

class KategoriLogistik {
  final int id;
  final String nama;

  const KategoriLogistik({required this.id, required this.nama});

  factory KategoriLogistik.fromMap(Map<String, Object?> map) =>
      KategoriLogistik(id: asInt(map['id']) ?? 0, nama: asText(map['nama']));
}

class Barang {
  final int? id;
  final int kategoriId;
  final String kategori; // nama kategori (untuk tampilan, diisi repository)
  final String namaItem;
  final String satuan;

  /// Kebutuhan PER ORANG PER HARI dalam [satuan]. null = tidak dihitung.
  final double? kebutuhanHarian;
  final String deskripsi;
  final DateTime dibuatPada;
  final DateTime diubahPada;

  const Barang({
    this.id,
    required this.kategoriId,
    this.kategori = '',
    required this.namaItem,
    required this.satuan,
    this.kebutuhanHarian,
    this.deskripsi = '',
    required this.dibuatPada,
    required this.diubahPada,
  });

  factory Barang.baru({
    required int kategoriId,
    required String namaItem,
    required String satuan,
    double? kebutuhanHarian,
    String deskripsi = '',
  }) {
    final now = DateTime.now();
    return Barang(
      kategoriId: kategoriId,
      namaItem: namaItem,
      satuan: satuan,
      kebutuhanHarian: kebutuhanHarian,
      deskripsi: deskripsi,
      dibuatPada: now,
      diubahPada: now,
    );
  }

  /// Barang POKOK = punya kebutuhan harian (> 0), ikut dihitung di
  /// kebutuhan bantuan walaupun belum pernah masuk.
  bool get isPokok => (kebutuhanHarian ?? 0) > 0;

  /// Contoh: "0,3 kg / orang / hari"
  String get kebutuhanLabel => isPokok
      ? '${Angka.tampil(kebutuhanHarian!)} $satuan / orang / hari'
      : 'Tidak dihitung';

  /// Kunci barang yang sama: kategori + nama huruf kecil.
  static String kunciSama(int kategoriId, String nama) =>
      '$kategoriId|${nama.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase()}';

  String get kunci => kunciSama(kategoriId, namaItem);

  Barang ubahData({
    required int kategoriId,
    required String namaItem,
    required String satuan,
    required double? kebutuhanHarian,
    required String deskripsi,
  }) {
    return Barang(
      id: id,
      kategoriId: kategoriId,
      namaItem: namaItem,
      satuan: satuan,
      kebutuhanHarian: kebutuhanHarian,
      deskripsi: deskripsi,
      dibuatPada: dibuatPada,
      diubahPada: DateTime.now(),
    );
  }

  Barang denganKategori(String nama) => Barang(
        id: id,
        kategoriId: kategoriId,
        kategori: nama,
        namaItem: namaItem,
        satuan: satuan,
        kebutuhanHarian: kebutuhanHarian,
        deskripsi: deskripsi,
        dibuatPada: dibuatPada,
        diubahPada: diubahPada,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'kategori_id': kategoriId,
        'nama_item': namaItem,
        'satuan': satuan,
        'kebutuhan_harian': kebutuhanHarian,
        'deskripsi': deskripsi.isEmpty ? null : deskripsi,
        'dibuat_pada': dibuatPada.toIso8601String(),
        'diubah_pada': diubahPada.toIso8601String(),
      };

  factory Barang.fromMap(Map<String, Object?> map) {
    final dibuat = asDate(map['dibuat_pada']);
    final kebutuhan = map['kebutuhan_harian'];
    return Barang(
      id: asInt(map['id']),
      kategoriId: asInt(map['kategori_id']) ?? 0,
      namaItem: asText(map['nama_item']),
      satuan: asText(map['satuan']),
      kebutuhanHarian: kebutuhan is num
          ? kebutuhan.toDouble()
          : double.tryParse(asText(kebutuhan)),
      deskripsi: asText(map['deskripsi']),
      dibuatPada: dibuat,
      diubahPada: asDateOrNull(map['diubah_pada']) ?? dibuat,
    );
  }
}
