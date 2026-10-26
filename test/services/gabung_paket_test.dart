// Tahap C: gabung Paket Data Posko antar-HP satu posko (dua database =
// dua HP). Aturan sama dengan import di website.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/repositories/admin_repository.dart';
import 'package:flutter_application_1/data/repositories/barang_repository.dart';
import 'package:flutter_application_1/data/repositories/logistik_repository.dart';
import 'package:flutter_application_1/data/repositories/pengungsi_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/catatan_logistik.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/services/gabung_paket_service.dart';
import 'package:flutter_application_1/services/paket_data_service.dart';
import 'package:flutter_application_1/services/penyiapan_service.dart';
import 'package:flutter_application_1/utils/waktu_wib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late SqliteTableStore induk;
  late SqliteTableStore anggota;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_gabung_');
    induk = SqliteTableStore(path: '${folder.path}/induk.db', factory: databaseFactoryFfi);
    anggota = SqliteTableStore(path: '${folder.path}/anggota.db', factory: databaseFactoryFfi);

    final admin = AdminRepository.withStore(induk);
    await admin.ensureDefaultAdmin();
    await admin.gantiPassword((await admin.getAll()).single, 'posko2026');
    final posko = await PoskoRepository.withStore(induk).add(Posko.baru(
      nama: 'Balai Desa', namaDesa: 'Panggarangan', alamat: 'Jl. 1',
      luasLokasi: 350, latitude: '-6.9', longitude: '106.1',
    ));
    final (_, file) = await PenyiapanService.buat(posko, store: induk);
    await PenyiapanService.terapkan(PenyiapanService.baca(file), store: anggota);
  });

  tearDown(() async {
    await induk.close();
    await anggota.close();
    await folder.delete(recursive: true);
  });

  Future<Posko> poskoDi(SqliteTableStore s) async =>
      (await PoskoRepository.withStore(s).getAll()).single;

  /// Ekspor paket dari HP [s] (seperti tombol Ekspor / Sinkron).
  Future<Uint8List> paketDari(SqliteTableStore s) async =>
      (await PaketDataService.kumpulkan([await poskoDi(s)], store: s)).zip;

  Future<void> catatPengungsi(SqliteTableStore s, String nama) async {
    await PengungsiRepository.withStore(s).add(Pengungsi.baru(
      poskoId: (await poskoDi(s)).id,
      nama: nama,
      asal: 'Cikaret',
      tanggalLahir: DateTime(1990, 1, 1),
      jenisKelamin: DataOptions.perempuan,
    ));
  }

  Future<void> catatBarang(SqliteTableStore s, {int masuk = 0, int keluar = 0}) async {
    final posko = await poskoDi(s);
    final beras = (await BarangRepository.withStore(s).getAll()).first;
    final repo = LogistikRepository.withStore(s);
    if (masuk > 0) {
      await repo.catatMasuk(BarangMasuk.baru(
          poskoId: posko.id!, barang: beras, jumlah: masuk,
          sumberBantuan: 'BPBD', tanggal: WaktuWib.hariIni()));
    }
    if (keluar > 0) {
      await repo.catatKeluar(
          BarangKeluar.baru(
              poskoId: posko.id!, barang: beras, jumlah: keluar,
              tujuan: 'dibagikan', tanggal: WaktuWib.hariIni()),
          barang: beras);
    }
  }

  Future<int> stokBeras(SqliteTableStore s) async {
    final beras = (await BarangRepository.withStore(s).getAll()).first;
    return LogistikRepository.withStore(s).stokBarang((await poskoDi(s)).id!, beras.id!);
  }

  test('HP Induk menggabungkan data HP Anggota; pratinjau tidak menyimpan', () async {
    await catatPengungsi(anggota, 'Siti');
    await catatPengungsi(anggota, 'Ani');
    await catatBarang(anggota, masuk: 50, keluar: 12);
    final paket = await paketDari(anggota);

    final cek = await GabungPaketService.periksa(paket, store: induk);
    expect(cek.ringkasanPengungsi[BarisGabung.tambah], 2);
    expect(cek.ringkasanMasuk[BarisGabung.tambah], 1);
    expect(cek.ringkasanKeluar[BarisGabung.tambah], 1);
    expect(cek.adaPerubahan, isTrue);
    expect(await PengungsiRepository.withStore(induk).count(), 0,
        reason: 'pratinjau tidak menyimpan');

    await GabungPaketService.terapkan(paket, store: induk);
    final semua = await PengungsiRepository.withStore(induk).getAll();
    expect(semua.map((p) => p.nama).toSet(), {'Siti', 'Ani'});
    expect(semua.every((p) => p.poskoId == (semua.first.poskoId)), isTrue);
    expect(await stokBeras(induk), 38);
  });

  test('impor ulang paket yang sama tidak dobel', () async {
    await catatPengungsi(anggota, 'Siti');
    await catatBarang(anggota, masuk: 50);
    final paket = await paketDari(anggota);
    await GabungPaketService.terapkan(paket, store: induk);
    final lagi = await GabungPaketService.terapkan(paket, store: induk);

    expect(lagi.adaPerubahan, isFalse);
    expect(await PengungsiRepository.withStore(induk).count(), 1);
    expect(await stokBeras(induk), 50);
  });

  test('sinkron dua arah: data HP Induk + Anggota jadi sama di kedua HP', () async {
    await catatPengungsi(anggota, 'Siti');
    await catatBarang(anggota, masuk: 50);
    await catatPengungsi(induk, 'Budi');
    await catatBarang(induk, keluar: 0, masuk: 10);

    await GabungPaketService.terapkan(await paketDari(anggota), store: induk);
    await GabungPaketService.terapkan(await paketDari(induk), store: anggota);

    for (final s in [induk, anggota]) {
      final nama = (await PengungsiRepository.withStore(s).getAll()).map((p) => p.nama);
      expect(nama.toSet(), {'Siti', 'Budi'});
      expect(await stokBeras(s), 60);
    }
    // Paket balik ke HP Induk: data milik HP Induk sendiri tidak berubah.
    final balik = await GabungPaketService.terapkan(await paketDari(anggota), store: induk);
    expect(balik.adaPerubahan, isFalse);
  });

  test('edit & hapus ikut; paket lama tidak mengembalikan / menimpa', () async {
    await catatPengungsi(anggota, 'Siti');
    await catatPengungsi(anggota, 'Ani');
    final lama = await paketDari(anggota);
    await GabungPaketService.terapkan(lama, store: induk);

    await Future<void>.delayed(const Duration(milliseconds: 1100)); // beda detik
    final repo = PengungsiRepository.withStore(anggota);
    final siti = (await repo.getAll()).firstWhere((p) => p.nama == 'Siti');
    final ani = (await repo.getAll()).firstWhere((p) => p.nama == 'Ani');
    await repo.update(siti.ubahData(
      poskoId: siti.poskoId, nama: 'Siti Aminah', asal: siti.asal,
      tanggalLahir: siti.tanggalLahir!, jenisKelamin: siti.jenisKelamin,
      nomorKk: '', kondisiKesehatan: 'Demam', kelompokRentan: 'Lansia',
      riwayatPenyakit: '',
    ));
    await repo.hapus(ani);

    final baru = await GabungPaketService.terapkan(await paketDari(anggota), store: induk);
    expect(baru.ringkasanPengungsi[BarisGabung.perbarui], 1);
    expect(baru.ringkasanPengungsi[BarisGabung.hapus], 1);

    final indukRepo = PengungsiRepository.withStore(induk);
    final aktif = await indukRepo.getAll();
    expect(aktif.map((p) => p.nama), ['Siti Aminah']);
    expect(aktif.single.kondisiKesehatan, 'Demam');

    // Paket LAMA datang belakangan.
    final terlambat = await GabungPaketService.terapkan(lama, store: induk);
    expect(terlambat.adaPerubahan, isFalse);
    expect((await indukRepo.getAll()).map((p) => p.nama), ['Siti Aminah']);
  });

  test('ekspor ulang dari HP Induk memakai waktu yang sama (tidak "lebih baru")',
      () async {
    await catatPengungsi(anggota, 'Siti');
    await GabungPaketService.terapkan(await paketDari(anggota), store: induk);
    final dariInduk = await GabungPaketService.periksa(await paketDari(induk), store: anggota);
    expect(dariInduk.ringkasanPengungsi[BarisGabung.sama], 1);
    expect(dariInduk.adaPerubahan, isFalse);
  });

  test('paket dari HP sendiri & dari posko lain ditolak', () async {
    await expectLater(GabungPaketService.periksa(await paketDari(induk), store: induk),
        throwsA(isA<GabungException>()
            .having((e) => e.message, 'pesan', contains('HP ini sendiri'))));

    final lain = SqliteTableStore(path: '${folder.path}/lain.db', factory: databaseFactoryFfi);
    await PoskoRepository.withStore(lain).add(Posko.baru(nama: 'Posko Lain'));
    await expectLater(GabungPaketService.periksa(await paketDari(lain), store: induk),
        throwsA(isA<GabungException>()
            .having((e) => e.message, 'pesan', contains('tidak ada di HP ini'))));
    await lain.close();
  });

  test('file rusak ditolak dengan pesan jelas', () async {
    await expectLater(GabungPaketService.periksa([1, 2, 3], store: induk),
        throwsA(isA<GabungException>()));
  });
}
