// Tes logistik: migrasi data lama (v6 -> v7), aturan stok, master barang.

import 'dart:io';

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/database_tables.dart';
import 'package:flutter_application_1/data/repositories/barang_repository.dart';
import 'package:flutter_application_1/data/repositories/logistik_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/admin.dart';
import 'package:flutter_application_1/models/barang.dart';
import 'package:flutter_application_1/models/catatan_logistik.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/services/session_service.dart';
import 'package:flutter_application_1/utils/kode_unik.dart';
import 'package:flutter_application_1/utils/waktu_wib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
    folder = await Directory.systemTemp.createTemp('logeva_logistik_');
    path = '${folder.path}/logeva.db';
  });

  tearDown(() async => folder.delete(recursive: true));

  test('instalasi baru: 10 kategori & barang awal sama dengan website',
      () async {
    final store = SqliteTableStore(path: path, factory: databaseFactoryFfi);
    final repo = BarangRepository.withStore(store);
    final kategori = await repo.getKategori();
    expect(kategori.map((k) => k.nama), DataOptions.kategoriLogistik);
    expect(kategori.first.id, 1);

    final barang = await repo.getAll();
    // Daftar baku = sama dengan website (MasterLogistikBaku).
    expect(barang.map((b) => b.namaItem).toSet(),
        DataOptions.barangAwal.map((e) => e.$1).toSet());
    Barang cari(String n) => barang.firstWhere((b) => b.namaItem == n);
    expect(cari('Beras').kategori, 'Makanan');
    expect(cari('Beras').satuan, 'kg');
    expect(cari('Beras').kebutuhanHarian, 0.3);
    expect(cari('Air Mineral').kebutuhanHarian, 2);
    expect(cari('Baju').kebutuhanHarian, isNull, reason: 'pakaian bukan kebutuhan harian');
    expect(barang.where((b) => b.isPokok).map((b) => b.namaItem).toSet(),
        {'Beras', 'Air Mineral'});
    await store.close();
  });

  test('upgrade v6 -> v7: logistik lama jadi master + saldo awal', () async {
    final lama = await bukaVersiLama(path, 6);
    const t = '2026-10-01T08:00:00.000';
    final poskoId = await lama.insert(DatabaseTables.posko, {
      'nama': 'Cisolok',
      'alamat': '',
      'dibuat_pada': t,
      'kode': '00000000-0000-4000-8000-000000000000',
    });
    Future<void> tambah(String nama, String kategori, int jumlah, String satuan,
        {String posko = 'Cisolok'}) {
      return lama.insert(DatabaseTables.logistik, {
        'nama_barang': nama,
        'kategori': kategori,
        'jumlah': jumlah,
        'satuan': satuan,
        'posko': posko,
        'dibuat_pada': t,
      });
    }

    await tambah('beras', 'Makanan', 25, 'Karung'); // = Beras bawaan
    await tambah('Beras', 'Makanan', 5, 'Kg');
    await tambah('Selimut', 'Perlengkapan', 40, 'Buah');
    await tambah('Paracetamol', 'Obat-obatan', 10, 'Strip');
    await tambah('Terpal', 'Alat', 3, 'Lembar'); // kategori tak dikenal
    await tambah('Sarden', 'Makanan', 0, 'Kaleng'); // jumlah 0
    await tambah('Mi Instan', 'Makanan', 7, 'Dus', posko: '-');
    await lama.close();

    final store = SqliteTableStore(path: path, factory: databaseFactoryFfi);
    final barang = await BarangRepository.withStore(store).getAll();
    Barang cari(String nama) =>
        barang.firstWhere((b) => b.namaItem.toLowerCase() == nama.toLowerCase());

    expect(barang.where((b) => b.namaItem.toLowerCase() == 'beras'),
        hasLength(1), reason: 'tidak dobel dengan Beras bawaan');
    expect(cari('Beras').satuan, 'kg');
    expect(cari('Selimut').kategori, 'Perlengkapan Tidur');
    expect(cari('Selimut').satuan, 'lembar', reason: 'satuan baku (versi 10)');
    expect(cari('Paracetamol').kategori, 'Medis');
    expect(cari('Terpal').kategori, 'Lainnya');
    expect(cari('Sarden').kategori, 'Makanan',
        reason: 'barang tetap masuk master walau jumlahnya 0');

    final logistik = LogistikRepository.withStore(store);
    final masuk = await logistik.getMasuk();
    expect(masuk, hasLength(6), reason: 'baris jumlah 0 tidak jadi catatan');
    expect(masuk.every((m) => KodeUnik.valid(m.kode)), isTrue);
    expect(masuk.map((m) => m.kode).toSet(), hasLength(6));
    expect(masuk.first.sumberBantuan, 'Saldo awal (data aplikasi lama)');
    expect(masuk.every((m) => m.tanggal == DateTime(2026, 10, 1)), isTrue);

    final karung = masuk.firstWhere((m) => m.jumlah == 25);
    expect(karung.keterangan, contains('satuan lama: Karung'));
    final kg = masuk.firstWhere((m) => m.jumlah == 5);
    expect(kg.keterangan, isNot(contains('satuan lama')));

    final stok = {
      for (final s in await logistik.getStok(poskoId)) s.barang.namaItem: s.jumlah,
    };
    expect(stok['Beras'], 30);
    expect(stok['Selimut'], 40);
    expect(stok.containsKey('Mi Instan'), isFalse, reason: 'tanpa posko');
    expect((await logistik.getMasuk()).where((m) => m.poskoId == null),
        hasLength(1));

    // Tabel lama disimpan sebagai arsip.
    expect(await store.count(DatabaseTables.logistikLama), 7);
    await store.close();
  });

  group('stok & catatan', () {
    late SqliteTableStore store;
    late LogistikRepository repo;
    late Posko posko;
    late Barang beras;

    setUp(() async {
      store = SqliteTableStore(path: path, factory: databaseFactoryFfi);
      repo = LogistikRepository.withStore(store);
      posko = await PoskoRepository.withStore(store).add(Posko.baru(nama: 'A'));
      beras = (await BarangRepository.withStore(store).getAll()).first;
    });

    tearDown(() async {
      SessionService.instance.clear();
      await store.close();
    });

    BarangMasuk masuk(int jumlah, {DateTime? tanggal}) => BarangMasuk.baru(
          poskoId: posko.id!,
          barang: beras,
          jumlah: jumlah,
          sumberBantuan: 'BNPB',
          tanggal: tanggal ?? WaktuWib.hariIni(),
        );

    BarangKeluar keluar(int jumlah) => BarangKeluar.baru(
          poskoId: posko.id!,
          barang: beras,
          jumlah: jumlah,
          tujuan: 'dibagikan',
          tanggal: WaktuWib.hariIni(),
        );

    test('stok = masuk − keluar', () async {
      await repo.catatMasuk(masuk(20));
      await repo.catatMasuk(masuk(5));
      await repo.catatKeluar(keluar(8), barang: beras);
      expect(await repo.stokBarang(posko.id!, beras.id!), 17);
      final stok = await repo.getStok(posko.id);
      expect(stok.single.jumlah, 17);
      expect(stok.single.terakhirDiperbarui, isNotNull);
      expect(await repo.getCatatan(poskoId: posko.id), hasLength(3));
    });

    test('keluar melebihi stok ditolak dengan pesan website', () async {
      await expectLater(
        repo.catatKeluar(keluar(1), barang: beras),
        throwsA(isA<LogistikException>().having(
            (e) => e.message, 'pesan', 'Stok barang ini sudah habis.')),
      );
      await repo.catatMasuk(masuk(3));
      await expectLater(
        repo.catatKeluar(keluar(4), barang: beras),
        throwsA(isA<LogistikException>().having((e) => e.message, 'pesan',
            'Stok tidak cukup. Sisa stok hanya 3 kg.')),
      );
      expect(await repo.stokBarang(posko.id!, beras.id!), 3);
    });

    test('tanggal setelah hari ini & jumlah 0 ditolak', () async {
      final besok = WaktuWib.hariIni().add(const Duration(days: 1));
      await expectLater(repo.catatMasuk(masuk(1, tanggal: besok)),
          throwsA(isA<LogistikException>()));
      await expectLater(
          repo.catatMasuk(masuk(0)), throwsA(isA<LogistikException>()));
    });

    test('barang pokok ikut walau belum pernah masuk (stok 0)', () async {
      expect(await repo.getStok(posko.id), isEmpty);
      final pokok = await repo.getStok(posko.id, termasukPokok: true);
      expect(pokok.map((s) => s.barang.namaItem), ['Beras', 'Air Mineral']);
      expect(pokok.every((s) => s.jumlah == 0), isTrue);
    });

    test('barang & posko yang punya catatan tidak bisa dihapus', () async {
      final barangRepo = BarangRepository.withStore(store);
      // Barang baku pusat tidak boleh dihapus dari HP.
      expect(await barangRepo.cekHapus(beras), contains('Master Logistik pusat'));
      await expectLater(barangRepo.delete(beras.id!), throwsA(isA<BarangException>()));

      // Barang buatan sendiri: boleh dihapus selama belum ada catatan.
      await barangRepo.add(Barang.baru(kategoriId: 10, namaItem: 'Terpal', satuan: 'lembar'));
      final terpal = (await barangRepo.getAll()).firstWhere((b) => b.namaItem == 'Terpal');
      expect(await barangRepo.cekHapus(terpal), isNull);
      await repo.catatMasuk(BarangMasuk.baru(
          poskoId: posko.id!, barang: terpal, jumlah: 3, sumberBantuan: 'BPBD',
          tanggal: DateTime(2026, 10, 20)));
      expect(await barangRepo.cekHapus(terpal), contains('catatan masuk/keluar'));
      await expectLater(barangRepo.delete(terpal.id!), throwsA(isA<BarangException>()),
          reason: 'catatan & stok tidak boleh ikut hilang');
      expect((await barangRepo.getAll()).any((b) => b.namaItem == 'Terpal'), isTrue);

      await repo.catatMasuk(masuk(1));

      SessionService.instance.startAdmin(Admin(
        nama: 'Admin',
        username: 'admin',
        email: 'a@x.id',
        passwordHash: '',
        passwordSalt: '',
        dibuatPada: DateTime(2026),
      ));
      expect(await PoskoRepository.withStore(store).cekHapus(posko),
          contains('catatan barang'));
    });

    test('barang sama = kategori + nama tanpa beda huruf', () async {
      final barangRepo = BarangRepository.withStore(store);
      await expectLater(
        barangRepo.add(Barang.baru(kategoriId: 1, namaItem: 'BERAS', satuan: 'kg')),
        throwsA(isA<BarangException>()),
      );
      // Nama sama di kategori lain boleh (aturan website).
      await barangRepo
          .add(Barang.baru(kategoriId: 8, namaItem: 'Beras', satuan: 'kg'));
      expect(await barangRepo.count(), DataOptions.barangAwal.length + 1);
    });
  });
}
