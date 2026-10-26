// Tahap B: File Penyiapan dari HP Induk ke HP Anggota (dua database
// terpisah = dua HP). Tanpa internet: file hanya dibuat & dibaca.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/repositories/admin_repository.dart';
import 'package:flutter_application_1/data/repositories/barang_repository.dart';
import 'package:flutter_application_1/data/repositories/pengaturan_repository.dart';
import 'package:flutter_application_1/data/repositories/pengungsi_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/data/repositories/relawan_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/barang.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/models/relawan.dart';
import 'package:flutter_application_1/services/penyiapan_service.dart';
import 'package:flutter_application_1/utils/password_hasher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late SqliteTableStore induk;
  late SqliteTableStore anggota;
  late Posko posko;
  late Relawan andi;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_penyiapan_');
    induk = SqliteTableStore(path: '${folder.path}/induk.db', factory: databaseFactoryFfi);
    anggota = SqliteTableStore(path: '${folder.path}/anggota.db', factory: databaseFactoryFfi);

    // ---- HP Induk: admin ganti password, buat posko, relawan, barang ----
    final admin = AdminRepository.withStore(induk);
    await admin.ensureDefaultAdmin();
    final a = (await admin.getAll()).single;
    await admin.gantiPassword(a, 'posko2026');
    await admin.add(
        nama: 'Admin Bawaan Lain', username: 'admin2', email: 'x@x.id',
        password: AdminRepository.defaultPassword);

    posko = await PoskoRepository.withStore(induk).add(Posko.baru(
      nama: 'Balai Desa', namaDesa: 'Panggarangan', alamat: 'Jl. 1',
      luasLokasi: 350, latitude: '-6.9', longitude: '106.1',
    ));
    final relawan = RelawanRepository.withStore(induk);
    andi = await relawan.add(Relawan(
        nama: 'Andi', kontak: '0812', pin: '111111', dibuatPada: DateTime(2026))
        .tempatkan(posko));
    await relawan.add(Relawan(
        nama: 'Siti', pin: '222222', status: DataOptions.statusNonaktif,
        dibuatPada: DateTime(2026)).tempatkan(posko));
    await BarangRepository.withStore(induk).add(Barang.baru(
        kategoriId: 4, namaItem: 'Selimut', satuan: 'buah', kebutuhanHarian: 0.1));
  });

  tearDown(() async {
    await induk.close();
    await anggota.close();
    await folder.delete(recursive: true);
  });

  Future<FilePenyiapan> buatFile() async {
    final (nama, bytes) = await PenyiapanService.buat(posko, store: induk);
    expect(nama, startsWith('penyiapan_BalaiDesa_'));
    return PenyiapanService.baca(bytes);
  }

  test('file tidak berisi PIN / password asli', () async {
    final (_, bytes) = await PenyiapanService.buat(posko, store: induk);
    final teks = utf8.decode(
        ZipDecoder().decodeBytes(bytes).findFile('penyiapan.json')!.content);
    expect(teks.contains('111111'), isFalse, reason: 'PIN asli');
    expect(teks.contains('222222'), isFalse);
    expect(teks.contains('posko2026'), isFalse, reason: 'password asli');
    expect(teks.contains('"pin":'), isFalse);
    final file = PenyiapanService.baca(bytes);
    expect(file.admin.map((a) => a['username']), ['admin'],
        reason: 'admin dengan password bawaan tidak ikut');
  });

  test('HP Anggota: posko sama, relawan & admin bisa login', () async {
    // HP baru: akun bawaan sempat dibuat saat layar login dibuka.
    await AdminRepository.withStore(anggota).ensureDefaultAdmin();

    final file = await buatFile();
    expect(await PenyiapanService.cekBoleh(file, store: anggota), isNull);
    await PenyiapanService.terapkan(file, store: anggota);

    final pengaturan = PengaturanRepository.withStore(anggota);
    expect(await pengaturan.isAnggota(), isTrue);

    final poskoAnggota = (await PoskoRepository.withStore(anggota).getAll()).single;
    expect(poskoAnggota.kode, posko.kode, reason: 'kode posko sama persis');
    expect(poskoAnggota.nama, 'Balai Desa');

    final relawan = RelawanRepository.withStore(anggota);
    final login = await relawan.findByPin('111111');
    expect(login?.nama, 'Andi');
    expect(login?.kode, andi.kode);
    expect(login?.poskoId, poskoAnggota.id);
    expect(login?.pinTerlihat, isFalse, reason: 'PIN asli tidak disimpan');
    expect(login?.kontak, '0812');
    final siti = await relawan.findByPin('222222');
    expect(siti?.isAktif, isFalse, reason: 'status nonaktif ikut, login ditolak');
    expect(await relawan.findByPin('333333'), isNull);

    final adminRepo = AdminRepository.withStore(anggota);
    final semuaAdmin = await adminRepo.getAll();
    expect(semuaAdmin, hasLength(1), reason: 'akun bawaan admin123 dihapus');
    final admin = (await adminRepo.findByLogin('admin'))!;
    expect(PasswordHasher.verify('posko2026',
        hash: admin.passwordHash, salt: admin.passwordSalt), isTrue);
    expect(adminRepo.masihPasswordBawaan(admin), isFalse);

    final barang = await BarangRepository.withStore(anggota).getAll();
    final selimut = barang.firstWhere((b) => b.namaItem == 'Selimut');
    expect(selimut.kategori, 'Perlengkapan Tidur');
    expect(selimut.kebutuhanHarian, 0.1);
    expect(barang.where((b) => b.namaItem == 'Beras'), hasLength(1),
        reason: 'barang bawaan tidak dobel');
  });

  test('kirim ulang: relawan baru masuk, yang dihapus ikut hilang, tidak dobel',
      () async {
    await PenyiapanService.terapkan(await buatFile(), store: anggota);

    final relawanInduk = RelawanRepository.withStore(induk);
    final budi = await relawanInduk.add(Relawan(
        nama: 'Budi', pin: '444444', dibuatPada: DateTime(2026)).tempatkan(posko));
    final siti = (await relawanInduk.getAll()).firstWhere((r) => r.nama == 'Siti');
    await relawanInduk.delete(siti.id!);
    final pinBaru = (await relawanInduk.regeneratePin(andi)).pin;

    await PenyiapanService.terapkan(await buatFile(), store: anggota);

    final relawan = RelawanRepository.withStore(anggota);
    final semua = await relawan.getAll();
    expect(semua.map((r) => r.nama).toSet(), {'Andi', 'Budi'});
    expect((await relawan.findByPin('444444'))?.kode, budi.kode);
    expect(await relawan.findByPin('111111'), isNull, reason: 'PIN lama Andi');
    expect((await relawan.findByPin(pinBaru))?.nama, 'Andi');
    expect(await PoskoRepository.withStore(anggota).count(), 1);
  });

  test('HP yang sudah berisi data lain ditolak', () async {
    await PengungsiRepository.withStore(anggota).add(Pengungsi.baru(
      poskoId: 1, nama: 'X', asal: 'Y', tanggalLahir: DateTime(1990),
      jenisKelamin: DataOptions.lakiLaki,
    ));
    final file = await buatFile();
    expect(await PenyiapanService.cekBoleh(file, store: anggota), isNotNull);
    await expectLater(PenyiapanService.terapkan(file, store: anggota),
        throwsA(isA<PenyiapanException>()));
    expect(await PengaturanRepository.withStore(anggota).isAnggota(), isFalse);
  });

  test('HP Anggota tidak bisa membuat File Penyiapan', () async {
    await PenyiapanService.terapkan(await buatFile(), store: anggota);
    final p = (await PoskoRepository.withStore(anggota).getAll()).single;
    await expectLater(PenyiapanService.buat(p, store: anggota),
        throwsA(isA<PenyiapanException>()));
  });

  test('admin masih password bawaan -> file tidak bisa dibuat', () async {
    final baru = SqliteTableStore(
        path: '${folder.path}/baru.db', factory: databaseFactoryFfi);
    await AdminRepository.withStore(baru).ensureDefaultAdmin();
    final p = await PoskoRepository.withStore(baru).add(Posko.baru(nama: 'A'));
    await expectLater(PenyiapanService.buat(p, store: baru),
        throwsA(isA<PenyiapanException>()
            .having((e) => e.message, 'pesan', contains('password bawaan'))));
    await baru.close();
  });

  test('file lain ditolak dengan pesan jelas', () {
    expect(() => PenyiapanService.baca([1, 2, 3]),
        throwsA(isA<PenyiapanException>()));
    final arsip = Archive()
      ..addFile(ArchiveFile.string('penyiapan.json', '{"jenis":"lain"}'));
    expect(() => PenyiapanService.baca(ZipEncoder().encodeBytes(arsip)),
        throwsA(isA<PenyiapanException>()));
  });
}
