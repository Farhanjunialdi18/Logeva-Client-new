// ============================================================
// relawan.dart
// Bentuk data AKUN RELAWAN yang dibuat oleh admin.
//
// PIN disimpan apa adanya (6 digit) karena admin perlu melihat
// dan memberikannya ke relawan. Hash pada PIN 6 digit juga tidak
// banyak menambah keamanan (hanya 1 juta kemungkinan).
// ============================================================

import '../core/data_options.dart';
import 'model_utils.dart';

class Relawan {
  final int? id;
  final String nama;
  final String kontak; // email atau nomor HP
  final String pin;
  final String posko; // NAMA posko, kosong = belum ditempatkan
  final String status; // 'Aktif' / 'Nonaktif'
  final DateTime dibuatPada;
  final DateTime? terakhirLogin; // null = belum pernah login

  const Relawan({
    this.id,
    required this.nama,
    this.kontak = '',
    required this.pin,
    this.posko = '',
    this.status = DataOptions.statusAktif,
    required this.dibuatPada,
    this.terakhirLogin,
  });

  bool get isAktif => status == DataOptions.statusAktif;
  bool get sudahDitempatkan => posko.isNotEmpty;
  String get poskoLabel => sudahDitempatkan ? 'Posko $posko' : 'Belum ditempatkan';

  Relawan copyWith({
    int? id,
    String? nama,
    String? kontak,
    String? pin,
    String? posko,
    String? status,
    DateTime? terakhirLogin,
  }) {
    return Relawan(
      id: id ?? this.id,
      nama: nama ?? this.nama,
      kontak: kontak ?? this.kontak,
      pin: pin ?? this.pin,
      posko: posko ?? this.posko,
      status: status ?? this.status,
      dibuatPada: dibuatPada,
      terakhirLogin: terakhirLogin ?? this.terakhirLogin,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'nama': nama,
        'kontak': kontak,
        'pin': pin,
        'posko': posko,
        'status': status,
        'dibuat_pada': dibuatPada.toIso8601String(),
        'terakhir_login': terakhirLogin?.toIso8601String(),
      };

  factory Relawan.fromMap(Map<String, Object?> map) {
    final login = asText(map['terakhir_login']);
    return Relawan(
      id: asInt(map['id']),
      nama: asText(map['nama']),
      kontak: asText(map['kontak']),
      pin: asText(map['pin']),
      posko: asText(map['posko']),
      status: asText(map['status']) == DataOptions.statusNonaktif
          ? DataOptions.statusNonaktif
          : DataOptions.statusAktif,
      dibuatPada: asDate(map['dibuat_pada']),
      terakhirLogin: login.isEmpty ? null : DateTime.tryParse(login),
    );
  }
}
