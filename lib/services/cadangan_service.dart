// ============================================================
// cadangan_service.dart
// CADANGAN & PEMULIHAN seluruh data HP (tanpa internet).
//  - Cadangkan : semua tabel -> cadangan_<YYYYMMDD-HHMM>.zip
//                (simpan ke flashdisk / kirim ke HP lain).
//  - Pulihkan  : HP baru menjadi SAMA PERSIS dengan HP asal: posko,
//                pengungsi, logistik, akun, peran HP (Induk/Anggota),
//                dan kode perangkat. Karena kode perangkatnya sama, HP
//                Anggota tetap mengenali HP Induk pengganti.
// Pemulihan dilakukan dalam satu transaksi: gagal di tengah = data
// lama tetap utuh. Hanya menerima cadangan dari versi database yang sama.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../data/data_events.dart';
import '../data/database_tables.dart';
import '../data/local_database.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/pengaturan_repository.dart';
import '../data/table_store.dart';
import '../utils/berkas_terkunci.dart';
import '../utils/waktu_wib.dart';
import 'perangkat_service.dart';

class CadanganException implements Exception {
  final String message;

  /// true = file dikunci kata sandi posko yang belum / salah diberikan.
  final bool perluKataSandi;

  const CadanganException(this.message, {this.perluKataSandi = false});

  @override
  String toString() => message;
}

/// Isi file cadangan yang sudah dibaca.
class FileCadangan {
  final Map<String, Object?> meta;
  final Map<String, List<Map<String, Object?>>> tabel;

  const FileCadangan(this.meta, this.tabel);

  DateTime? get dibuatPada => WaktuWib.baca('${meta['dibuat_pada'] ?? ''}');
  bool get dariAnggota => meta['peran_perangkat'] == PengaturanRepository.peranAnggota;
  int jumlah(String t) => tabel[t]?.length ?? 0;

  /// Nama posko di cadangan (untuk ditampilkan sebelum dipulihkan).
  List<String> get namaPosko => [
        for (final r in tabel[DatabaseTables.posko] ?? const [])
          '${r['nama'] ?? '-'}',
      ];

  int get jumlahPengungsiAktif => (tabel[DatabaseTables.pengungsi] ?? const [])
      .where((r) => r['dihapus_pada'] == null)
      .length;
}

class CadanganService {
  CadanganService._();

  static const String jenis = 'logeva-cadangan';
  static const int versiFormat = 1;
  static const String namaJson = 'cadangan.json';

  /// Semua tabel yang dicadangkan (urutan = urutan pemulihan).
  static const List<String> tabel = [
    DatabaseTables.pengaturan,
    DatabaseTables.admin,
    DatabaseTables.posko,
    DatabaseTables.relawan,
    DatabaseTables.kategoriLogistik,
    DatabaseTables.barang,
    DatabaseTables.pengungsi,
    DatabaseTables.barangMasuk,
    DatabaseTables.barangKeluar,
    DatabaseTables.riwayat,
    DatabaseTables.logistikLama,
  ];

  static TableStore _s(TableStore? store) => store ?? LocalDatabase.store;

  /// Hasil: (nama file, isi ZIP).
  /// Hasil: (nama file, isi ZIP yang DIKUNCI kata sandi posko).
  static Future<(String, Uint8List)> buat({TableStore? store, DateTime? sekarang}) async {
    final s = _s(store);
    final waktu = sekarang ?? DateTime.now();
    final pengaturan = PengaturanRepository.withStore(s);
    final kataSandi = await pengaturan.kataSandiBerkas();
    if (kataSandi.isEmpty) {
      throw const CadanganException('Kata sandi posko belum diatur. Supervisor '
          'mengaturnya di HP Induk: Settings → Kata Sandi Posko.');
    }
    final isi = <String, Object?>{};
    for (final t in tabel) {
      // getAll urut terbaru dulu; dibalik supaya id tersimpan berurutan.
      isi[t] = (await s.getAll(t)).reversed.toList();
    }
    final json = {
      'jenis': jenis,
      'versi_format': versiFormat,
      'versi_database': DatabaseTables.version,
      'dibuat_pada': WaktuWib.tanggalWaktu(waktu),
      'kode_perangkat': await pengaturan.kodePerangkat(),
      'peran_perangkat': await pengaturan.peranPerangkat(),
      'tabel': isi,
    };
    final arsip = Archive()
      ..addFile(ArchiveFile.string(namaJson, jsonEncode(json)));
    final bytes = BerkasTerkunci.kunci(ZipEncoder().encode(arsip), kataSandi);
    return ('cadangan_logeva_${WaktuWib.capFile(waktu)}.zip', bytes);
  }

  /// Baca file cadangan. [kataSandi] = kata sandi posko (file terkunci);
  /// cadangan versi lama yang tidak terkunci tetap bisa dibaca.
  static FileCadangan baca(List<int> berkas, {String? kataSandi}) {
    final List<int> bytes;
    try {
      bytes = BerkasTerkunci.buka(berkas, kataSandi);
    } on BerkasTerkunciException catch (e) {
      throw CadanganException(e.message, perluKataSandi: e.perluKataSandi);
    }
    final Map<String, Object?> json;
    try {
      final f = ZipDecoder().decodeBytes(bytes).findFile(namaJson);
      if (f == null) throw const FormatException();
      json = (jsonDecode(utf8.decode(f.content)) as Map).cast();
    } catch (_) {
      throw const CadanganException(
          'File ini bukan file cadangan LOGEVA. Pilih file cadangan_logeva_....zip.');
    }
    if (json['jenis'] != jenis || json['versi_format'] != versiFormat) {
      throw const CadanganException('File ini bukan file cadangan LOGEVA.');
    }
    final versi = json['versi_database'];
    if (versi != DatabaseTables.version) {
      throw CadanganException(versi is int && versi < DatabaseTables.version
          ? 'Cadangan dari versi aplikasi yang lebih lama (database versi $versi). '
              'Pasang versi aplikasi yang sama dengan HP asal, pulihkan, lalu perbarui aplikasinya.'
          : 'Cadangan dari versi aplikasi yang lebih baru. Perbarui aplikasi di HP ini dulu.');
    }
    final mentah = (json['tabel'] as Map?) ?? const {};
    final isi = <String, List<Map<String, Object?>>>{
      for (final t in tabel)
        t: [
          for (final r in (mentah[t] as List?) ?? const [])
            (r as Map).cast<String, Object?>(),
        ],
    };
    if (isi[DatabaseTables.admin]!.isEmpty) {
      throw const CadanganException('File cadangan tidak berisi akun admin.');
    }
    final meta = Map<String, Object?>.of(json)..remove('tabel');
    return FileCadangan(meta, isi);
  }

  /// HP baru dipasang (belum ada posko, akun, atau catatan)? Pemulihan
  /// dari layar awal (sebelum login) hanya boleh di HP seperti ini.
  static Future<bool> hpKosong({TableStore? store}) async {
    final s = _s(store);
    final adminRepo = AdminRepository.withStore(s);
    final adminLain =
        (await adminRepo.getAll()).where((a) => !adminRepo.masihPasswordBawaan(a)).length;
    var terisi = adminLain;
    for (final t in [
      DatabaseTables.posko,
      DatabaseTables.relawan,
      DatabaseTables.pengungsi,
      DatabaseTables.barangMasuk,
      DatabaseTables.barangKeluar,
    ]) {
      terisi += await s.count(t);
    }
    return terisi == 0;
  }

  /// Mengganti SELURUH data HP ini dengan isi cadangan.
  static Future<void> pulihkan(FileCadangan file, {TableStore? store}) async {
    final s = _s(store);
    try {
      await s.gantiSemua(file.tabel);
    } catch (e) {
      throw CadanganException(
          'Pemulihan gagal, data HP ini tidak diubah. ($e)');
    }
    if (store == null) {
      PengaturanRepository.instance.lupakanCache();
      await PerangkatService.muat();
      DataEvents.instance.notifyChanged();
    }
  }
}
