// ============================================================
// kode_unik.dart
// Membuat KODE UNIK (UUID versi 4, huruf kecil) untuk setiap posko,
// pengungsi, barang masuk, dan barang keluar.
//
// Kode dibuat SEKALI saat data dibuat dan tidak pernah berubah.
// Website pusat memakai kode ini untuk mengenali data yang sudah
// pernah diimpor, supaya paket dari banyak HP tidak membuat data dobel.
// ============================================================

import 'dart:math';

class KodeUnik {
  KodeUnik._();

  static final Random _random = Random.secure();

  /// Contoh hasil: 3f2b8c1e-9d4a-4e7b-b1c2-0a9f8e7d6c5b
  static String buat() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // versi 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // varian RFC 4122

    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static final RegExp _pola = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  /// Apakah [kode] berbentuk UUID v4 huruf kecil?
  static bool valid(String kode) => _pola.hasMatch(kode);

  /// Perintah SQL yang menghasilkan UUID v4 huruf kecil, untuk mengisi
  /// kode pada baris lama saat migrasi database (dihitung per baris).
  static const String sql = "lower(hex(randomblob(4))) || '-' || "
      "lower(hex(randomblob(2))) || '-4' || "
      "substr(lower(hex(randomblob(2))), 2) || '-' || "
      "substr('89ab', 1 + (abs(random()) % 4), 1) || "
      "substr(lower(hex(randomblob(2))), 2) || '-' || "
      "lower(hex(randomblob(6)))";
}
