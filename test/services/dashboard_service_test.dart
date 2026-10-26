// Dashboard Grafik: angka ringkasan, komposisi, keterisian, tren 7 hari,
// dan status stok dihitung dari data yang sama dengan layar lain.

import 'dart:io';

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/repositories/barang_repository.dart';
import 'package:flutter_application_1/data/repositories/logistik_repository.dart';
import 'package:flutter_application_1/data/repositories/pengungsi_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/catatan_logistik.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/services/dashboard_service.dart';
import 'package:flutter_application_1/services/kebutuhan_service.dart';
import 'package:flutter_application_1/utils/waktu_wib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late SqliteTableStore s;
  late Posko a, b;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_dashboard_');
    s = SqliteTableStore(path: '${folder.path}/hp.db', factory: databaseFactoryFfi);
    final posko = PoskoRepository.withStore(s);
    a = await posko.add(Posko.baru(nama: 'A', luasLokasi: 35)); // kapasitas 10
    a = await posko.ubahStatus(a, AksiOperasional.mulai);
    b = await posko.add(Posko.baru(nama: 'B', luasLokasi: 1050)); // kapasitas 300

    final hariIni = WaktuWib.hariIni();
    Pengungsi orang(Posko p, String nama, int umur, String jk,
            {String sakit = '', String rentan = DataOptions.bukanRentan}) =>
        Pengungsi.baru(
          poskoId: p.id,
          nama: nama,
          asal: 'X',
          tanggalLahir: DateTime(hariIni.year - umur, 1, 1),
          jenisKelamin: jk,
          kondisiKesehatan: sakit,
          kelompokRentan: rentan,
        );
    final pengungsi = PengungsiRepository.withStore(s);
    await pengungsi.add(orang(a, 'Bayi', 2, DataOptions.lakiLaki));
    await pengungsi.add(orang(a, 'Nenek', 70, DataOptions.perempuan, rentan: 'Lansia'));
    await pengungsi.add(orang(a, 'Ibu', 35, DataOptions.perempuan, sakit: 'Demam'));
    await pengungsi.add(orang(b, 'Bapak', 40, DataOptions.lakiLaki));

    final beras = (await BarangRepository.withStore(s).getAll()).first;
    final logistik = LogistikRepository.withStore(s);
    await logistik.catatMasuk(BarangMasuk.baru(
        poskoId: a.id!, barang: beras, jumlah: 50, sumberBantuan: 'BPBD', tanggal: hariIni));
    await logistik.catatKeluar(
        BarangKeluar.baru(
            poskoId: a.id!, barang: beras, jumlah: 10, tujuan: 'dibagikan', tanggal: hariIni),
        barang: beras);
  });

  tearDown(() async {
    await s.close();
    await folder.delete(recursive: true);
  });

  test('semua posko: komposisi, keterisian, tren, dan status bantuan', () async {
    final d = await DashboardService.muat(store: s);

    expect(d.posko, isNull);
    expect(d.jumlahPosko, 2);
    expect(d.poskoBeroperasi, 1);
    expect(d.komposisi.total, 4);
    expect(d.komposisi.kapasitas, 310);
    expect((d.komposisi.lakiLaki, d.komposisi.perempuan), (2, 2));
    expect(d.komposisi.usia[KebutuhanService.usiaBalita], 1);
    expect(d.komposisi.usia[KebutuhanService.usiaLansia], 1);
    expect(d.komposisi.rentan, {'Lansia': 1});
    expect((d.sehat, d.sakit), (3, 1));

    // Paling penuh dulu: A 3/10 = 30%, B 1/300 = 0%.
    expect(d.isiPosko.map((i) => (i.posko.nama, i.jumlah, i.persen)),
        [('A', 3, 30), ('B', 1, 0)]);

    expect(d.tren, hasLength(7));
    expect(d.tren.last.tanggal, WaktuWib.hariIni());
    expect((d.tren.last.pengungsiBaru, d.tren.last.barangMasuk, d.tren.last.barangKeluar),
        (4, 1, 1));
    expect(d.pengungsiBaru7Hari, 4);
    expect(d.tren.first.pengungsiBaru, 0);

    expect(d.tingkatPosko.values.fold(0, (x, y) => x + y), 1,
        reason: 'hanya posko beroperasi yang punya status bantuan');
    expect(d.statusStok.values.fold(0, (x, y) => x + y), greaterThan(0));
    expect(d.ketahanan, isEmpty, reason: 'daya tahan stok hanya untuk satu posko');
  });

  test('satu posko: hanya data posko itu, daya tahan stok terurut', () async {
    final d = await DashboardService.muat(poskoId: a.id, store: s);

    expect(d.posko?.nama, 'A');
    expect(d.jumlahPosko, 1);
    expect(d.komposisi.total, 3);
    expect(d.komposisi.kapasitas, 10);
    expect(d.isiPosko.single.persen, 30);
    expect(d.tren.last.pengungsiBaru, 3);

    final hari = d.ketahanan.map((k) => k.cukupHari!).toList();
    expect(hari, [...hari]..sort(), reason: 'paling cepat habis dulu');
  });

  test('posko kosong tidak membuat error', () async {
    final d = await DashboardService.muat(poskoId: b.id, store: s);
    expect(d.komposisi.total, 1);
    expect(d.tren.last.barangMasuk, 0);
  });
}
