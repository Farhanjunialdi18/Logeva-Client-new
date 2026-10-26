// ============================================================
// pengungsi.dart
// Bentuk data PENGUNGSI, mengikuti tabel `pengungsis` website.
//
// - [kode]        : kode unik (UUID) untuk Paket Data Posko, tidak berubah.
// - [tanggalLahir]: wajib untuk data baru; null hanya pada data dari
//                   versi lama aplikasi (ditandai "perlu dilengkapi").
// - [nomorKk]     : boleh kosong (dokumen bisa hilang saat bencana);
//                   kalau diisi harus 16 digit.
// - [dihapusPada] : data tidak dihapus permanen, hanya ditandai, supaya
//                   penghapusannya ikut terkirim ke pusat.
// ============================================================

import '../core/data_options.dart';
import '../utils/kode_unik.dart';
import '../utils/tanggal.dart';
import 'model_utils.dart';

class Pengungsi {
  final int? id;
  final String kode;
  final int? poskoId;
  final String posko; // NAMA posko (untuk tampilan, diisi repository)
  final String nama;
  final String asal;
  final DateTime? tanggalLahir;
  final int usia;
  final String jenisKelamin; // 'Laki-laki' / 'Perempuan'
  final String nomorKk; // kosong = belum diketahui
  final String kondisiKesehatan;
  final String kelompokRentan;
  final String riwayatPenyakit;
  final String dicatatOleh;
  final DateTime dibuatPada;
  final DateTime diubahPada;
  final DateTime? dihapusPada;

  const Pengungsi({
    this.id,
    required this.kode,
    this.poskoId,
    this.posko = '',
    required this.nama,
    this.asal = '',
    this.tanggalLahir,
    required this.usia,
    required this.jenisKelamin,
    this.nomorKk = '',
    this.kondisiKesehatan = DataOptions.kondisiSehat,
    this.kelompokRentan = DataOptions.bukanRentan,
    this.riwayatPenyakit = '',
    this.dicatatOleh = '',
    required this.dibuatPada,
    required this.diubahPada,
    this.dihapusPada,
  });

  /// Pengungsi baru: kode unik & waktu dibuat otomatis,
  /// usia dihitung dari tanggal lahir.
  factory Pengungsi.baru({
    required int? poskoId,
    required String nama,
    required String asal,
    required DateTime tanggalLahir,
    required String jenisKelamin,
    String nomorKk = '',
    String kondisiKesehatan = '',
    String kelompokRentan = DataOptions.bukanRentan,
    String riwayatPenyakit = '',
    String dicatatOleh = '',
  }) {
    final now = DateTime.now();
    return Pengungsi(
      kode: KodeUnik.buat(),
      poskoId: poskoId,
      nama: nama,
      asal: asal,
      tanggalLahir: tanggalLahir,
      usia: Tanggal.usia(tanggalLahir),
      jenisKelamin: jenisKelamin,
      nomorKk: nomorKk,
      kondisiKesehatan: _kondisi(kondisiKesehatan),
      kelompokRentan: kelompokRentan,
      riwayatPenyakit: riwayatPenyakit,
      dicatatOleh: dicatatOleh,
      dibuatPada: now,
      diubahPada: now,
    );
  }

  static String _kondisi(String teks) =>
      teks.trim().isEmpty ? DataOptions.kondisiSehat : teks.trim();

  bool get isPerempuan => jenisKelamin == DataOptions.perempuan;
  bool get isRentan => kelompokRentan != DataOptions.bukanRentan;
  bool get isDihapus => dihapusPada != null;

  /// Data versi lama tanpa tanggal lahir: wajib dilengkapi.
  bool get perluDilengkapi => tanggalLahir == null;

  /// Kunci ORANG YANG SAMA (aturan website): nama tanpa beda huruf
  /// besar/kecil & spasi ganda + tanggal lahir. Dibandingkan per posko.
  static String kunciSama(String nama, DateTime tanggalLahir) =>
      '${nama.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase()}'
      '|${Tanggal.format(tanggalLahir)}';

  /// null kalau tanggal lahir belum diisi.
  String? get kunci =>
      tanggalLahir == null ? null : kunciSama(nama, tanggalLahir!);

  /// Salinan dengan biodata baru (kode & waktu dibuat tetap).
  Pengungsi ubahData({
    required int? poskoId,
    required String nama,
    required String asal,
    required DateTime tanggalLahir,
    required String jenisKelamin,
    required String nomorKk,
    required String kondisiKesehatan,
    required String kelompokRentan,
    required String riwayatPenyakit,
  }) {
    return Pengungsi(
      id: id,
      kode: kode,
      poskoId: poskoId,
      nama: nama,
      asal: asal,
      tanggalLahir: tanggalLahir,
      usia: Tanggal.usia(tanggalLahir),
      jenisKelamin: jenisKelamin,
      nomorKk: nomorKk,
      kondisiKesehatan: _kondisi(kondisiKesehatan),
      kelompokRentan: kelompokRentan,
      riwayatPenyakit: riwayatPenyakit,
      dicatatOleh: dicatatOleh,
      dibuatPada: dibuatPada,
      diubahPada: DateTime.now(),
    );
  }

  /// Salinan yang ditandai dihapus.
  Pengungsi tandaiDihapus() {
    final now = DateTime.now();
    return _salin(diubahPada: now, dihapusPada: now);
  }

  /// Salinan dengan nama posko untuk tampilan.
  Pengungsi denganNamaPosko(String nama) => _salin(posko: nama);

  Pengungsi _salin({String? posko, DateTime? diubahPada, DateTime? dihapusPada}) {
    return Pengungsi(
      id: id,
      kode: kode,
      poskoId: poskoId,
      posko: posko ?? this.posko,
      nama: nama,
      asal: asal,
      tanggalLahir: tanggalLahir,
      usia: usia,
      jenisKelamin: jenisKelamin,
      nomorKk: nomorKk,
      kondisiKesehatan: kondisiKesehatan,
      kelompokRentan: kelompokRentan,
      riwayatPenyakit: riwayatPenyakit,
      dicatatOleh: dicatatOleh,
      dibuatPada: dibuatPada,
      diubahPada: diubahPada ?? this.diubahPada,
      dihapusPada: dihapusPada ?? this.dihapusPada,
    );
  }

  // ---------------- DATABASE ----------------

  Map<String, Object?> toMap() => {
        'id': id,
        'kode': kode,
        'posko_id': poskoId,
        'nama': nama,
        'asal': asal,
        'tanggal_lahir':
            tanggalLahir == null ? null : Tanggal.format(tanggalLahir!),
        'usia': usia,
        'jenis_kelamin': jenisKelamin,
        'nomor_kk': nomorKk.isEmpty ? null : nomorKk,
        'kondisi_kesehatan': kondisiKesehatan,
        'kelompok_rentan': kelompokRentan,
        'riwayat_penyakit': riwayatPenyakit.isEmpty ? null : riwayatPenyakit,
        'dicatat_oleh': dicatatOleh.isEmpty ? null : dicatatOleh,
        'dibuat_pada': dibuatPada.toIso8601String(),
        'diubah_pada': diubahPada.toIso8601String(),
        'dihapus_pada': dihapusPada?.toIso8601String(),
      };

  factory Pengungsi.fromMap(Map<String, Object?> map) {
    final dibuat = asDate(map['dibuat_pada']);
    final rentan = asText(map['kelompok_rentan']);
    return Pengungsi(
      id: asInt(map['id']),
      kode: asText(map['kode']),
      poskoId: asInt(map['posko_id']),
      nama: asText(map['nama']),
      asal: asText(map['asal']),
      tanggalLahir: Tanggal.baca(asText(map['tanggal_lahir'])),
      usia: asInt(map['usia']) ?? 0,
      jenisKelamin: asText(map['jenis_kelamin']) == DataOptions.perempuan
          ? DataOptions.perempuan
          : DataOptions.lakiLaki,
      nomorKk: asText(map['nomor_kk']),
      kondisiKesehatan: _kondisi(asText(map['kondisi_kesehatan'])),
      kelompokRentan: DataOptions.kelompokRentan.contains(rentan)
          ? rentan
          : DataOptions.bukanRentan,
      riwayatPenyakit: asText(map['riwayat_penyakit']),
      dicatatOleh: asText(map['dicatat_oleh']),
      dibuatPada: dibuat,
      diubahPada: asDateOrNull(map['diubah_pada']) ?? dibuat,
      dihapusPada: asDateOrNull(map['dihapus_pada']),
    );
  }
}
