// Tahap E: barang keluar di HP Anggota boleh melebihi stok HP itu (setelah
// konfirmasi), lalu stok minus ditandai & beres setelah sinkron.

import 'dart:io';

import 'package:flutter_application_1/data/repositories/admin_repository.dart';
import 'package:flutter_application_1/data/repositories/barang_repository.dart';
import 'package:flutter_application_1/data/repositories/logistik_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/barang.dart';
import 'package:flutter_application_1/models/catatan_logistik.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/services/kebutuhan_service.dart';
import 'package:flutter_application_1/services/penyiapan_service.dart';
import 'package:flutter_application_1/services/sinkron_service.dart';
import 'package:flutter_application_1/utils/waktu_wib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late SqliteTableStore induk, anggota;

  Future<Posko> poskoDi(SqliteTableStore s) async =>
      (await PoskoRepository.withStore(s).getAll()).single;
  Future<Barang> berasDi(SqliteTableStore s) async =>
      (await BarangRepository.withStore(s).getAll()).first;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_stok_');
    induk = SqliteTableStore(path: '${folder.path}/induk.db', factory: databaseFactoryFfi);
    anggota = SqliteTableStore(path: '${folder.path}/anggota.db', factory: databaseFactoryFfi);
    final admin = AdminRepository.withStore(induk);
    await admin.ensureDefaultAdmin();
    await admin.gantiPassword((await admin.getAll()).single, 'posko2026');
    final posko = await PoskoRepository.withStore(induk).add(Posko.baru(nama: 'A'));
    final (_, f) = await PenyiapanService.buat(posko, store: induk);
    await PenyiapanService.terapkan(PenyiapanService.baca(f), store: anggota);
  });

  tearDown(() async {
    await induk.close();
    await anggota.close();
    await folder.delete(recursive: true);
  });

  Future<BarangKeluar> keluar(SqliteTableStore s, int jumlah) async => BarangKeluar.baru(
        poskoId: (await poskoDi(s)).id!, barang: await berasDi(s), jumlah: jumlah,
        tujuan: 'dibagikan', tanggal: WaktuWib.hariIni());

  Future<int> stok(SqliteTableStore s) async => LogistikRepository.withStore(s)
      .stokBarang((await poskoDi(s)).id!, (await berasDi(s)).id!);

  test('melebihi stok: ditolak biasa, boleh setelah konfirmasi (HP Anggota)', () async {
    final repo = LogistikRepository.withStore(anggota);
    final beras = await berasDi(anggota);
    await expectLater(repo.catatKeluar(await keluar(anggota, 10), barang: beras),
        throwsA(isA<LogistikException>()));
    await repo.catatKeluar(await keluar(anggota, 10),
        barang: beras, izinkanMelebihiStok: true);
    expect(await stok(anggota), -10);
    expect((await repo.stokMinus((await poskoDi(anggota)).id)).single.jumlah, -10);
  });

  test('HP Anggota: semua barang master bisa dipilih walau stok 0', () async {
    final semua = await LogistikRepository.withStore(anggota)
        .getStok((await poskoDi(anggota)).id, semuaBarang: true);
    expect(semua.map((s) => s.barang.namaItem), containsAll(['Beras', 'Air Mineral']));
    expect(semua.every((s) => s.jumlah == 0), isTrue);
  });

  test('barang masuk di HP Induk + keluar di HP Anggota: setelah sinkron stok benar',
      () async {
    final repoInduk = LogistikRepository.withStore(induk);
    await repoInduk.catatMasuk(BarangMasuk.baru(
        poskoId: (await poskoDi(induk)).id!, barang: await berasDi(induk), jumlah: 30,
        sumberBantuan: 'BPBD', tanggal: WaktuWib.hariIni()));
    // Relawan membagikan 10 sebelum sinkron (stok di HP Anggota masih 0).
    await LogistikRepository.withStore(anggota).catatKeluar(await keluar(anggota, 10),
        barang: await berasDi(anggota), izinkanMelebihiStok: true);
    expect(await stok(anggota), -10);

    await SinkronService.terapkan(
        (await SinkronService.buatFile(await poskoDi(anggota), store: anggota)).$2,
        store: induk);
    await SinkronService.terapkan(
        (await SinkronService.buatFile(await poskoDi(induk), store: induk)).$2,
        store: anggota);

    expect(await stok(induk), 20);
    expect(await stok(anggota), 20);
    expect(await repoInduk.stokMinus((await poskoDi(induk)).id), isEmpty);
  });

  test('stok minus muncul sebagai tugas prioritas tinggi', () async {
    await LogistikRepository.withStore(induk).catatKeluar(await keluar(induk, 5),
        barang: await berasDi(induk), izinkanMelebihiStok: true);
    final stokPosko = KebutuhanService.hitung(
      await LogistikRepository.withStore(induk)
          .getStok((await poskoDi(induk)).id, termasukPokok: true),
      0,
    );
    final tugas = KebutuhanService.tugasHariIni(
      stok: stokPosko,
      komposisi: KebutuhanService.komposisi([], 0),
      perhatianMedis: [],
      adaBarangKeluarHariIni: true,
    );
    final t = tugas.firstWhere((t) => t.teks.startsWith('Periksa stok minus'));
    expect(t.prioritas, PrioritasTugas.tinggi);
    expect(t.keterangan, contains('Beras −5 kg'));
  });
}
