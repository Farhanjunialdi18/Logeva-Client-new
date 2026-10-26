// ============================================================
// waktu_wib.dart
// Format tanggal & waktu untuk PAKET DATA POSKO, selalu dalam WIB
// (UTC+7) seperti website pusat, berapa pun zona waktu di HP.
//  - Tanggal       : 2026-10-23
//  - Tanggal-waktu : 2026-10-23 14:05:09
// Untuk tampilan di layar, tetap pakai date_formatter.dart.
// ============================================================

class WaktuWib {
  WaktuWib._();

  static const Duration _selisih = Duration(hours: 7);

  /// Jam dinding WIB dari [waktu] (bagian jam/tanggalnya = WIB).
  static DateTime jamDinding(DateTime waktu) => waktu.toUtc().add(_selisih);

  /// Tanggal hari ini di WIB (jam 00:00), untuk aturan
  /// "tanggal tidak boleh setelah hari ini".
  static DateTime hariIni([DateTime? sekarang]) {
    final w = jamDinding(sekarang ?? DateTime.now());
    return DateTime(w.year, w.month, w.day);
  }

  static String _dua(int n) => n.toString().padLeft(2, '0');

  /// Contoh: 2026-10-23
  static String tanggal(DateTime waktu) {
    final w = jamDinding(waktu);
    return '${w.year.toString().padLeft(4, '0')}-${_dua(w.month)}-${_dua(w.day)}';
  }

  /// Contoh: 2026-10-23 14:05:09
  static String tanggalWaktu(DateTime waktu) {
    final w = jamDinding(waktu);
    return '${tanggal(waktu)} ${_dua(w.hour)}:${_dua(w.minute)}:${_dua(w.second)}';
  }

  static final RegExp _polaWaktu =
      RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$');

  /// Kebalikan [tanggalWaktu]: '2026-10-23 14:05:09' (WIB) -> waktu
  /// sebenarnya. null = kosong / format salah.
  static DateTime? baca(String? teks) {
    final m = _polaWaktu.firstMatch((teks ?? '').trim());
    if (m == null) return null;
    int g(int i) => int.parse(m.group(i)!);
    final utc = DateTime.utc(g(1), g(2), g(3), g(4), g(5), g(6)).subtract(_selisih);
    return utc.toLocal();
  }

  /// Dipotong ke detik (paket hanya menyimpan sampai detik), untuk
  /// membandingkan versi data dari HP lain dengan adil.
  static DateTime keDetik(DateTime waktu) {
    final u = waktu.toUtc();
    return DateTime.utc(u.year, u.month, u.day, u.hour, u.minute, u.second);
  }

  /// Untuk nama file paket. Contoh: 20261023-1405
  static String capFile(DateTime waktu) {
    final w = jamDinding(waktu);
    return '${w.year}${_dua(w.month)}${_dua(w.day)}-${_dua(w.hour)}${_dua(w.minute)}';
  }
}
