// Cadangan & pemulihan: HP baru menjadi sama persis dengan HP asal
// (data, akun, peran, kode perangkat); gagal = data lama tetap utuh.

import 'dart:io';

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/database_tables.dart';
import 'package:flutter_application_1/data/repositories/admin_repository.dart';
import 'package:flutter_application_1/data/repositories/pengaturan_repository.dart';
import 'package:flutter_application_1/data/repositories/pengungsi_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/services/cadangan_service.dart';
import 'package:flutter_application_1/utils/password_hasher.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late SqliteTableStore asal, baru;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_cadangan_');
    asal = SqliteTableStore(path: '${folder.path}/asal.db', factory: databaseFactoryFfi);
    baru = SqliteTableStore(path: '${folder.path}/baru.db', factory: databaseFactoryFfi);

    final admin = AdminRepository.withStore(asal);
    await admin.ensureDefaultAdmin();
    await admin.gantiPassword((await admin.getAll()).single, 'posko2026');
    await PengaturanRepository.withStore(asal).setKataSandiBerkas('posko2026');
    final posko = await PoskoRepository.withStore(asal).add(Posko.baru(nama: 'Balai Desa'));
    for (final nama in ['Siti', 'Budi']) {
      await PengungsiRepository.withStore(asal).add(Pengungsi.baru(
          poskoId: posko.id, nama: nama, asal: 'X',
          tanggalLahir: DateTime(1980), jenisKelamin: DataOptions.perempuan));
    }
  });

  tearDown(() async {
    await asal.close();
    await baru.close();
    await folder.delete(recursive: true);
  });

  test('cadangan dipulihkan di HP baru: data, akun, dan kode perangkat sama', () async {
    final kodeAsal = await PengaturanRepository.withStore(asal).kodePerangkat();
    final (nama, bytes) = await CadanganService.buat(store: asal);
    expect(nama, startsWith('cadangan_logeva_'));

    expect(() => CadanganService.baca(bytes),
        throwsA(isA<CadanganException>().having((e) => e.perluKataSandi, 'perlu kata sandi', isTrue)));
    expect(() => CadanganService.baca(bytes, kataSandi: 'salah123'),
        throwsA(isA<CadanganException>().having((e) => e.message, 'pesan', 'Kata sandi posko salah.')));
    final file = CadanganService.baca(bytes, kataSandi: 'posko2026');
    expect(file.namaPosko, ['Balai Desa']);
    expect(file.jumlahPengungsiAktif, 2);
    expect(file.dariAnggota, isFalse);

    await PoskoRepository.withStore(baru).add(Posko.baru(nama: 'Data lama di HP baru'));
    await CadanganService.pulihkan(file, store: baru);

    expect((await PoskoRepository.withStore(baru).getAll()).map((p) => p.nama),
        ['Balai Desa'], reason: 'data lama di HP baru diganti seluruhnya');
    final orang = await PengungsiRepository.withStore(baru).getAll();
    expect(orang.map((p) => p.nama).toSet(), {'Siti', 'Budi'});
    expect(orang.map((p) => (p.id, p.kode)).toSet(),
        (await PengungsiRepository.withStore(asal).getAll()).map((p) => (p.id, p.kode)).toSet(),
        reason: 'id & kode sama, jadi sinkron/paket tidak membuat dobel');

    final admin = (await AdminRepository.withStore(baru).getAll()).single;
    expect(PasswordHasher.verify('posko2026', hash: admin.passwordHash, salt: admin.passwordSalt),
        isTrue);
    expect(await PengaturanRepository.withStore(baru).kodePerangkat(), kodeAsal);

    // Data baru setelah pemulihan mendapat id baru (tidak bentrok).
    await PoskoRepository.withStore(baru).add(Posko.baru(nama: 'Posko baru'));
    expect(await baru.count(DatabaseTables.posko), 2);
  });

  test('pemulihan gagal di tengah: data HP tidak berubah', () async {
    final (_, bytes) = await CadanganService.buat(store: asal);
    final file = CadanganService.baca(bytes, kataSandi: 'posko2026');
    // Rusak: kolom yang tidak ada di tabel pengungsi.
    file.tabel[DatabaseTables.pengungsi]!.first['kolom_aneh'] = 1;

    await PoskoRepository.withStore(baru).add(Posko.baru(nama: 'Tetap ada'));
    await expectLater(CadanganService.pulihkan(file, store: baru),
        throwsA(isA<CadanganException>()));
    expect((await PoskoRepository.withStore(baru).getAll()).map((p) => p.nama), ['Tetap ada']);
  });

  test('tanpa kata sandi posko cadangan belum bisa dibuat', () async {
    await PengaturanRepository.withStore(asal).setKataSandiBerkas('');
    await expectLater(CadanganService.buat(store: asal),
        throwsA(isA<CadanganException>().having((e) => e.message, 'pesan', contains('Kata Sandi Posko'))));
  });

  test('file bukan cadangan ditolak dengan pesan jelas', () {
    expect(() => CadanganService.baca([1, 2, 3]),
        throwsA(isA<CadanganException>()
            .having((e) => e.message, 'pesan', contains('bukan file cadangan'))));
  });
}
