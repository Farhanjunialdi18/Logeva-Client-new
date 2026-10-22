// ============================================================
// date_formatter.dart
// Format tanggal dalam Bahasa Indonesia.
// ============================================================

class DateFormatter {
  DateFormatter._();

  static const List<String> _bulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];

  static const List<String> _bulanSingkat = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static String _dua(int n) => n.toString().padLeft(2, '0');

  /// Contoh: 06 Okt 2026 • 15:42 (dipakai di Aktivitas Terbaru admin)
  static String shortFull(DateTime d) =>
      '${_dua(d.day)} ${_bulanSingkat[d.month - 1]} ${d.year} • ${_dua(d.hour)}:${_dua(d.minute)}';

  /// Contoh: 06 Oktober 2026 • 15:42
  static String full(DateTime d) =>
      '${_dua(d.day)} ${_bulan[d.month - 1]} ${d.year} • ${_dua(d.hour)}:${_dua(d.minute)}';

  /// Contoh: 06 Oktober 2026
  static String date(DateTime d) => '${_dua(d.day)} ${_bulan[d.month - 1]} ${d.year}';

  /// Untuk nama file. Contoh: 20261006_1542
  static String fileStamp(DateTime d) =>
      '${d.year}${_dua(d.month)}${_dua(d.day)}_${_dua(d.hour)}${_dua(d.minute)}';
}
