// Mengunci & membuka file dengan kata sandi posko (AES-256-GCM + PBKDF2).

import 'dart:convert';

import 'package:flutter_application_1/utils/berkas_terkunci.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final isi = utf8.encode('isi paket rahasia: Siti Aminah, 1958-03-12');

  test('dikunci lalu dibuka dengan kata sandi yang benar', () {
    final f = BerkasTerkunci.kunci(isi, 'posko2026', iterasi: 1000);
    expect(BerkasTerkunci.terkunci(f), isTrue);
    expect(utf8.decode(f, allowMalformed: true), isNot(contains('Siti')),
        reason: 'isi tidak terbaca tanpa kata sandi');
    expect(BerkasTerkunci.buka(f, 'posko2026'), isi);
  });

  test('kata sandi salah / kosong ditolak', () {
    final f = BerkasTerkunci.kunci(isi, 'posko2026', iterasi: 1000);
    expect(() => BerkasTerkunci.buka(f, 'posko2027'),
        throwsA(isA<BerkasTerkunciException>().having((e) => e.message, 'pesan', 'Kata sandi posko salah.')));
    expect(() => BerkasTerkunci.buka(f, null),
        throwsA(isA<BerkasTerkunciException>().having((e) => e.perluKataSandi, 'perlu', isTrue)));
  });

  test('file lama (tidak terkunci) dikembalikan apa adanya', () {
    expect(BerkasTerkunci.terkunci(isi), isFalse);
    expect(BerkasTerkunci.buka(isi, null), isi);
  });

  test('aturan kata sandi', () {
    expect(BerkasTerkunci.cekKataSandi('pendek1'), isNotNull);
    expect(BerkasTerkunci.cekKataSandi('tanpaangka'), isNotNull);
    expect(BerkasTerkunci.cekKataSandi('posko2026'), isNull);
  });
}
