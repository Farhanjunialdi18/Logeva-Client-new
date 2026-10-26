// Tahap A (beberapa HP satu posko): kode unik akun, PIN tersimpan acak,
// dan login PIN yang bekerja di HP Induk maupun HP Anggota.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/database_tables.dart';
import 'package:flutter_application_1/data/repositories/admin_repository.dart';
import 'package:flutter_application_1/data/repositories/pengaturan_repository.dart';
import 'package:flutter_application_1/data/repositories/relawan_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/relawan.dart';
import 'package:flutter_application_1/utils/kode_unik.dart';
import 'package:flutter_application_1/utils/pin_hasher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

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

  group('PBKDF2-HMAC-SHA256 (contoh resmi)', () {
    test('password / salt', () {
      final p = utf8.encode('password');
      final s = utf8.encode('salt');
      expect(hex(PinHasher.pbkdf2(p, s, 1)),
          '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b');
      expect(hex(PinHasher.pbkdf2(p, s, 2)),
          'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43');
      expect(hex(PinHasher.pbkdf2(p, s, 4096)),
          'c5e478d59288c841aa530db6845c4c8d962893a001ce4e11a4963873aa98134a');
    });

    test('hash PIN: sama untuk salt sama, beda untuk salt lain', () {
      expect(PinHasher.hash('123456', 'a'), PinHasher.hash('123456', 'a'));
      expect(PinHasher.hash('123456', 'a'), isNot(PinHasher.hash('123456', 'b')));
      expect(PinHasher.hash('123456', 'a'), isNot(PinHasher.hash('123457', 'a')));
      expect(PinHasher.hash('123456', 'a'), isNot(contains('123456')));
    });
  });

  late Directory folder;
  late String path;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_akun_');
    path = '${folder.path}/logeva.db';
  });

  tearDown(() async => folder.delete(recursive: true));

  test('upgrade v7 -> v8: akun lama tetap ada & bisa login dengan PIN', () async {
    final lama = await bukaVersiLama(path, 7);
    const t = '2026-10-01T08:00:00.000';
    await lama.insert(DatabaseTables.relawan, {
      'nama': 'Andi', 'pin': '111111', 'kontak': '0812', 'status': 'Aktif',
      'posko': 'X', 'dibuat_pada': t,
    });
    await lama.insert(DatabaseTables.relawan, {
      'nama': 'Siti', 'pin': '222222', 'status': 'Nonaktif', 'dibuat_pada': t,
    });
    await lama.insert(DatabaseTables.admin, {
      'nama': 'Admin', 'username': 'admin', 'email': 'a@x.id',
      'password_hash': 'h', 'password_salt': 's', 'dibuat_pada': t,
    });
    await lama.close();

    final store = SqliteTableStore(path: path, factory: databaseFactoryFfi);
    final repo = RelawanRepository.withStore(store);
    final semua = await repo.getAll();
    expect(semua.map((r) => r.nama).toSet(), {'Andi', 'Siti'});
    expect(semua.every((r) => KodeUnik.valid(r.kode)), isTrue);
    expect(semua.map((r) => r.kode).toSet(), hasLength(2));
    final andi = semua.firstWhere((r) => r.nama == 'Andi');
    expect(andi.pin, '111111', reason: 'PIN asli tetap ada di HP Induk');
    expect(andi.kontak, '0812');
    expect(andi.diubahPada, DateTime.parse(t));
    expect(semua.firstWhere((r) => r.nama == 'Siti').isAktif, isFalse);

    // Login PIN tetap jalan (hash dilengkapi otomatis saat pertama dipakai).
    expect((await repo.findByPin('111111'))?.nama, 'Andi');
    expect(await repo.findByPin('999999'), isNull);
    expect((await repo.getAll()).every((r) => r.pinHash.isNotEmpty), isTrue);

    final admin = (await AdminRepository.withStore(store).getAll()).single;
    expect(KodeUnik.valid(admin.kode), isTrue);
    expect(admin.diubahPada, DateTime.parse(t));
    await store.close();
  });

  group('akun', () {
    late SqliteTableStore store;
    late RelawanRepository repo;

    setUp(() {
      store = SqliteTableStore(path: path, factory: databaseFactoryFfi);
      repo = RelawanRepository.withStore(store);
    });
    tearDown(() async => store.close());

    test('relawan baru: kode unik, PIN tersimpan juga dalam bentuk acak', () async {
      final r = await repo.add(
          Relawan(nama: 'Andi', pin: '123456', dibuatPada: DateTime(2026)));
      expect(KodeUnik.valid(r.kode), isTrue);
      expect(r.pinHash, isNotEmpty);
      expect(r.pinHash, isNot(contains('123456')));
      expect((await repo.findByPin('123456'))?.kode, r.kode);
    });

    test('HP Anggota: akun tanpa PIN asli tetap bisa login lewat hash', () async {
      // Simulasi HP Anggota: salt dari HP Induk, PIN asli tidak disimpan.
      const saltInduk = 'salt-dari-hp-induk';
      final pengaturan = PengaturanRepository.withStore(store);
      await pengaturan.set(PengaturanRepository.kunciSaltPin, saltInduk);
      await pengaturan.setPeranPerangkat(PengaturanRepository.peranAnggota);
      for (final (nama, pin) in [('Andi', '111111'), ('Budi', '222222')]) {
        await store.insert(DatabaseTables.relawan, Relawan(
          kode: KodeUnik.buat(),
          nama: nama,
          pin: '', // tidak ada PIN asli di HP Anggota
          pinHash: PinHasher.hash(pin, saltInduk),
          dibuatPada: DateTime(2026),
        ).toMap());
      }

      expect(await pengaturan.isAnggota(), isTrue);
      expect((await repo.findByPin('222222'))?.nama, 'Budi');
      expect(await repo.findByPin('333333'), isNull);
      final andi = (await repo.findByPin('111111'))!;
      expect(andi.pinTerlihat, isFalse, reason: 'PIN asli tidak bisa dilihat');

      // PIN baru dari HP ini tidak boleh sama dengan PIN akun yang hanya punya hash.
      final pin = await repo.generateUniquePin();
      expect(['111111', '222222'], isNot(contains(pin)));
    });

    test('login tidak mengubah diubah_pada; edit oleh admin mengubahnya', () async {
      final r = await repo.add(
          Relawan(nama: 'Andi', pin: '123456', dibuatPada: DateTime(2026)));
      final sebelum = (await repo.findById(r.id!))!.diubahPada;

      await repo.markLogin((await repo.findById(r.id!))!);
      final setelahLogin = (await repo.findById(r.id!))!;
      expect(setelahLogin.terakhirLogin, isNotNull);
      expect(setelahLogin.diubahPada, sebelum);

      await Future<void>.delayed(const Duration(milliseconds: 5));
      await repo.update(setelahLogin.copyWith(status: DataOptions.statusNonaktif));
      expect((await repo.findById(r.id!))!.diubahPada.isAfter(sebelum), isTrue);
    });

    test('ganti PIN: PIN lama tidak bisa login lagi', () async {
      final r = await repo.add(
          Relawan(nama: 'Andi', pin: '123456', dibuatPada: DateTime(2026)));
      final baru = await repo.regeneratePin(r);
      expect(baru.pin, isNot('123456'));
      expect(await repo.findByPin('123456'), isNull);
      expect((await repo.findByPin(baru.pin))?.kode, r.kode);
    });

    test('admin baru punya kode unik', () async {
      final admin = AdminRepository.withStore(store);
      await admin.ensureDefaultAdmin();
      expect(KodeUnik.valid((await admin.getAll()).single.kode), isTrue);
    });
  });
}
