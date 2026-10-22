// ============================================================
// password_hasher.dart
// Mengacak (hash) password admin sebelum disimpan ke database,
// supaya password asli tidak bisa dibaca dari file database.
//
// Cara kerja: hash = SHA-256(salt + password)
// Salt = teks acak unik per akun, disimpan di samping hash.
// Butuh package: crypto  (jalankan: flutter pub add crypto)
// ============================================================

import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

class HashedPassword {
  final String hash;
  final String salt;

  const HashedPassword({required this.hash, required this.salt});
}

class PasswordHasher {
  PasswordHasher._();

  /// Buat hash baru untuk password (dipakai saat membuat/ubah akun).
  static HashedPassword create(String password) {
    final salt = _randomSalt();
    return HashedPassword(hash: _hash(password, salt), salt: salt);
  }

  /// Cek apakah password yang diketik cocok dengan hash tersimpan.
  static bool verify(String password, {required String hash, required String salt}) {
    return _hash(password, salt) == hash;
  }

  static String _hash(String password, String salt) {
    return sha256.convert(utf8.encode('$salt$password')).toString();
  }

  static String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }
}
