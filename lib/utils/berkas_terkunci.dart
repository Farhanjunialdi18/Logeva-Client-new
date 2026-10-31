// ============================================================
// berkas_terkunci.dart
// MENGUNCI FILE dengan KATA SANDI POSKO (Paket Data Posko & Cadangan),
// karena file ini dibawa keluar posko lewat flashdisk / laptop dan berisi
// data pribadi pengungsi.
//
// Hasilnya tetap file .zip (supaya Bluetooth, pemilih file, dan upload
// website menerimanya), berisi:
//   - terkunci.enc : isi asli yang dienkripsi
//   - BACA.txt     : penjelasan untuk orang yang membuka file
//
// Format terkunci.enc (website membuka dengan format yang sama,
// app/Support/BerkasTerkunci.php):
//   "LGVENC01" (8 byte) | iterasi (uint32 big-endian) | salt (16) |
//   iv (12) | ciphertext + tag (16)
// Kunci = PBKDF2-HMAC-SHA256(kata sandi, salt, iterasi) 32 byte,
// sandi = AES-256-GCM dengan AAD = "LGVENC01".
// ============================================================

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:pointycastle/export.dart';

import 'pin_hasher.dart';

class BerkasTerkunciException implements Exception {
  final String message;

  /// true = file terkunci tapi kata sandi belum diberikan.
  final bool perluKataSandi;

  const BerkasTerkunciException(this.message, {this.perluKataSandi = false});

  @override
  String toString() => message;
}

class BerkasTerkunci {
  BerkasTerkunci._();

  static const String namaIsi = 'terkunci.enc';
  static const String namaBaca = 'BACA.txt';
  static final Uint8List _magic = Uint8List.fromList(ascii.encode('LGVENC01'));

  /// Pengulangan PBKDF2: memperlambat penebakan kata sandi (± 1 detik di HP).
  static const int iterasi = 60000;

  static const int panjangMinimal = 8;

  /// Kata sandi posko yang layak: minimal 8 karakter, ada huruf & angka.
  static String? cekKataSandi(String? kataSandi) {
    final k = kataSandi ?? '';
    if (k.length < panjangMinimal) return 'Minimal $panjangMinimal karakter.';
    if (!RegExp(r'[A-Za-z]').hasMatch(k) || !RegExp(r'[0-9]').hasMatch(k)) {
      return 'Harus berisi huruf dan angka.';
    }
    return null;
  }

  static Uint8List _acak(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }

  static GCMBlockCipher _sandi(bool enkripsi, Uint8List kunci, Uint8List iv) =>
      GCMBlockCipher(AESEngine())
        ..init(enkripsi, AEADParameters(KeyParameter(kunci), 128, iv, _magic));

  /// Kunci [isi] (misal ZIP paket) dengan [kataSandi]. Hasil: file ZIP baru.
  static Uint8List kunci(List<int> isi, String kataSandi, {int iterasi = iterasi}) {
    final salt = _acak(16);
    final iv = _acak(12);
    final kunci = PinHasher.pbkdf2(utf8.encode(kataSandi), salt, iterasi);
    final ciphertext = _sandi(true, kunci, iv).process(Uint8List.fromList(isi));

    final kepala = ByteData(4)..setUint32(0, iterasi);
    final enc = BytesBuilder()
      ..add(_magic)
      ..add(kepala.buffer.asUint8List())
      ..add(salt)
      ..add(iv)
      ..add(ciphertext);
    final arsip = Archive()
      ..addFile(ArchiveFile.bytes(namaIsi, enc.toBytes()))
      ..addFile(ArchiveFile.string(
          namaBaca,
          'File LOGEVA ini dikunci dengan KATA SANDI POSKO karena berisi data '
          'pribadi pengungsi.\r\nBuka lewat aplikasi LOGEVA atau menu Import '
          'Paket Posko di website, lalu masukkan kata sandi posko.\r\n'));
    return Uint8List.fromList(ZipEncoder().encode(arsip));
  }

  /// Apakah [berkas] (ZIP) file terkunci?
  static bool terkunci(List<int> berkas) {
    try {
      return ZipDecoder().decodeBytes(berkas).findFile(namaIsi) != null;
    } catch (_) {
      return false;
    }
  }

  /// Isi asli [berkas]. File tidak terkunci dikembalikan apa adanya (file
  /// versi lama). Melempar [BerkasTerkunciException] kalau kata sandi
  /// kosong / salah.
  static Uint8List buka(List<int> berkas, String? kataSandi) {
    final Archive arsip;
    try {
      arsip = ZipDecoder().decodeBytes(berkas);
    } catch (_) {
      return Uint8List.fromList(berkas); // bukan ZIP: biar pemanggil yang menolak
    }
    final f = arsip.findFile(namaIsi);
    if (f == null) return Uint8List.fromList(berkas);
    if (kataSandi == null || kataSandi.isEmpty) {
      throw const BerkasTerkunciException(
          'File ini dikunci kata sandi posko. Masukkan kata sandinya.',
          perluKataSandi: true);
    }

    final enc = Uint8List.fromList(f.content);
    const awal = 8 + 4 + 16 + 12;
    if (enc.length < awal + 16 ||
        !_samaMagic(enc.sublist(0, 8))) {
      throw const BerkasTerkunciException('File terkunci rusak atau bukan dari LOGEVA.');
    }
    final putaran = ByteData.sublistView(enc, 8, 12).getUint32(0);
    final salt = enc.sublist(12, 28);
    final iv = enc.sublist(28, 40);
    final kunci = PinHasher.pbkdf2(utf8.encode(kataSandi), salt, putaran);
    try {
      return _sandi(false, kunci, iv).process(enc.sublist(awal));
    } on InvalidCipherTextException {
      throw const BerkasTerkunciException('Kata sandi posko salah.', perluKataSandi: true);
    }
  }

  static bool _samaMagic(List<int> b) {
    for (var i = 0; i < _magic.length; i++) {
      if (b[i] != _magic[i]) return false;
    }
    return true;
  }
}
