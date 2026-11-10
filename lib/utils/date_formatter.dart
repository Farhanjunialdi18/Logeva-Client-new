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

  /// Lama waktu sejak [d] (per tanggal kalender): "hari ini", "kemarin",
  /// "12 hari lalu", "3 bulan lalu", "2 tahun 3 bulan lalu".
  /// Sama dengan App\Support\LamaWaktu::sejak() di website.
  static String lamaSejak(DateTime d, [DateTime? sekarang]) {
    final n = sekarang ?? DateTime.now();
    final dari = DateTime(d.year, d.month, d.day);
    final sampai = DateTime(n.year, n.month, n.day);
    final hari = sampai.difference(dari).inDays;
    if (hari <= 0) return 'hari ini';
    if (hari == 1) return 'kemarin';
    if (hari < 30) return '$hari hari lalu';

    var bulan = (sampai.year - dari.year) * 12 + sampai.month - dari.month;
    if (sampai.day < dari.day) bulan--;
    if (bulan < 12) return '${bulan < 1 ? 1 : bulan} bulan lalu';
    final tahun = bulan ~/ 12;
    final sisa = bulan % 12;
    return sisa == 0 ? '$tahun tahun lalu' : '$tahun tahun $sisa bulan lalu';
  }

  /// Untuk nama file. Contoh: 20261006_1542
  static String fileStamp(DateTime d) =>
      '${d.year}${_dua(d.month)}${_dua(d.day)}_${_dua(d.hour)}${_dua(d.minute)}';
}
