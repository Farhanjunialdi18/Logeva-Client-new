// ============================================================
// kondisi_kesehatan.dart
// KONDISI KESEHATAN = PILIHAN + keterangan bebas (sama dengan website,
// App\Support\KondisiKesehatan). Disimpan di satu kolom yang sama
// (kondisi_kesehatan) supaya format database & paket tidak berubah:
//   "Sehat"                      (kosong juga = Sehat)
//   "Sakit ringan - Demam"
//   "Sakit berat"
//   "Perlu rujukan - Patah tulang"
// Teks lama yang bukan pilihan (misal "Demam") tetap diterima; di form
// pilihannya dikosongkan dan teksnya jadi keterangan.
// ============================================================

import '../core/data_options.dart';

class KondisiKesehatan {
  KondisiKesehatan._();

  static const String sehat = DataOptions.kondisiSehat;
  static const String sakitRingan = 'Sakit ringan';
  static const String sakitBerat = 'Sakit berat';
  static const String perluRujukan = 'Perlu rujukan';

  static const List<String> pilihan = [sehat, sakitRingan, sakitBerat, perluRujukan];

  static const String pemisah = ' - ';

  /// Gabungkan pilihan + keterangan jadi isi kolom kondisi_kesehatan.
  static String gabung(String pilihan, String keterangan) {
    final ket = keterangan.trim().replaceAll(RegExp(r'\s+'), ' ');
    return ket.isEmpty ? pilihan : '$pilihan$pemisah$ket';
  }

  /// Pisahkan isi kolom. [pilihan] null = teks lama yang bukan pilihan.
  static ({String? pilihan, String keterangan}) pisah(String teks) {
    final t = teks.trim();
    if (t.isEmpty) return (pilihan: sehat, keterangan: '');
    final kecil = t.toLowerCase();
    for (final p in pilihan) {
      final pk = p.toLowerCase();
      if (kecil == pk) return (pilihan: p, keterangan: '');
      for (final sep in [pemisah, ':', ',', '(']) {
        if (kecil.startsWith('$pk${sep.trim()}') || kecil.startsWith('$pk$sep')) {
          final sisa = t.substring(p.length).trim();
          return (
            pilihan: p,
            keterangan: sisa.replaceFirst(RegExp(r'^[-:,(]\s*'), '').replaceFirst(RegExp(r'\)$'), '').trim(),
          );
        }
      }
    }
    if (kecil == 'baik' || kecil == '-') return (pilihan: sehat, keterangan: '');
    return (pilihan: null, keterangan: t);
  }

  /// Tingkat keparahan untuk urutan "perhatian medis": Perlu rujukan 3,
  /// Sakit berat 2, Sakit ringan / teks lama 1, Sehat 0.
  static int tingkat(String teks) => switch (pisah(teks).pilihan) {
        sehat => 0,
        perluRujukan => 3,
        sakitBerat => 2,
        _ => 1,
      };

  /// Rapikan teks (huruf besar/kecil pilihan diseragamkan, "baik" = Sehat).
  /// Teks lama yang bukan pilihan dibiarkan.
  static String rapikan(String teks) {
    final p = pisah(teks);
    return p.pilihan == null ? p.keterangan : gabung(p.pilihan!, p.keterangan);
  }
}
