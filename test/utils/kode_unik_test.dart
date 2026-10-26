import 'package:flutter_application_1/utils/kode_unik.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kode berbentuk UUID v4 huruf kecil', () {
    for (var i = 0; i < 200; i++) {
      final kode = KodeUnik.buat();
      expect(KodeUnik.valid(kode), isTrue, reason: kode);
    }
  });

  test('kode tidak berulang', () {
    final semua = {for (var i = 0; i < 5000; i++) KodeUnik.buat()};
    expect(semua.length, 5000);
  });

  test('valid() menolak bentuk lain', () {
    expect(KodeUnik.valid(''), isFalse);
    expect(KodeUnik.valid('3F2B8C1E-9D4A-4E7B-B1C2-0A9F8E7D6C5B'), isFalse);
    expect(KodeUnik.valid('3f2b8c1e-9d4a-1e7b-b1c2-0a9f8e7d6c5b'), isFalse);
  });
}
