// Peringatan posko: notifikasi kapasitas 80% / 100% dan stok < 7 hari,
// hanya saat batas baru terlewati (tidak berulang setiap data berubah).

import 'dart:io';

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/repositories/barang_repository.dart';
import 'package:flutter_application_1/data/repositories/logistik_repository.dart';
import 'package:flutter_application_1/data/repositories/pengungsi_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/barang.dart';
import 'package:flutter_application_1/models/catatan_logistik.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/services/notifikasi_service.dart';
import 'package:flutter_application_1/services/peringatan_service.dart';
import 'package:flutter_application_1/utils/waktu_wib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late SqliteTableStore s;
  late Posko posko;
  final terkirim = <(int, String, String)>[];

  Future<void> tambah(int n) async {
    final repo = PengungsiRepository.withStore(s);
    for (var i = 0; i < n; i++) {
      await repo.add(Pengungsi.baru(
        poskoId: posko.id,
        nama: 'Orang ${DateTime.now().microsecondsSinceEpoch}',
        asal: 'X',
        tanggalLahir: DateTime(1990, 1, 1),
        jenisKelamin: DataOptions.lakiLaki,
      ));
    }
  }

  Future<List<String>> periksa() async {
    terkirim.clear();
    await PeringatanService.periksa(store: s);
    return terkirim.map((t) => t.$2).toList();
  }

  /// Isi semua barang pokok untuk [hari] hari.
  Future<List<Barang>> isiStok(int hari) async {
    final jumlah = await PengungsiRepository.withStore(s).count(poskoId: posko.id);
    final pokok = (await BarangRepository.withStore(s).getAll())
        .where((b) => (b.kebutuhanHarian ?? 0) > 0)
        .toList();
    for (final b in pokok) {
      await LogistikRepository.withStore(s).catatMasuk(BarangMasuk.baru(
          poskoId: posko.id!,
          barang: b,
          jumlah: (b.kebutuhanHarian! * jumlah * hari).ceil(),
          sumberBantuan: 'BPBD',
          tanggal: WaktuWib.hariIni()));
    }
    return pokok;
  }

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_peringatan_');
    s = SqliteTableStore(path: '${folder.path}/hp.db', factory: databaseFactoryFfi);
    final repo = PoskoRepository.withStore(s);
    posko = await repo.add(Posko.baru(nama: 'Balai Desa', luasLokasi: 35)); // 10 orang
    posko = await repo.ubahStatus(posko, AksiOperasional.mulai);
    NotifikasiService.tangkapUntukTes = (id, judul, isi) => terkirim.add((id, judul, isi));
  });

  tearDown(() async {
    NotifikasiService.tangkapUntukTes = null;
    await s.close();
    await folder.delete(recursive: true);
  });

  test('kapasitas: 80% lalu 100%, sekali saja, muncul lagi setelah turun', () async {
    await tambah(7);
    await isiStok(30); // stok aman, supaya hanya kapasitas yang diuji
    expect(await periksa(), isEmpty, reason: '70% masih aman');

    await tambah(1);
    expect(await periksa(), ['Posko Balai Desa hampir penuh']);
    expect(terkirim.single.$3, '8/10 orang (80%), sisa 2 tempat.');
    expect(await periksa(), isEmpty, reason: 'tidak berulang');
    await tambah(1);
    expect(await periksa(), isEmpty, reason: '90% masih tingkat yang sama');

    await tambah(1);
    expect(await periksa(), ['Posko Balai Desa sudah penuh']);
    expect(terkirim.single.$3, contains('Arahkan pengungsi baru ke posko lain'));
    await tambah(2);
    expect(await periksa(), isEmpty, reason: 'lebih dari penuh tetap tingkat penuh');

    // Pengungsi pindah: turun ke 50%, lalu naik lagi ke 80% -> diberi tahu lagi.
    final repo = PengungsiRepository.withStore(s);
    for (final p in (await repo.getByPosko(posko.id)).take(7)) {
      await repo.hapus(p);
    }
    expect(await periksa(), isEmpty);
    await tambah(3);
    expect(await periksa(), ['Posko Balai Desa hampir penuh']);
  });

  test('stok kurang dari 7 hari & habis', () async {
    await tambah(4);
    final pokok = await isiStok(10);
    expect(pokok, isNotEmpty, reason: 'master barang bawaan punya kebutuhan harian');
    expect(await periksa(), isEmpty, reason: 'stok cukup 10 hari');

    // Satu barang dikeluarkan sampai tersisa sekitar 2 hari.
    final b = pokok.first;
    final perHari = b.kebutuhanHarian! * 4;
    final sisa = (perHari * 2).ceil();
    final stok = await LogistikRepository.withStore(s).stokBarang(posko.id!, b.id!);
    await LogistikRepository.withStore(s).catatKeluar(
        BarangKeluar.baru(
            poskoId: posko.id!, barang: b, jumlah: stok - sisa,
            tujuan: 'dibagikan', tanggal: WaktuWib.hariIni()),
        barang: b);
    expect(await periksa(), ['Stok Posko Balai Desa kurang dari 7 hari']);
    expect(terkirim.single.$3, startsWith('${b.namaItem} ('));
    expect(terkirim.single.$3, contains('Ajukan bantuan logistik'));
    expect(await periksa(), isEmpty, reason: 'tidak berulang');

    // Habis -> diberi tahu lagi (lebih parah).
    await LogistikRepository.withStore(s).catatKeluar(
        BarangKeluar.baru(
            poskoId: posko.id!, barang: b, jumlah: sisa,
            tujuan: 'dibagikan', tanggal: WaktuWib.hariIni()),
        barang: b);
    expect(await periksa(), ['Stok habis di Posko Balai Desa']);
    expect(terkirim.single.$3, contains('sudah habis'));

    // Bantuan datang: peringatan hilang dari keadaan sekarang.
    await isiStok(10);
    final w = (await PeringatanService.keadaan(store: s)).single;
    expect(w.adaStok, isFalse);
  });

  test('posko tidak beroperasi: hanya kapasitas yang diperiksa', () async {
    posko = await PoskoRepository.withStore(s).ubahStatus(posko, AksiOperasional.tutup);
    await tambah(9);
    expect(await periksa(), ['Posko Balai Desa hampir penuh'],
        reason: 'stok kosong tidak diperingatkan karena posko tidak beroperasi');
  });
}
