// ============================================================
// tanggal.dart
// TANGGAL KALENDER tanpa jam (misal tanggal lahir), disimpan sebagai
// teks 'YYYY-MM-DD' supaya tidak bergeser karena zona waktu.
// Format yang dibaca sama dengan import website
// (PengungsiImportController::tanggal): Y-m-d, d-m-Y, d/m/Y, d.m.Y,
// Y/m/d, dan 'Y-m-d H:i:s'.
// ============================================================

import 'waktu_wib.dart';

class Tanggal {
  Tanggal._();

  static String _dua(int n) => n.toString().padLeft(2, '0');

  /// Contoh: 1990-07-25
  static String format(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_dua(d.month)}-${_dua(d.day)}';

  /// Contoh: 25-07-1990 (untuk layar)
  static String tampil(DateTime d) => '${_dua(d.day)}-${_dua(d.month)}-${d.year}';

  static final List<(RegExp, bool)> _pola = [
    // (pola, true = tahun di depan)
    (RegExp(r'^(\d{4})-(\d{2})-(\d{2})$'), true),
    (RegExp(r'^(\d{2})-(\d{2})-(\d{4})$'), false),
    (RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'), false),
    (RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$'), false),
    (RegExp(r'^(\d{4})/(\d{2})/(\d{2})$'), true),
    (RegExp(r'^(\d{4})-(\d{2})-(\d{2}) \d{2}:\d{2}:\d{2}$'), true),
  ];

  /// Baca teks tanggal. null = kosong atau tidak dikenali / tidak ada
  /// di kalender (misal 31-02-2000).
  static DateTime? baca(String? teks) {
    final s = (teks ?? '').trim();
    if (s.isEmpty) return null;
    for (final (pola, tahunDulu) in _pola) {
      final m = pola.firstMatch(s);
      if (m == null) continue;
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(2)!);
      final c = int.parse(m.group(3)!);
      final (y, mo, d) = tahunDulu ? (a, b, c) : (c, b, a);
      final hasil = DateTime(y, mo, d);
      if (hasil.year != y || hasil.month != mo || hasil.day != d) return null;
      return hasil;
    }
    return null;
  }

  /// Usia dalam tahun penuh pada [hariIni] (default: hari ini WIB).
  static int usia(DateTime lahir, [DateTime? hariIni]) {
    final h = hariIni ?? WaktuWib.hariIni();
    var tahun = h.year - lahir.year;
    if (h.month < lahir.month || (h.month == lahir.month && h.day < lahir.day)) {
      tahun--;
    }
    return tahun;
  }
}
