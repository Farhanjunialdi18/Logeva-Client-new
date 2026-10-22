// ============================================================
// posko.dart
// Bentuk data POSKO pengungsian.
// [nama] dipakai sebagai penghubung ke data pengungsi, logistik,
// dan relawan (kolom 'posko' di tabel-tabel tersebut).
// ============================================================

import 'model_utils.dart';

class Posko {
  final int? id;
  final String nama; // contoh: 'Desa Panggarangan'
  final String alamat;
  final DateTime dibuatPada;

  const Posko({
    this.id,
    required this.nama,
    this.alamat = '',
    required this.dibuatPada,
  });

  String get label => 'Posko $nama';

  Map<String, Object?> toMap() => {
        'id': id,
        'nama': nama,
        'alamat': alamat,
        'dibuat_pada': dibuatPada.toIso8601String(),
      };

  factory Posko.fromMap(Map<String, Object?> map) => Posko(
        id: asInt(map['id']),
        nama: asText(map['nama']),
        alamat: asText(map['alamat']),
        dibuatPada: asDate(map['dibuat_pada']),
      );
}
