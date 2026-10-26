// ============================================================
// angka.dart
// Membaca & menulis angka, aturannya SAMA dengan website
// (app/Imports/Support/NilaiImport.php):
//  - "1.250" -> 1250 ; "1.250,5" -> 1250.5 ; "2,5" -> 2.5
//  - Koordinat: koma dianggap desimal, "-6,9195" -> -6.9195
// ============================================================

class Angka {
  Angka._();

  static final RegExp _ribuan = RegExp(r'^-?\d{1,3}(\.\d{3})+$');

  /// Angka biasa (luas, kebutuhan). null = kosong atau bukan angka.
  static double? baca(String? teks) {
    var s = (teks ?? '').replaceAll(' ', '').trim();
    if (s.isEmpty) return null;

    if (s.contains('.') && s.contains(',')) {
      s = s.replaceAll('.', '').replaceAll(',', '.'); // titik = ribuan
    } else if (_ribuan.hasMatch(s)) {
      s = s.replaceAll('.', ''); // "1.250" -> 1250
    } else {
      s = s.replaceAll(',', '.'); // "2,5" -> 2.5
    }
    return double.tryParse(s);
  }

  /// Koordinat (latitude/longitude). null = kosong atau bukan angka.
  static double? bacaKoordinat(String? teks) {
    final s = (teks ?? '').replaceAll(' ', '').replaceAll(',', '.').trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  /// Untuk layar: 1050 -> "1050", 12.5 -> "12,5".
  static String tampil(double nilai) {
    if (nilai == nilai.roundToDouble()) return nilai.toInt().toString();
    return nilai.toString().replaceAll('.', ',');
  }

  /// Bilangan bulat dengan pemisah ribuan titik: 21000 -> "21.000".
  static String ribuan(int nilai) {
    final teks = nilai.abs().toString();
    final buf = StringBuffer(nilai < 0 ? '-' : '');
    for (var i = 0; i < teks.length; i++) {
      if (i > 0 && (teks.length - i) % 3 == 0) buf.write('.');
      buf.write(teks[i]);
    }
    return buf.toString();
  }

  /// Untuk file paket (desimal titik): 1050 -> "1050", 12.5 -> "12.5".
  static String ekspor(double nilai) {
    if (nilai == nilai.roundToDouble()) return nilai.toInt().toString();
    return nilai.toString();
  }
}
