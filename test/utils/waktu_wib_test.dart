import 'package:flutter_application_1/utils/waktu_wib.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('waktu UTC diubah ke WIB (UTC+7)', () {
    final utc = DateTime.utc(2026, 10, 23, 7, 5, 9);
    expect(WaktuWib.tanggalWaktu(utc), '2026-10-23 14:05:09');
    expect(WaktuWib.tanggal(utc), '2026-10-23');
    expect(WaktuWib.capFile(utc), '20261023-1405');
  });

  test('melewati tengah malam ikut ganti tanggal', () {
    final utc = DateTime.utc(2026, 12, 31, 18, 30);
    expect(WaktuWib.tanggalWaktu(utc), '2027-01-01 01:30:00');
  });

  test('hasil sama berapa pun zona waktu asalnya', () {
    final lokal = DateTime(2026, 10, 23, 9, 0);
    expect(WaktuWib.tanggalWaktu(lokal),
        WaktuWib.tanggalWaktu(lokal.toUtc()));
  });
}
