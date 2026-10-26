// Tes migrasi database: HP yang memperbarui aplikasi tidak boleh
// kehilangan data. Memakai sqflite_common_ffi (SQLite di komputer).

import 'dart:io';

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/database_tables.dart';
import 'package:flutter_application_1/data/repositories/pengungsi_repository.dart';
import 'package:flutter_application_1/data/repositories/pengaturan_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/models/admin.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/models/relawan_session.dart';
import 'package:flutter_application_1/services/session_service.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/utils/kode_unik.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Buat database "HP lama" pada [versi] tertentu.
Future<Database> bukaVersiLama(String path, int versi) {
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: versi,
      onCreate: (db, _) async {
        for (var v = 1; v <= versi; v++) {
          for (final sql in DatabaseTables.upgradeSteps[v]!) {
            await db.execute(sql);
          }
        }
      },
    ),
  );
}

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late String path;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_test_');
    path = '${folder.path}/logeva.db';
  });

  tearDown(() async => folder.delete(recursive: true));

  test('instalasi baru membuat semua tabel', () async {
    final store = SqliteTableStore(path: path, factory: databaseFactoryFfi);
    expect(await store.count(DatabaseTables.pengaturan), 0);
    expect(await store.count(DatabaseTables.pengungsi), 0);
    await store.close();
  });

  test('upgrade versi 3 -> terbaru: data lama tetap ada', () async {
    final lama = await bukaVersiLama(path, 3);
    await lama.insert(DatabaseTables.posko, {
      'nama': 'Desa Panggarangan',
      'dibuat_pada': '2026-10-01T08:00:00.000',
    });
    await lama.insert(DatabaseTables.pengungsi, {
      'nama': 'Budi Santoso',
      'nik': '3602010101010001',
      'jenis_kelamin': 'L',
      'usia': 42,
      'kondisi': 'Sehat',
      'domisili': 'Desa Panggarangan',
      'posko': 'Desa Panggarangan',
      'dibuat_pada': '2026-10-01T08:00:00.000',
    });
    await lama.close();

    final store = SqliteTableStore(path: path, factory: databaseFactoryFfi);
    final pengungsi = await store.getAll(DatabaseTables.pengungsi);
    expect(pengungsi, hasLength(1));
    expect(pengungsi.single['nama'], 'Budi Santoso');
    expect(await store.count(DatabaseTables.posko), 1);
    expect(await store.count(DatabaseTables.pengaturan), 0);
    await store.close();
  });

  test('upgrade ke versi 5: posko lengkap + relawan memakai posko_id',
      () async {
    final lama = await bukaVersiLama(path, 3);
    const t = '2026-10-01T08:00:00.000';
    await lama.insert(DatabaseTables.posko,
        {'nama': 'Desa Panggarangan', 'alamat': 'Kec. X', 'dibuat_pada': t});
    // Huruf besar/kecil & spasi berbeda, tetap posko yang sama.
    await lama.insert(DatabaseTables.relawan, {
      'nama': 'Andi',
      'pin': '111111',
      'posko': ' desa panggarangan',
      'dibuat_pada': t,
    });
    await lama.insert(DatabaseTables.relawan,
        {'nama': 'Belum', 'pin': '222222', 'posko': '', 'dibuat_pada': t});
    // 'Cisolok' dipakai pengungsi tapi belum terdaftar sebagai posko.
    await lama.insert(DatabaseTables.pengungsi, {
      'nama': 'Siti',
      'jenis_kelamin': 'P',
      'usia': 29,
      'kondisi': 'Sehat',
      'domisili': 'Cisolok',
      'posko': 'Cisolok',
      'dibuat_pada': t,
    });
    // '-' = posko kosong dari import CSV lama, jangan jadi posko.
    await lama.insert(DatabaseTables.logistik, {
      'nama_barang': 'Beras',
      'kategori': 'Makanan',
      'jumlah': 5,
      'satuan': 'Kg',
      'posko': '-',
      'dibuat_pada': t,
    });
    await lama.close();

    final store = SqliteTableStore(path: path, factory: databaseFactoryFfi);
    final posko = (await store.getAll(DatabaseTables.posko))
        .map(Posko.fromMap)
        .toList();
    expect(posko.map((p) => p.nama).toSet(), {'Desa Panggarangan', 'Cisolok'});
    expect(posko.every((p) => KodeUnik.valid(p.kode)), isTrue);
    expect(posko.map((p) => p.kode).toSet(), hasLength(2));
    for (final p in posko) {
      expect(p.namaDesa, p.nama, reason: 'desa sementara = nama posko');
      expect(p.statusOperasional, Posko.siaga);
      expect(p.lengkap, isFalse);
    }

    final panggarangan = posko.firstWhere((p) => p.nama == 'Desa Panggarangan');
    expect(panggarangan.alamat, 'Kec. X');
    expect(panggarangan.diubahPada, DateTime.parse(t));

    final relawan = await store.getAll(DatabaseTables.relawan);
    final andi = relawan.firstWhere((r) => r['nama'] == 'Andi');
    final belum = relawan.firstWhere((r) => r['nama'] == 'Belum');
    expect(andi['posko_id'], panggarangan.id);
    expect(belum['posko_id'], isNull);
    await store.close();
  });

  test('upgrade dari versi 1 sampai terbaru berjalan', () async {
    final lama = await bukaVersiLama(path, 1);
    await lama.close();
    final store = SqliteTableStore(path: path, factory: databaseFactoryFfi);
    expect(await store.count(DatabaseTables.posko), 0);
    await store.close();
  });

  test('upgrade ke versi 6: pengungsi lama dipindahkan ke kolom website',
      () async {
    final lama = await bukaVersiLama(path, 5);
    const t = '2026-10-01T08:00:00.000';
    final poskoId = await lama.insert(DatabaseTables.posko, {
      'nama': 'Cisolok',
      'alamat': '',
      'dibuat_pada': t,
      'kode': '00000000-0000-4000-8000-000000000000',
    });
    Future<void> tambah(String nama, String jk, String kondisi,
        {String posko = 'cisolok', String? nik}) {
      return lama.insert(DatabaseTables.pengungsi, {
        'nama': nama,
        'nik': nik,
        'jenis_kelamin': jk,
        'usia': 70,
        'kondisi': kondisi,
        'domisili': 'Desa Cikaret',
        'posko': posko,
        'dibuat_pada': t,
      });
    }

    await tambah('Budi', 'L', 'Sehat', nik: '3602010101010001');
    await tambah('Siti', 'P', 'Ibu Hamil');
    await tambah('Ani', 'P', 'Perlu Perawatan');
    await tambah('Asep', 'L', 'Demam', posko: '-');
    await lama.close();

    final store = SqliteTableStore(path: path, factory: databaseFactoryFfi);
    final rows = await store.getAll(DatabaseTables.pengungsi);
    Map<String, Object?> cari(String nama) =>
        rows.firstWhere((r) => r['nama'] == nama);

    final budi = cari('Budi');
    expect(budi['jenis_kelamin'], 'Laki-laki');
    expect(budi['asal'], 'Desa Cikaret');
    expect(budi['kondisi_kesehatan'], 'Sehat');
    expect(budi['kelompok_rentan'], 'Tidak');
    expect(budi['posko_id'], poskoId);
    expect(budi['nomor_kk'], isNull, reason: 'NIK bukan nomor KK');
    expect(budi['nik_lama'], '3602010101010001');
    expect(budi['tanggal_lahir'], isNull);
    expect(budi['diubah_pada'], t);
    expect(budi['dihapus_pada'], isNull);

    final siti = cari('Siti');
    expect(siti['jenis_kelamin'], 'Perempuan');
    expect(siti['kondisi_kesehatan'], 'Sehat');
    expect(siti['kelompok_rentan'], 'Ibu Hamil');

    final ani = cari('Ani');
    expect(ani['kondisi_kesehatan'], 'Perlu Perawatan');
    expect(ani['kelompok_rentan'], 'Sakit');

    final asep = cari('Asep');
    expect(asep['kondisi_kesehatan'], 'Demam');
    expect(asep['posko_id'], isNull);

    final kode = rows.map((r) => r['kode'] as String).toSet();
    expect(kode, hasLength(4));
    expect(kode.every(KodeUnik.valid), isTrue);

    final model = rows.map(Pengungsi.fromMap).toList();
    expect(model.every((e) => e.perluDilengkapi), isTrue);
    await store.close();
  });

  group('repository', () {
    late SqliteTableStore store;
    late PoskoRepository poskoRepo;
    late PengungsiRepository repo;

    setUp(() {
      store = SqliteTableStore(path: path, factory: databaseFactoryFfi);
      poskoRepo = PoskoRepository.withStore(store);
      repo = PengungsiRepository.withStore(store);
      SessionService.instance.startAdmin(Admin(
        nama: 'Admin',
        username: 'admin',
        email: 'admin@x.id',
        passwordHash: '',
        passwordSalt: '',
        dibuatPada: DateTime(2026),
      ));
    });

    tearDown(() async {
      SessionService.instance.clear();
      await store.close();
    });

    Pengungsi orang(int poskoId, String nama) => Pengungsi.baru(
          poskoId: poskoId,
          nama: nama,
          asal: 'X',
          tanggalLahir: DateTime(1990, 7, 25),
          jenisKelamin: DataOptions.lakiLaki,
        );

    test('hapus pengungsi = ditandai, tidak hilang dari database', () async {
      final posko = await poskoRepo.add(Posko.baru(nama: 'A'));
      await repo.add(orang(posko.id!, 'Budi'));
      final budi = (await repo.getByPosko(posko.id)).single;

      await repo.hapus(budi);
      expect(await repo.getByPosko(posko.id), isEmpty);
      expect(await repo.count(), 0);

      final semua = await repo.getAll(termasukDihapus: true);
      expect(semua.single.kode, budi.kode);
      expect(semua.single.dihapusPada, isNotNull);
      expect(semua.single.diubahPada.isBefore(budi.diubahPada), isFalse);
    });

    test('orang yang sama = nama (tanpa beda huruf) + tanggal lahir, per posko',
        () async {
      final a = await poskoRepo.add(Posko.baru(nama: 'A'));
      final b = await poskoRepo.add(Posko.baru(nama: 'B'));
      await repo.add(orang(a.id!, 'Budi  Santoso'));

      expect(await repo.cariSama(orang(a.id!, 'budi santoso')), isNotNull);
      expect(await repo.cariSama(orang(b.id!, 'Budi Santoso')), isNull,
          reason: 'posko lain');
      final lain = Pengungsi.baru(
        poskoId: a.id,
        nama: 'Budi Santoso',
        asal: 'X',
        tanggalLahir: DateTime(1991, 7, 25),
        jenisKelamin: DataOptions.lakiLaki,
      );
      expect(await repo.cariSama(lain), isNull, reason: 'tanggal lahir beda');

      // Mengedit diri sendiri tidak dianggap dobel.
      final budi = (await repo.getByPosko(a.id)).single;
      expect(await repo.cariSama(budi), isNull);
    });

    test('nama posko ikut tampil & tetap benar setelah posko diganti nama',
        () async {
      final posko = await poskoRepo.add(Posko.baru(nama: 'Lama'));
      await repo.add(orang(posko.id!, 'Budi'));
      await poskoRepo.update(posko.ubahData(
        nama: 'Baru',
        namaDesa: '',
        alamat: '',
        luasLokasi: null,
        latitude: '',
        longitude: '',
      ));
      expect((await repo.getByPosko(posko.id)).single.posko, 'Baru');
      expect((await poskoRepo.findById(posko.id!))!.kode, posko.kode);

      await expectLater(poskoRepo.add(Posko.baru(nama: 'baru')),
          throwsA(isA<PoskoException>()),
          reason: 'nama sama (beda huruf besar/kecil) ditolak');
    });

    test('aturan hapus posko', () async {
      final posko = await poskoRepo.add(Posko.baru(nama: 'A'));
      expect(await poskoRepo.cekHapus(posko), isNull);

      await repo.add(orang(posko.id!, 'Budi'));
      expect(await poskoRepo.cekHapus(posko), contains('Masih ada 1 pengungsi'));

      await repo.hapus((await repo.getByPosko(posko.id)).single);
      expect(await poskoRepo.cekHapus(posko), contains('riwayat'),
          reason: 'penghapusan pengungsi masih harus dikirim ke pusat');

      final kosong = await poskoRepo.add(Posko.baru(nama: 'Kosong'));
      SessionService.instance.startRelawan(
          const RelawanSession(nama: 'Andi', posko: 'Kosong'));
      expect(await poskoRepo.cekHapus(kosong),
          'Hanya admin yang dapat menghapus posko.');
    });
  });

  test('kode_perangkat dibuat sekali lalu tetap sama', () async {
    final store = SqliteTableStore(path: path, factory: databaseFactoryFfi);
    final kode1 = await PengaturanRepository.withStore(store).kodePerangkat();
    expect(KodeUnik.valid(kode1), isTrue);

    // Repository baru (seperti aplikasi dibuka ulang) membaca kode yang sama.
    final kode2 = await PengaturanRepository.withStore(store).kodePerangkat();
    expect(kode2, kode1);
    expect(await store.count(DatabaseTables.pengaturan), 1);
    await store.close();
  });

  test('perintah SQL KodeUnik.sql menghasilkan UUID v4 berbeda per baris',
      () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    final rows = await db.rawQuery(
      'WITH RECURSIVE n(i) AS (SELECT 1 UNION ALL SELECT i + 1 FROM n '
      'WHERE i < 500) SELECT ${KodeUnik.sql} AS kode FROM n',
    );
    final kode = rows.map((r) => r['kode'] as String).toList();
    expect(kode.every(KodeUnik.valid), isTrue, reason: kode.first);
    expect(kode.toSet(), hasLength(500));
    await db.close();
  });
}
