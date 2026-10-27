// Laporan harian (teks SMS/radio): angka ringkas tanpa nama pengungsi.

import 'dart:io';

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/repositories/pengungsi_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/services/laporan_harian_service.dart';
import 'package:flutter_application_1/utils/waktu_wib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late SqliteTableStore s;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_laporan_');
    s = SqliteTableStore(path: '${folder.path}/hp.db', factory: databaseFactoryFfi);
  });
  tearDown(() async {
    await s.close();
    await folder.delete(recursive: true);
  });

  test('isi laporan satu posko', () async {
    final repo = PoskoRepository.withStore(s);
    var p = await repo.add(Posko.baru(nama: 'Balai Desa', luasLokasi: 35));
    p = await repo.ubahStatus(p, AksiOperasional.mulai);
    final orang = PengungsiRepository.withStore(s);
    final hariIni = WaktuWib.hariIni();
    for (final (nama, umur, jk, rentan) in [
      ('Siti Aminah', 70, DataOptions.perempuan, 'Lansia'),
      ('Budi', 30, DataOptions.lakiLaki, DataOptions.bukanRentan),
      ('Rahmat', 8, DataOptions.lakiLaki, DataOptions.bukanRentan),
    ]) {
      await orang.add(Pengungsi.baru(
          poskoId: p.id, nama: nama, asal: 'X',
          tanggalLahir: DateTime(hariIni.year - umur), jenisKelamin: jk, kelompokRentan: rentan));
    }
    final rahmat = (await orang.getAll()).firstWhere((e) => e.nama == 'Rahmat');
    await orang.update(rahmat.catatKeluar(DataOptions.pulang, hariIni, ''));

    final teks = await LaporanHarianService.buat(store: s, oleh: 'Andi');
    expect(teks, startsWith('LAPORAN HARIAN LOGEVA\n'));
    expect(teks, contains('== POSKO BALAI DESA =='));
    expect(teks, contains('Status: Beroperasi · hari ke-1'));
    expect(teks, contains('Pengungsi: 2/10 orang (20%), sisa 8 tempat'));
    expect(teks, contains('- Laki-laki 1, perempuan 1'));
    expect(teks, contains('- Rentan: Lansia 1'));
    expect(teks, contains('Hari ini: 3 datang, 1 keluar posko'));
    expect(teks, contains('Stok kurang dari 7 hari:'), reason: 'belum ada barang masuk');
    expect(teks, endsWith('Dilaporkan oleh: Andi'));
    expect(teks, isNot(contains('Siti')), reason: 'tanpa nama pengungsi');
  });

  test('tanpa posko', () async {
    expect(await LaporanHarianService.buat(store: s), contains('Belum ada posko.'));
  });
}
