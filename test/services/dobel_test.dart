// Tahap F: orang yang sama dicatat di 2 HP -> HP Induk menampilkan
// kemungkinan dobel; supervisor menggabungkan / menandai bukan orang sama.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/repositories/admin_repository.dart';
import 'package:flutter_application_1/data/repositories/pengungsi_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/services/csv_service.dart';
import 'package:flutter_application_1/services/dobel_service.dart';
import 'package:flutter_application_1/services/paket_data_service.dart';
import 'package:flutter_application_1/services/penyiapan_service.dart';
import 'package:flutter_application_1/services/sinkron_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late SqliteTableStore induk, anggota;

  Future<Posko> poskoDi(SqliteTableStore s) async =>
      (await PoskoRepository.withStore(s).getAll()).first;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_dobel_');
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

  Future<void> catat(SqliteTableStore s, String nama,
      {String kk = '', String rentan = 'Tidak', DateTime? lahir, int? poskoId}) async {
    await PengungsiRepository.withStore(s).add(Pengungsi.baru(
      poskoId: poskoId ?? (await poskoDi(s)).id,
      nama: nama,
      asal: 'Cikaret',
      tanggalLahir: lahir ?? DateTime(1958, 3, 12),
      jenisKelamin: DataOptions.perempuan,
      nomorKk: kk,
      kelompokRentan: rentan,
    ));
  }

  Future<void> sinkronKeInduk() async => SinkronService.terapkan(
      (await SinkronService.buatFile(await poskoDi(anggota), store: anggota)).$2,
      store: induk);

  test('orang yang sama dari 2 HP terdeteksi & bisa digabung', () async {
    await catat(induk, 'Siti Aminah', rentan: 'Lansia');
    await catat(anggota, 'siti  aminah', kk: '3602011203580001');
    await sinkronKeInduk();

    final grup = await DobelService.cari(store: induk);
    expect(grup, hasLength(1));
    expect(grup.single.data, hasLength(2));

    final pilihan = grup.single.data.firstWhere((p) => p.nama == 'Siti Aminah');
    final duplikat = grup.single.data.firstWhere((p) => p.nama != 'Siti Aminah');
    // Paket mencatat waktu per detik; di lapangan keputusan supervisor
    // selalu beberapa detik setelah data dicatat.
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    await DobelService.gabungkan(grup.single, pilihan, store: induk);

    final aktif = await PengungsiRepository.withStore(induk).getAll();
    expect(aktif, hasLength(1));
    expect(aktif.single.kode, pilihan.kode);
    expect(aktif.single.nomorKk, '3602011203580001', reason: 'KK diambil dari duplikat');
    expect(aktif.single.kelompokRentan, 'Lansia');
    expect(await DobelService.cari(store: induk), isEmpty);

    // Hasilnya ikut ke HP Anggota lewat sinkron...
    await SinkronService.terapkan(
        (await SinkronService.buatFile(await poskoDi(induk), store: induk)).$2,
        store: anggota);
    final diAnggota = await PengungsiRepository.withStore(anggota).getAll();
    expect(diAnggota.map((p) => p.kode), [pilihan.kode]);
    expect(diAnggota.single.nomorKk, '3602011203580001');

    // ...dan ke pusat sebagai penghapusan duplikat.
    final paket = await PaketDataService.kumpulkan([await poskoDi(induk)], store: induk);
    final csv = utf8.decode(
        ZipDecoder().decodeBytes(paket.zip).findFile('pengungsi.csv')!.content);
    final baris = CsvService.decode(csv);
    expect(baris.firstWhere((r) => r['kode'] == duplikat.kode)['dihapus_pada'], isNotEmpty);
  });

  test('"bukan orang yang sama" disimpan; muncul lagi jika ada data ketiga', () async {
    await catat(induk, 'Siti');
    await catat(anggota, 'Siti');
    await sinkronKeInduk();

    final grup = (await DobelService.cari(store: induk)).single;
    await DobelService.bukanOrangYangSama(grup, store: induk);
    expect(await DobelService.cari(store: induk), isEmpty);

    // Data ketiga yang cocok: grup berubah, ditampilkan lagi.
    await catat(induk, 'SITI');
    final lagi = await DobelService.cari(store: induk);
    expect(lagi.single.data, hasLength(3));
  });

  test('beda tanggal lahir / beda posko / data lama tanpa tanggal lahir: bukan dobel',
      () async {
    final poskoA = await poskoDi(induk);
    final poskoLain = await PoskoRepository.withStore(induk).add(Posko.baru(nama: 'B'));
    await catat(induk, 'Siti', poskoId: poskoA.id);
    await catat(induk, 'Siti', lahir: DateTime(1960, 1, 1), poskoId: poskoA.id);
    await catat(induk, 'Siti', poskoId: poskoLain.id);
    await induk.insert('pengungsi', {
      'kode': '11111111-1111-4111-8111-111111111111', 'posko_id': poskoA.id, 'nama': 'Siti',
      'asal': '', 'usia': 60, 'jenis_kelamin': 'Perempuan',
      'dibuat_pada': '2026-10-01T08:00:00.000', 'diubah_pada': '2026-10-01T08:00:00.000',
    });
    expect(await DobelService.cari(store: induk), isEmpty);
  });
}
