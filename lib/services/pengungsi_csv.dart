// ============================================================
// pengungsi_csv.dart
// Format CSV PENGUNGSI = template "Import Pengungsi" website (§5):
// judul kolom, urutan, pilihan nilai, dan aturan validasinya sama
// (PengungsiImportController), supaya file bisa diimpor bolak-balik.
//
// Nomor KK boleh kosong (dokumen bisa hilang saat bencana). Tanggal
// lahir ATAU usia wajib diisi salah satu (sama dengan website).
// ============================================================

import '../core/data_options.dart';
import '../models/pengungsi.dart';
import '../utils/kondisi_kesehatan.dart';
import '../utils/tanggal.dart';
import '../utils/validators.dart';
import '../utils/waktu_wib.dart';

/// Hasil membaca satu baris CSV.
class BarisPengungsi {
  final String nama;
  final String asal;
  final DateTime? tanggalLahir;

  /// Usia kalau tanggal lahir kosong (pilih salah satu).
  final int? usia;
  final String jenisKelamin;

  /// null = kolom kosong (data lama tidak diubah saat memperbarui).
  final String? nomorKk;
  final String? kondisiKesehatan;
  final String? kelompokRentan;
  final String? riwayatPenyakit;

  /// Pesan kesalahan; kosong = baris valid.
  final List<String> error;

  const BarisPengungsi({
    required this.nama,
    required this.asal,
    required this.tanggalLahir,
    this.usia,
    required this.jenisKelamin,
    required this.nomorKk,
    required this.kondisiKesehatan,
    required this.kelompokRentan,
    required this.riwayatPenyakit,
    required this.error,
  });

  bool get valid => error.isEmpty;

  /// Kunci orang yang sama: nama (huruf kecil) + tanggal lahir, atau
  /// nama + usia kalau tanggal lahir kosong.
  String? get kunci => nama.isEmpty
      ? null
      : tanggalLahir != null
          ? Pengungsi.kunciSama(nama, tanggalLahir!)
          : usia != null
              ? Pengungsi.kunciUsia(nama, usia!)
              : null;

  /// Jadi pengungsi baru di posko [poskoId].
  Pengungsi keBaru(int poskoId, String dicatatOleh) => Pengungsi.baru(
        poskoId: poskoId,
        nama: nama,
        asal: asal,
        tanggalLahir: tanggalLahir,
        usia: usia,
        jenisKelamin: jenisKelamin,
        nomorKk: nomorKk ?? '',
        kondisiKesehatan: kondisiKesehatan ?? '',
        kelompokRentan: kelompokRentan ?? DataOptions.bukanRentan,
        riwayatPenyakit: riwayatPenyakit ?? '',
        dicatatOleh: dicatatOleh,
      );

  /// Perbarui pengungsi [lama]; kolom opsional yang kosong tidak diubah.
  Pengungsi perbarui(Pengungsi lama) => lama.ubahData(
        poskoId: lama.poskoId,
        nama: nama,
        asal: asal,
        tanggalLahir: tanggalLahir,
        usia: usia,
        jenisKelamin: jenisKelamin,
        nomorKk: nomorKk ?? lama.nomorKk,
        kondisiKesehatan: kondisiKesehatan ?? lama.kondisiKesehatan,
        kelompokRentan: kelompokRentan ?? lama.kelompokRentan,
        riwayatPenyakit: riwayatPenyakit ?? lama.riwayatPenyakit,
      );
}

class PengungsiCsv {
  PengungsiCsv._();

  static const List<String> headers = [
    'Nama',
    'Asal',
    'Tanggal Lahir',
    'Nomor KK',
    'Usia',
    'Jenis Kelamin',
    'Kondisi Kesehatan',
    'Kelompok Rentan',
    'Riwayat Penyakit',
  ];

  static List<String> toRow(Pengungsi e) => [
        e.nama,
        e.asal,
        e.tanggalLahir == null ? '' : Tanggal.format(e.tanggalLahir!),
        e.nomorKk,
        '${e.usia}',
        e.jenisKelamin,
        e.kondisiKesehatan,
        e.kelompokRentan,
        e.riwayatPenyakit,
      ];

  // ---------------- BACA ----------------
  // Nama kolom dari CsvService.decode sudah huruf kecil & spasi -> '_'.
  // Alias sama dengan website, ditambah 'domisili' (format aplikasi lama).

  static const Map<String, List<String>> _alias = {
    'nama': ['nama', 'nama_pengungsi', 'nama_lengkap'],
    'asal': ['asal', 'alamat_asal', 'asal_desa', 'domisili'],
    'tanggal_lahir': ['tanggal_lahir', 'tgl_lahir'],
    'nomor_kk': ['nomor_kk', 'no_kk', 'nomor_kartu_keluarga', 'kk'],
    'usia': ['usia', 'umur'],
    'jenis_kelamin': ['jenis_kelamin', 'jk', 'kelamin'],
    'kondisi_kesehatan': ['kondisi_kesehatan', 'kondisi'],
    'kelompok_rentan': ['kelompok_rentan', 'rentan'],
    'riwayat_penyakit': ['riwayat_penyakit', 'penyakit'],
  };

  static const Map<String, List<String>> _jenisKelamin = {
    DataOptions.lakiLaki: [
      'laki-laki', 'laki laki', 'lakilaki', 'laki', 'l', 'lk', 'pria', 'male',
    ],
    DataOptions.perempuan: ['perempuan', 'p', 'pr', 'wanita', 'female'],
  };

  static String _ambil(Map<String, String> row, String kolom) {
    for (final nama in _alias[kolom]!) {
      final v = row[nama];
      if (v != null && v.trim().isNotEmpty) return v;
    }
    return '';
  }

  static String? _kondisi(String? teks) =>
      teks == null ? null : KondisiKesehatan.rapikan(teks);

  /// Teks dirapikan: spasi ganda jadi satu, null kalau kosong.
  static String? _teks(String v) {
    final t = v.trim().replaceAll(RegExp(r'\s+'), ' ');
    return t.isEmpty ? null : t;
  }

  /// Baca & periksa satu baris (aturan sama dengan import website).
  static BarisPengungsi baca(Map<String, String> row, {DateTime? hariIni}) {
    final error = <String>[];
    final h = hariIni ?? WaktuWib.hariIni();

    final nama = _teks(_ambil(row, 'nama')) ?? '';
    if (nama.isEmpty) error.add('Nama kosong');
    final asal = _teks(_ambil(row, 'asal')) ?? '';
    if (asal.isEmpty) error.add('Asal kosong');

    // --- tanggal lahir & usia ---
    final teksLahir = _ambil(row, 'tanggal_lahir').trim();
    final lahir = Tanggal.baca(teksLahir);
    DateTime? lahirValid;
    if (teksLahir.isEmpty) {
      // Boleh kosong kalau usia diisi (dicek di bawah).
    } else if (lahir == null) {
      error.add('Tanggal lahir tidak dikenali, gunakan format '
          'TAHUN-BULAN-TANGGAL (contoh: 1990-07-25)');
    } else if (lahir.isAfter(h) || lahir.year < 1900) {
      error.add('Tanggal lahir tidak masuk akal (${Tanggal.tampil(lahir)})');
    } else {
      lahirValid = lahir;
    }

    final teksUsia = _ambil(row, 'usia').trim();
    int? usiaValid;
    if (teksUsia.isEmpty) {
      if (teksLahir.isEmpty) error.add('Isi tanggal lahir atau usia');
    } else {
      final usia = int.tryParse(teksUsia);
      if (usia != null && usia >= 0 && usia <= 130) usiaValid = usia;
      if (usia == null || usia < 0 || usia > 130) {
        error.add('Usia harus bilangan bulat 0–130');
      } else if (lahirValid != null) {
        final hitung = Tanggal.usia(lahirValid, h);
        if ((usia - hitung).abs() > 1) {
          error.add('Usia ($usia) tidak sesuai tanggal lahir '
              '(seharusnya $hitung tahun)');
        }
      }
    }

    // --- nomor KK (boleh kosong) ---
    final teksKk = _ambil(row, 'nomor_kk');
    String? kk;
    if (teksKk.trim().isNotEmpty) {
      if (teksKk.toLowerCase().contains('e+')) {
        error.add('Nomor KK rusak karena dibaca Excel sebagai angka (digit '
            'terakhir hilang). Format kolom Nomor KK sebagai Teks lalu ketik ulang');
      } else if (Validators.nomorKkOptional(teksKk) != null) {
        error.add('Nomor KK harus 16 digit angka (terbaca: ${teksKk.trim()})');
      } else {
        kk = Validators.bersihkanKk(teksKk);
      }
    }

    // --- pilihan tetap ---
    final teksJk = _ambil(row, 'jenis_kelamin');
    final jk = _pilih(teksJk, _jenisKelamin);
    if (teksJk.trim().isEmpty) {
      error.add('Jenis kelamin kosong');
    } else if (jk == null) {
      error.add('Jenis kelamin "${teksJk.trim()}" tidak dikenali '
          '(isi Laki-laki atau Perempuan)');
    }

    final teksRentan = _teks(_ambil(row, 'kelompok_rentan'));
    String? rentan;
    if (teksRentan != null) {
      rentan = _pilih(teksRentan, {
        for (final r in DataOptions.kelompokRentan) r: [r.toLowerCase()],
        DataOptions.bukanRentan: ['tidak', '-', 'tidak ada', 'bukan'],
      });
      if (rentan == null) {
        error.add('Kelompok rentan "$teksRentan" tidak dikenali (pilihan: '
            '${DataOptions.kelompokRentan.join(', ')})');
      }
    }

    return BarisPengungsi(
      nama: nama,
      asal: asal,
      tanggalLahir: lahirValid,
      usia: lahirValid == null ? usiaValid : null,
      jenisKelamin: jk ?? DataOptions.lakiLaki,
      nomorKk: kk,
      // Pilihan diseragamkan ("sakit ringan - demam" -> "Sakit ringan - demam").
      kondisiKesehatan: _kondisi(_teks(_ambil(row, 'kondisi_kesehatan'))),
      kelompokRentan: rentan,
      riwayatPenyakit: _teks(_ambil(row, 'riwayat_penyakit')),
      error: error,
    );
  }

  static String? _pilih(String teks, Map<String, List<String>> pilihan) {
    final kunci = teks.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
    if (kunci.isEmpty) return null;
    for (final e in pilihan.entries) {
      if (kunci == e.key.toLowerCase() || e.value.contains(kunci)) return e.key;
    }
    return null;
  }
}
