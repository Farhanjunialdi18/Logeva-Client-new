// ============================================================
// pin_hasher.dart
// Mengacak PIN relawan (PBKDF2-HMAC-SHA256) untuk LOGIN.
//
// Kenapa PBKDF2, bukan SHA-256 biasa seperti password admin?
// PIN hanya 6 digit (1 juta kemungkinan). PBKDF2 mengulang hash ribuan
// kali sehingga menebak semua PIN dari file yang bocor jadi LAMBAT
// (berjam-jam), bukan instan. Ini memperlambat, bukan mustahil dibongkar.
//
// Salt = satu teks acak per HP Induk (disimpan di pengaturan, ikut ke
// HP Anggota lewat File Penyiapan), sehingga login cukup menghitung
// SATU hash lalu mencocokkannya dengan semua relawan.
// ============================================================

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class PinHasher {
  PinHasher._();

  /// Jumlah pengulangan. Di HP sekitar 0,1–0,3 detik per hash.
  static const int iterasi = 20000;

  /// Hash PIN dengan [salt]. Hasil: teks base64.
  static String hash(String pin, String salt) =>
      base64Url.encode(pbkdf2(utf8.encode(pin), utf8.encode(salt), iterasi));

  /// Salt acak baru (dibuat sekali per HP Induk).
  static String saltBaru() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(16, (_) => random.nextInt(256)));
  }

  /// PBKDF2-HMAC-SHA256 dengan panjang hasil 32 byte (satu blok, RFC 8018).
  static Uint8List pbkdf2(List<int> password, List<int> salt, int iterasi) {
    final hmac = Hmac(sha256, password);
    // U1 = HMAC(P, S || INT(1))
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final hasil = Uint8List.fromList(u);
    for (var i = 1; i < iterasi; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < hasil.length; j++) {
        hasil[j] ^= u[j];
      }
    }
    return hasil;
  }
}
