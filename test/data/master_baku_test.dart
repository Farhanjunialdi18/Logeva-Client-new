// Master barang disamakan dengan website (DB versi 10): daftar baku,
// Air Mineral 2 liter, pakaian tanpa kebutuhan harian, dan "Pakaian Layak
// Pakai" digabung ke "Baju" (catatan ikut pindah, nama lama tetap dikenali).

import 'dart:io';

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/database_tables.dart';
import 'package:flutter_application_1/data/repositories/barang_repository.dart';
import 'package:flutter_application_1/data/repositories/logistik_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late String path;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_master_');
    path = '${folder.path}/hp.db';
  });
  tearDown(() async {
    try {
      await folder.delete(recursive: true);
    } catch (_) {}
  });

  test('upgrade v9 -> v10: HP lama dirapikan sesuai master pusat', () async {
    // HP versi lama: daftar bawaan lama + barang buatan admin HP.
    final lama = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 9,
          onCreate: (db, _) async {
            for (var v = 1; v <= 9; v++) {
              for (final sql in DatabaseTables.upgradeSteps[v]!) {
                await db.execute(sql);
              }
            }
          },
        ));
    const t = '2026-10-20T08:00:00.000';
    // Keadaan HP lama: bawaan dulu hanya Beras & Air Mineral (3 liter),
    // admin HP menambah Pakaian Layak Pakai & Terpal sendiri.
    await lama.delete(DatabaseTables.barang,
        where: "nama_item NOT IN ('Beras', 'Air Mineral')");
    await lama.update(DatabaseTables.barang, {'kebutuhan_harian': 3},
        where: 'nama_item = ?', whereArgs: ['Air Mineral']);
    final plp = await lama.insert(DatabaseTables.barang, {
      'kategori_id': 3, 'nama_item': 'Pakaian Layak Pakai', 'satuan': 'paket',
      'dibuat_pada': t, 'diubah_pada': t,
    });
    await lama.insert(DatabaseTables.barangMasuk, {
      'kode': '11111111-1111-4111-8111-111111111111', 'posko_id': 1, 'barang_id': plp,
      'jumlah_masuk': 15, 'sumber_bantuan': 'BPBD', 'tanggal_masuk': '2026-10-20',
      'dibuat_pada': t,
    });
    await lama.insert(DatabaseTables.barang, {
      'kategori_id': 10, 'nama_item': 'Terpal', 'satuan': 'lembar',
      'dibuat_pada': t, 'diubah_pada': t,
    });
    await lama.close();

    final s = SqliteTableStore(path: path, factory: databaseFactoryFfi);
    final barang = await BarangRepository.withStore(s).getAll();
    final nama = barang.map((b) => b.namaItem).toSet();
    expect(nama, containsAll(DataOptions.barangAwal.map((e) => e.$1)));
    expect(nama, isNot(contains('Pakaian Layak Pakai')));
    expect(nama, contains('Terpal'), reason: 'barang buatan sendiri tidak dihapus');

    final baju = barang.firstWhere((b) => b.namaItem == 'Baju');
    expect((baju.satuan, baju.kebutuhanHarian), ('potong', null));
    expect(barang.firstWhere((b) => b.namaItem == 'Air Mineral').kebutuhanHarian, 2);

    final masuk = (await LogistikRepository.withStore(s).getMasuk()).single;
    expect(masuk.barangId, baju.id, reason: 'catatan Pakaian Layak Pakai pindah ke Baju');
    await s.close();
  });

  test('nama lama dikenali', () {
    expect(DataOptions.namaBakuBarang('Pakaian  layak PAKAI'), 'Baju');
    expect(DataOptions.namaBakuBarang('Selimut'), 'Selimut');
  });
}
