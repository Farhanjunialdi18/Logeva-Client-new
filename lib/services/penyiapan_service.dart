// ============================================================
// penyiapan_service.dart
// FILE PENYIAPAN POSKO: menyiapkan HP Anggota dari HP Induk tanpa
// internet (dikirim lewat Bluetooth / Quick Share / flashdisk).
//
// Isi (penyiapan.json di dalam ZIP):
//  - identitas posko (kode SAMA dengan HP Induk, jadi semua HP mencatat
//    posko yang sama, tidak bergantung pada kesamaan nama)
//  - master barang & kategori
//  - akun relawan posko itu: nama, kontak, status, PIN yang DIACAK
//    (PIN asli tidak ikut) + salt PIN HP Induk supaya login PIN bekerja
//  - akun admin: password yang sudah diacak (password asli tidak ikut).
//    Admin yang masih memakai password bawaan TIDAK ikut.
//
// File boleh diterapkan berkali-kali (misal ada relawan baru): data
// dicocokkan dengan kode, jadi tidak dobel. Akun relawan/admin yang
// sudah dihapus di HP Induk ikut terhapus di HP Anggota.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../data/database_tables.dart';
import '../data/data_events.dart';
import '../data/local_database.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/barang_repository.dart';
import '../data/repositories/pengaturan_repository.dart';
import '../data/repositories/relawan_repository.dart';
import '../data/table_store.dart';
import '../models/admin.dart';
import '../models/barang.dart';
import '../models/posko.dart';
import '../models/relawan.dart';
import '../utils/waktu_wib.dart';

/// Penyiapan ditolak; [message] siap ditampilkan.
class PenyiapanException implements Exception {
  final String message;
  const PenyiapanException(this.message);

  @override
  String toString() => message;
}

/// Isi File Penyiapan yang sudah dibaca (untuk pratinjau sebelum diterapkan).
class FilePenyiapan {
  static const String jenis = 'penyiapan_posko';
  static const int versiFormat = 1;
  static const String namaJson = 'penyiapan.json';

  final Map<String, Object?> json;
  const FilePenyiapan(this.json);

  String get kodePerangkatInduk => json['kode_perangkat_induk'] as String;
  String get saltPin => json['salt_pin'] as String;
  Map<String, Object?> get posko => (json['posko'] as Map).cast();
  String get namaPosko => posko['nama'] as String;
  String get kodePosko => posko['kode'] as String;
  String get dibuatPada => json['dibuat_pada'] as String;
  String get dibuatOleh => json['dibuat_oleh'] as String? ?? '';

  List<Map<String, Object?>> _daftar(String k) =>
      [for (final e in json[k] as List) (e as Map).cast<String, Object?>()];

  List<Map<String, Object?>> get kategori => _daftar('kategori');
  List<Map<String, Object?>> get barang => _daftar('barang');
  List<Map<String, Object?>> get admin => _daftar('admin');
  List<Map<String, Object?>> get relawan => _daftar('relawan');
}

/// Ringkasan sebelum File Penyiapan dibuat di HP Induk.
class RencanaPenyiapan {
  final Posko posko;
  final List<Admin> admin; // yang ikut
  final List<Admin> adminBawaan; // tidak ikut (password bawaan)
  final List<Relawan> relawan;

  const RencanaPenyiapan({
    required this.posko,
    required this.admin,
    required this.adminBawaan,
    required this.relawan,
  });

  bool get bisaDibuat => admin.isNotEmpty;
}

class PenyiapanService {
  PenyiapanService._();

  static TableStore _s(TableStore? store) => store ?? LocalDatabase.store;

  // ================= DI HP INDUK =================

  static Future<RencanaPenyiapan> rencana(Posko posko,
      {TableStore? store}) async {
    final s = _s(store);
    final adminRepo = AdminRepository.withStore(s);
    final semuaAdmin = await adminRepo.getAll();
    final relawanRepo = RelawanRepository.withStore(s);
    await relawanRepo.lengkapiPinHash();
    return RencanaPenyiapan(
      posko: posko,
      admin: semuaAdmin.where((a) => !adminRepo.masihPasswordBawaan(a)).toList(),
      adminBawaan:
          semuaAdmin.where((a) => adminRepo.masihPasswordBawaan(a)).toList(),
      relawan: await relawanRepo.getByPosko(posko.id!),
    );
  }

  /// Buat File Penyiapan (ZIP) untuk [posko]. Hanya di HP Induk.
  static Future<(String, Uint8List)> buat(
    Posko posko, {
    TableStore? store,
    String dibuatOleh = '',
    DateTime? waktu,
  }) async {
    final now = waktu ?? DateTime.now();
    final json = await buatJson(posko, store: store, dibuatOleh: dibuatOleh, waktu: now);
    final arsip = Archive()
      ..addFile(ArchiveFile.string(FilePenyiapan.namaJson, jsonEncode(json)));
    final nama = posko.nama.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
    return (
      'penyiapan_${nama.isEmpty ? 'Posko' : nama}_${WaktuWib.capFile(now)}.zip',
      ZipEncoder().encodeBytes(arsip),
    );
  }

  /// Isi penyiapan.json (dipakai juga File Sinkron dari HP Induk, supaya
  /// perubahan akun & master barang ikut ke HP Anggota).
  static Future<Map<String, Object?>> buatJson(
    Posko posko, {
    TableStore? store,
    String dibuatOleh = '',
    DateTime? waktu,
  }) async {
    final s = _s(store);
    final pengaturan = PengaturanRepository.withStore(s);
    if (await pengaturan.isAnggota()) {
      throw const PenyiapanException(
          'File Penyiapan hanya bisa dibuat di HP Induk.');
    }
    final r = await rencana(posko, store: s);
    if (!r.bisaDibuat) {
      throw const PenyiapanException(
          'Ganti dulu password bawaan admin (Settings → Keamanan). Akun dengan '
          'password bawaan tidak boleh dibagikan ke HP lain.');
    }

    final now = waktu ?? DateTime.now();
    final barangRepo = BarangRepository.withStore(s);
    return {
      'jenis': FilePenyiapan.jenis,
      'versi_format': FilePenyiapan.versiFormat,
      'dibuat_pada': WaktuWib.tanggalWaktu(now),
      'dibuat_oleh': dibuatOleh,
      'kode_perangkat_induk': await pengaturan.kodePerangkat(),
      'salt_pin': await pengaturan.saltPin(),
      'posko': posko.toMap()..remove('id'),
      'kategori': [
        for (final k in await barangRepo.getKategori()) {'id': k.id, 'nama': k.nama},
      ],
      'barang': [
        for (final b in await barangRepo.getAll()) b.toMap()..remove('id'),
      ],
      'admin': [
        for (final a in r.admin) a.toMap()..remove('id'),
      ],
      'relawan': [
        for (final v in r.relawan)
          (v.toMap()
                ..remove('id')
                ..remove('pin') // PIN asli tidak pernah ikut
                ..remove('posko_id')
                ..remove('terakhir_login'))
            ..['posko_kode'] = posko.kode,
      ],
    };
  }

  // ================= DI HP ANGGOTA =================

  /// Baca & periksa File Penyiapan (belum menyimpan apa pun).
  static FilePenyiapan baca(List<int> bytes) {
    final Map<String, Object?> json;
    try {
      final arsip = ZipDecoder().decodeBytes(bytes);
      final f = arsip.findFile(FilePenyiapan.namaJson);
      if (f == null) throw const FormatException();
      json = (jsonDecode(utf8.decode(f.content)) as Map).cast();
    } catch (_) {
      throw const PenyiapanException(
          'File ini bukan File Penyiapan Posko. Pilih file penyiapan_....zip '
          'dari HP Induk.');
    }
    if (json['jenis'] != FilePenyiapan.jenis) {
      throw const PenyiapanException('File ini bukan File Penyiapan Posko.');
    }
    if (json['versi_format'] != FilePenyiapan.versiFormat) {
      throw const PenyiapanException(
          'Versi File Penyiapan tidak dikenali. Samakan versi aplikasi di '
          'kedua HP.');
    }
    final file = FilePenyiapan(json);
    if (file.admin.isEmpty) {
      throw const PenyiapanException('File Penyiapan tidak berisi akun admin.');
    }
    return file;
  }

  /// Apakah HP ini boleh menerima [file]? Boleh jika HP masih kosong, atau
  /// sudah menjadi HP Anggota dari HP Induk yang sama (memperbarui akun).
  /// Hasil: alasan penolakan, atau null kalau boleh.
  static Future<String?> cekBoleh(FilePenyiapan file, {TableStore? store}) async {
    final s = _s(store);
    final pengaturan = PengaturanRepository.withStore(s);
    if (await pengaturan.isAnggota()) {
      final induk = await pengaturan.get(kunciKodeInduk);
      final posko = await pengaturan.get(kunciKodePosko);
      if (induk == file.kodePerangkatInduk && posko == file.kodePosko) return null;
      return 'HP ini sudah disiapkan dari HP Induk / posko lain.';
    }

    final adminRepo = AdminRepository.withStore(s);
    final adminLain = (await adminRepo.getAll())
        .where((a) => !adminRepo.masihPasswordBawaan(a))
        .length;
    final terisi = await s.count(DatabaseTables.posko) +
        await s.count(DatabaseTables.relawan) +
        await s.count(DatabaseTables.pengungsi) +
        await s.count(DatabaseTables.barangMasuk) +
        await s.count(DatabaseTables.barangKeluar) +
        adminLain;
    if (terisi > 0) {
      return 'HP ini sudah berisi data (posko, akun, atau catatan). Penyiapan '
          'hanya untuk HP yang baru dipasang, supaya data tidak tercampur.';
    }
    return null;
  }

  static const String kunciKodeInduk = 'kode_perangkat_induk';
  static const String kunciKodePosko = 'posko_anggota';

  /// Terapkan [file] ke HP ini. Hasil: ringkasan untuk ditampilkan.
  static Future<String> terapkan(FilePenyiapan file, {TableStore? store}) async {
    final s = _s(store);
    final alasan = await cekBoleh(file, store: s);
    if (alasan != null) throw PenyiapanException(alasan);

    final pengaturan = PengaturanRepository.withStore(s);
    // Salt dulu: tanpa salt yang sama, PIN dari HP Induk tidak cocok.
    await pengaturan.set(PengaturanRepository.kunciSaltPin, file.saltPin);
    await pengaturan.set(kunciKodeInduk, file.kodePerangkatInduk);
    await pengaturan.set(kunciKodePosko, file.kodePosko);

    final poskoId = await _terapkanPosko(s, file.posko);
    await _terapkanMaster(s, file);
    await _terapkanAdmin(s, file.admin);
    final relawan = await _terapkanRelawan(s, file.relawan, poskoId);

    await pengaturan.setPeranPerangkat(PengaturanRepository.peranAnggota);
    DataEvents.instance.notifyChanged();
    return 'HP ini siap sebagai HP Anggota ${file.namaPosko}: '
        '$relawan relawan dan ${file.admin.length} admin bisa login.';
  }

  static Future<int> _terapkanPosko(TableStore s, Map<String, Object?> map) async {
    final baru = Posko.fromMap(map);
    for (final row in await s.getAll(DatabaseTables.posko)) {
      if (row['kode'] == baru.kode) {
        final id = row['id'] as int;
        await s.update(DatabaseTables.posko, id, baru.toMap()..['id'] = id);
        return id;
      }
    }
    return s.insert(DatabaseTables.posko, baru.toMap());
  }

  static Future<void> _terapkanMaster(TableStore s, FilePenyiapan file) async {
    // Kategori dicocokkan dengan nama; id kategori HP Induk -> id di HP ini.
    final lokal = {
      for (final r in await s.getAll(DatabaseTables.kategoriLogistik))
        (r['nama'] as String).toLowerCase(): r['id'] as int,
    };
    final petaKategori = <int, int>{};
    for (final k in file.kategori) {
      final nama = k['nama'] as String;
      petaKategori[k['id'] as int] = lokal[nama.toLowerCase()] ??
          await s.insert(DatabaseTables.kategoriLogistik, {'nama': nama});
    }

    // Barang dicocokkan dengan kategori + nama (sama dengan website).
    final ada = {
      for (final r in await s.getAll(DatabaseTables.barang))
        Barang.fromMap(r).kunci: r['id'] as int,
    };
    for (final m in file.barang) {
      final b = Barang.fromMap({
        ...m,
        'kategori_id': petaKategori[m['kategori_id']] ?? m['kategori_id'],
      });
      final id = ada[b.kunci];
      if (id == null) {
        await s.insert(DatabaseTables.barang, b.toMap());
      } else {
        await s.update(DatabaseTables.barang, id, b.toMap()..['id'] = id);
      }
    }
  }

  static Future<void> _terapkanAdmin(
      TableStore s, List<Map<String, Object?>> daftar) async {
    final kode = {for (final a in daftar) a['kode']};
    final lokal = (await s.getAll(DatabaseTables.admin)).map(Admin.fromMap);
    // Admin lokal yang tidak ada di HP Induk (termasuk akun bawaan admin123)
    // dihapus: akun admin dikelola di HP Induk.
    for (final a in lokal) {
      if (!kode.contains(a.kode)) await s.delete(DatabaseTables.admin, a.id!);
    }
    final byKode = {
      for (final r in await s.getAll(DatabaseTables.admin)) r['kode']: r['id'] as int,
    };
    for (final m in daftar) {
      final id = byKode[m['kode']];
      if (id == null) {
        await s.insert(DatabaseTables.admin, Admin.fromMap(m).toMap());
      } else {
        await s.update(DatabaseTables.admin, id, Admin.fromMap(m).toMap()..['id'] = id);
      }
    }
  }

  static Future<int> _terapkanRelawan(
      TableStore s, List<Map<String, Object?>> daftar, int poskoId) async {
    final kode = {for (final r in daftar) r['kode']};
    final lokal = (await s.getAll(DatabaseTables.relawan)).map(Relawan.fromMap);
    for (final r in lokal) {
      if (!kode.contains(r.kode)) await s.delete(DatabaseTables.relawan, r.id!);
    }
    final byKode = {for (final r in lokal) r.kode: r};
    for (final m in daftar) {
      final lama = byKode[m['kode']];
      final baru = Relawan.fromMap({
        ...m,
        'pin': null, // PIN asli tidak disimpan di HP Anggota
        'posko_id': poskoId,
        'terakhir_login': lama?.terakhirLogin?.toIso8601String(),
      });
      if (lama == null) {
        await s.insert(DatabaseTables.relawan, baru.toMap());
      } else {
        await s.update(
            DatabaseTables.relawan, lama.id!, baru.toMap()..['id'] = lama.id);
      }
    }
    return daftar.length;
  }
}
