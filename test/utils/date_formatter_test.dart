// Lama waktu sejak akun dibuat: sama dengan App\Support\LamaWaktu di website.

import 'package:flutter_application_1/utils/date_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sekarang = DateTime(2026, 11, 10, 9);
  String cek(DateTime d) => DateFormatter.lamaSejak(d, sekarang);

  test('lama waktu dalam bahasa sehari-hari', () {
    expect(cek(DateTime(2026, 11, 10, 7)), 'hari ini');
    expect(cek(DateTime(2026, 11, 9, 23)), 'kemarin');
    expect(cek(DateTime(2026, 10, 29, 10)), '12 hari lalu');
    expect(cek(DateTime(2026, 8, 1, 10)), '3 bulan lalu');
    expect(cek(DateTime(2026, 10, 1, 10)), '1 bulan lalu');
    expect(cek(DateTime(2025, 11, 1, 10)), '1 tahun lalu');
    expect(cek(DateTime(2024, 8, 5, 10)), '2 tahun 3 bulan lalu');
  });
}
