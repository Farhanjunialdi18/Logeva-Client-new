// ============================================================
// relawan.dart
// Bentuk data AKUN RELAWAN yang dibuat oleh admin.
//
// - [pin]     : PIN asli (6 digit), hanya ada di HP Induk karena admin
//               perlu melihat & memberikannya ke relawan. Kosong di HP Anggota.
// - [pinHash] : PIN yang diacak (pin_hasher.dart), dipakai LOGIN di semua HP.
// - [kode]    : kode unik akun, supaya akun bisa dikirim dari HP Induk
//               ke HP Anggota tanpa dobel. Tidak pernah berubah.
// ============================================================

import '../core/data_options.dart';
import 'model_utils.dart';
import 'posko.dart';

class Relawan {
  final int? id;
  final String kode; // kosong = dibuatkan repository saat disimpan
  final String nama;
  final String kontak; // email atau nomor HP
  final String pin; // kosong di HP Anggota
  final String pinHash;
  final int? poskoId; // null = belum ditempatkan
  final String posko; // NAMA posko (untuk tampilan, diisi repository)
  final String status; // 'Aktif' / 'Nonaktif'
  final DateTime dibuatPada;
  final DateTime diubahPada;
  final DateTime? terakhirLogin; // null = belum pernah login

  Relawan({
    this.id,
    this.kode = '',
    required this.nama,
    this.kontak = '',
    required this.pin,
    this.pinHash = '',
    this.poskoId,
    this.posko = '',
    this.status = DataOptions.statusAktif,
    required this.dibuatPada,
    DateTime? diubahPada,
    this.terakhirLogin,
  }) : diubahPada = diubahPada ?? dibuatPada;

  bool get isAktif => status == DataOptions.statusAktif;
  bool get sudahDitempatkan => poskoId != null;
  String get poskoLabel => sudahDitempatkan ? 'Posko $posko' : 'Belum ditempatkan';

  /// PIN asli hanya bisa dilihat di HP tempat akun dibuat (HP Induk).
  bool get pinTerlihat => pin.isNotEmpty;

  Relawan copyWith({
    int? id,
    String? kode,
    String? nama,
    String? kontak,
    String? pin,
    String? pinHash,
    String? posko,
    String? status,
    DateTime? diubahPada,
    DateTime? terakhirLogin,
  }) {
    return Relawan(
      id: id ?? this.id,
      kode: kode ?? this.kode,
      nama: nama ?? this.nama,
      kontak: kontak ?? this.kontak,
      pin: pin ?? this.pin,
      pinHash: pinHash ?? this.pinHash,
      poskoId: poskoId,
      posko: posko ?? this.posko,
      status: status ?? this.status,
      dibuatPada: dibuatPada,
      diubahPada: diubahPada ?? this.diubahPada,
      terakhirLogin: terakhirLogin ?? this.terakhirLogin,
    );
  }

  /// Salinan dengan penempatan posko baru ([tujuan] null = belum ditempatkan).
  Relawan tempatkan(Posko? tujuan) {
    return Relawan(
      id: id,
      kode: kode,
      nama: nama,
      kontak: kontak,
      pin: pin,
      pinHash: pinHash,
      poskoId: tujuan?.id,
      posko: tujuan?.nama ?? '',
      status: status,
      dibuatPada: dibuatPada,
      diubahPada: diubahPada,
      terakhirLogin: terakhirLogin,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'kode': kode,
        'nama': nama,
        'kontak': kontak,
        'pin': pin.isEmpty ? null : pin,
        'pin_hash': pinHash.isEmpty ? null : pinHash,
        'posko_id': poskoId,
        'posko': posko,
        'status': status,
        'dibuat_pada': dibuatPada.toIso8601String(),
        'diubah_pada': diubahPada.toIso8601String(),
        'terakhir_login': terakhirLogin?.toIso8601String(),
      };

  factory Relawan.fromMap(Map<String, Object?> map) {
    final login = asText(map['terakhir_login']);
    final dibuat = asDate(map['dibuat_pada']);
    return Relawan(
      id: asInt(map['id']),
      kode: asText(map['kode']),
      nama: asText(map['nama']),
      kontak: asText(map['kontak']),
      pin: asText(map['pin']),
      pinHash: asText(map['pin_hash']),
      poskoId: asInt(map['posko_id']),
      posko: asText(map['posko']),
      status: asText(map['status']) == DataOptions.statusNonaktif
          ? DataOptions.statusNonaktif
          : DataOptions.statusAktif,
      dibuatPada: dibuat,
      diubahPada: asDateOrNull(map['diubah_pada']) ?? dibuat,
      terakhirLogin: login.isEmpty ? null : DateTime.tryParse(login),
    );
  }
}
