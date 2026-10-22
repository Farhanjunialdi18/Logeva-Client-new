// ============================================================
// admin.dart
// Bentuk data AKUN ADMIN + cara mengubahnya ke/dari database.
// Password TIDAK disimpan asli, hanya hash + salt (lihat password_hasher.dart).
// ============================================================

import '../core/data_options.dart';
import 'model_utils.dart';

class Admin {
  final int? id;
  final String nama;
  final String username;
  final String email;
  final String passwordHash;
  final String passwordSalt;
  final String role; // 'Super Admin' / 'Admin'
  final String status; // 'Aktif' / 'Nonaktif'
  final DateTime dibuatPada;

  const Admin({
    this.id,
    required this.nama,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.passwordSalt,
    this.role = DataOptions.roleAdmin,
    this.status = DataOptions.statusAktif,
    required this.dibuatPada,
  });

  bool get isAktif => status == DataOptions.statusAktif;
  bool get isSuperAdmin => role == DataOptions.roleSuperAdmin;

  Admin copyWith({
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
      nama: nama ?? this.nama,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      role: role ?? this.role,
      status: status ?? this.status,
      dibuatPada: dibuatPada,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'nama': nama,
        'username': username,
        'email': email,
        'password_hash': passwordHash,
        'password_salt': passwordSalt,
        'role': role,
        'status': status,
        'dibuat_pada': dibuatPada.toIso8601String(),
      };

  factory Admin.fromMap(Map<String, Object?> map) => Admin(
        id: asInt(map['id']),
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
      );
}
