// ============================================================
// admin.dart
// Bentuk data AKUN ADMIN + cara mengubahnya ke/dari database.
// Password TIDAK disimpan asli, hanya hash + salt (lihat password_hasher.dart).
// ============================================================

import '../core/data_options.dart';
import 'model_utils.dart';

class Admin {
  final int? id;
  final String kode; // kode unik akun (kosong = dibuatkan repository)
  final String nama;
  final String username;
  final String email;
  final String passwordHash;
  final String passwordSalt;
  final String role; // 'Super Admin' / 'Admin'
  final String status; // 'Aktif' / 'Nonaktif'
  final DateTime dibuatPada;
  final DateTime diubahPada;

  const Admin({
    this.id,
    this.kode = '',
    required this.nama,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.passwordSalt,
    this.role = DataOptions.roleAdmin,
    this.status = DataOptions.statusAktif,
    required this.dibuatPada,
    DateTime? diubahPada,
  }) : diubahPada = diubahPada ?? dibuatPada;

  bool get isAktif => status == DataOptions.statusAktif;
  bool get isSuperAdmin => role == DataOptions.roleSuperAdmin;

  Admin copyWith({
    String? kode,
    DateTime? diubahPada,
    String? nama,
    String? username,
    String? email,
    String? passwordHash,
    String? passwordSalt,
    String? role,
    String? status,
  }) {
    return Admin(
      id: id,
      kode: kode ?? this.kode,
      nama: nama ?? this.nama,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      role: role ?? this.role,
      status: status ?? this.status,
      dibuatPada: dibuatPada,
      diubahPada: diubahPada ?? this.diubahPada,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'kode': kode,
        'nama': nama,
        'username': username,
        'email': email,
        'password_hash': passwordHash,
        'password_salt': passwordSalt,
        'role': role,
        'status': status,
        'dibuat_pada': dibuatPada.toIso8601String(),
        'diubah_pada': diubahPada.toIso8601String(),
      };

  factory Admin.fromMap(Map<String, Object?> map) => Admin(
        id: asInt(map['id']),
        kode: asText(map['kode']),
        nama: asText(map['nama']),
        username: asText(map['username']),
        email: asText(map['email']),
        passwordHash: asText(map['password_hash']),
        passwordSalt: asText(map['password_salt']),
        role: asText(map['role']).isEmpty
            ? DataOptions.roleAdmin
            : asText(map['role']),
        status: asText(map['status']) == DataOptions.statusNonaktif
            ? DataOptions.statusNonaktif
            : DataOptions.statusAktif,
        dibuatPada: asDate(map['dibuat_pada']),
        diubahPada: asDateOrNull(map['diubah_pada']) ?? asDate(map['dibuat_pada']),
      );
}
