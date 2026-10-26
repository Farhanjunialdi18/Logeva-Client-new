// ============================================================
// csv_service.dart
// Mengubah data <-> teks CSV.
// - Export memakai pemisah koma (,)
// - Import menerima koma (,) maupun titik koma (;) dari Excel
// ============================================================

class CsvService {
  CsvService._();

  // ---------------- EXPORT ----------------

  static String encode(List<String> headers, List<List<String>> rows) {
    final buffer = StringBuffer();
    buffer.write(headers.map(_escape).join(','));
    for (final row in rows) {
      buffer.write('\r\n');
      buffer.write(row.map(_escape).join(','));
    }
    buffer.write('\r\n');
    return buffer.toString();
  }

  static String _escape(String value) {
    final perluKutip = value.contains(',') ||
        value.contains(';') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!perluKutip) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  // ---------------- IMPORT ----------------

  /// Hasil: daftar baris, tiap baris = {nama_kolom: isi}.
  /// Nama kolom dibuat huruf kecil & spasi diganti '_'.
  ///
  /// [cariJudul]: kalau diisi, baris judul = baris PERTAMA yang memuat
  /// semua nama kolom ini (untuk file Excel website yang punya baris judul
  /// laporan di atas tabel). Kosong = baris pertama file.
  static List<Map<String, String>> decode(
    String content, {
    List<String> cariJudul = const [],
  }) {
    var text = content;
    if (text.startsWith('﻿')) text = text.substring(1); // buang BOM

    final rows = _parse(text, _detectDelimiter(text));
    if (rows.isEmpty) return [];

    List<String> normal(List<String> row) =>
        row.map((h) => h.trim().toLowerCase().replaceAll(' ', '_')).toList();

    var mulai = 0;
    if (cariJudul.isNotEmpty) {
      mulai = rows.indexWhere((r) => cariJudul.every(normal(r).contains));
      if (mulai < 0) return [];
    }
    final headers = normal(rows[mulai]);

    final result = <Map<String, String>>[];
    for (final row in rows.skip(mulai + 1)) {
      if (row.every((cell) => cell.trim().isEmpty)) continue; // baris kosong
      final map = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        map[headers[i]] = i < row.length ? row[i].trim() : '';
      }
      result.add(map);
    }
    return result;
  }

  static String _detectDelimiter(String text) {
    final end = text.indexOf('\n');
    final firstLine = end == -1 ? text : text.substring(0, end);
    final semicolons = ';'.allMatches(firstLine).length;
    final commas = ','.allMatches(firstLine).length;
    return semicolons > commas ? ';' : ',';
  }

  static List<List<String>> _parse(String text, String delimiter) {
    final rows = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < text.length; i++) {
      final c = text[i];

      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"'); // "" di dalam kutip = satu tanda kutip
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          field.write(c);
        }
      } else if (c == '"') {
        inQuotes = true;
      } else if (c == delimiter) {
        row.add(field.toString());
        field.clear();
      } else if (c == '\n' || c == '\r') {
        if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        row.add(field.toString());
        field.clear();
        rows.add(row);
        row = <String>[];
      } else {
        field.write(c);
      }
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}
