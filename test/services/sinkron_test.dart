// Tahap D: sinkron dua arah antar 3 HP satu posko (1 Induk + 2 Anggota).
// Tiga database terpisah = tiga HP; file dipertukarkan seperti lewat
// Bluetooth / Quick Share. Tanpa internet.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/repositories/admin_repository.dart';
import 'package:flutter_application_1/data/repositories/barang_repository.dart';
import 'package:flutter_application_1/data/repositories/logistik_repository.dart';
import 'package:flutter_application_1/data/repositories/pengungsi_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/data/repositories/relawan_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/catatan_logistik.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/models/relawan.dart';
import 'package:flutter_application_1/services/gabung_paket_service.dart';
import 'package:flutter_application_1/services/penyiapan_service.dart';
import 'package:flutter_application_1/services/sinkron_service.dart';
import 'package:flutter_application_1/utils/waktu_wib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late SqliteTableStore induk, a, b;

  SqliteTableStore buka(String nama) =>
      SqliteTableStore(path: '${folder.path}/$nama.db', factory: databaseFactoryFfi);

  Future<Posko> poskoDi(SqliteTableStore s) async =>
      (await PoskoRepository.withStore(s).getAll()).single;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_sinkron_');
    induk = buka('induk');
    a = buka('anggota_a');
    b = buka('anggota_b');

    final admin = AdminRepository.withStore(induk);
    await admin.ensureDefaultAdmin();
    await admin.gantiPassword((await admin.getAll()).single, 'posko2026');
    final posko = await PoskoRepository.withStore(induk).add(Posko.baru(
      nama: 'Balai Desa', namaDesa: 'Panggarangan', alamat: 'Jl. 1',
      luasLokasi: 350, latitude: '-6.9', longitude: '106.1',
    ));
    await RelawanRepository.withStore(induk).add(
        Relawan(nama: 'Andi', pin: '111111', dibuatPada: DateTime(2026)).tempatkan(posko));
    final (_, file) = await PenyiapanService.buat(posko, store: induk);
    for (final s in [a, b]) {
      await PenyiapanService.terapkan(PenyiapanService.baca(file), store: s);
    }
  });

  tearDown(() async {
    for (final s in [induk, a, b]) {
      await s.close();
    }
    await folder.delete(recursive: true);
  });

  Future<Uint8List> kirimDari(SqliteTableStore s) async =>
      (await SinkronService.buatFile(await poskoDi(s), store: s, dibuatOleh: 'x')).$2;

  Future<void> catat(SqliteTableStore s, String nama, {int masuk = 0, int keluar = 0}) async {
    final posko = await poskoDi(s);
    await PengungsiRepository.withStore(s).add(Pengungsi.baru(
      poskoId: posko.id, nama: nama, asal: 'X',
      tanggalLahir: DateTime(1990), jenisKelamin: DataOptions.lakiLaki,
    ));
    final beras = (await BarangRepository.withStore(s).getAll()).first;
    final repo = LogistikRepository.withStore(s);
    if (masuk > 0) {
      await repo.catatMasuk(BarangMasuk.baru(
          poskoId: posko.id!, barang: beras, jumlah: masuk,
          sumberBantuan: 'BPBD', tanggal: WaktuWib.hariIni()));
    }
    if (keluar > 0) {
      await repo.catatKeluar(
          BarangKeluar.baru(poskoId: posko.id!, barang: beras, jumlah: keluar,
              tujuan: 'dibagikan', tanggal: WaktuWib.hariIni()),
          barang: beras);
    }
  }

  Future<Set<String>> namaPengungsi(SqliteTableStore s) async =>
      (await PengungsiRepository.withStore(s).getAll()).map((p) => p.nama).toSet();

  Future<int> stokBeras(SqliteTableStore s) async {
    final beras = (await BarangRepository.withStore(s).getAll()).first;
    return LogistikRepository.withStore(s).stokBarang((await poskoDi(s)).id!, beras.id!);
  }

  test('1 Induk + 2 Anggota: setelah sinkron, ketiga HP berisi data yang sama',
      () async {
    await catat(a, 'Siti', masuk: 50);
    await catat(b, 'Budi', masuk: 20, keluar: 5);
    await catat(induk, 'Ani');

    // Anggota -> Induk
    await SinkronService.terapkan(await kirimDari(a), store: induk);
    await SinkronService.terapkan(await kirimDari(b), store: induk);
    // Induk -> semua Anggota (data gabungan)
    final gabungan = await kirimDari(induk);
    await SinkronService.terapkan(gabungan, store: a);
    await SinkronService.terapkan(gabungan, store: b);

    for (final s in [induk, a, b]) {
      expect(await namaPengungsi(s), {'Siti', 'Budi', 'Ani'});
      expect(await stokBeras(s), 65);
    }
    // Sinkron ulang tidak membuat dobel.
    final ulang = await SinkronService.periksa(await kirimDari(a), store: induk);
    expect(ulang.data.adaPerubahan, isFalse);
  });

  test('file HP Anggota tidak membawa akun; file HP Induk membawa pembaruan akun',
      () async {
    final dariA = await SinkronService.periksa(await kirimDari(a), store: induk);
    expect(dariA.akun, isNull);

    // Relawan baru & PIN baru di HP Induk.
    final relawan = RelawanRepository.withStore(induk);
    final posko = await poskoDi(induk);
    await relawan.add(
        Relawan(nama: 'Rina', pin: '555555', dibuatPada: DateTime(2026)).tempatkan(posko));

    final cek = await SinkronService.periksa(await kirimDari(induk), store: a);
    expect(cek.akun, isNotNull);
    expect(cek.ditolak, isNull);
    await SinkronService.terapkan(await kirimDari(induk), store: a);
    expect((await RelawanRepository.withStore(a).findByPin('555555'))?.nama, 'Rina');
    expect((await RelawanRepository.withStore(a).findByPin('111111'))?.nama, 'Andi');
  });

  test('HP Induk tidak menerima akun dari file HP Induk lain', () async {
    final indukLain = buka('induk_lain');
    final admin = AdminRepository.withStore(indukLain);
    await admin.add(nama: 'Lain', username: 'lain', email: 'l@x.id', password: 'rahasia123');
    // Posko sama (supaya datanya dikenal), tapi akun tidak boleh masuk.
    final p = await poskoDi(induk);
    await PoskoRepository.withStore(indukLain).add(Posko.fromMap(p.toMap()..remove('id')));

    final cek = await SinkronService.periksa(await kirimDari(indukLain), store: induk);
    expect(cek.akun, isNull, reason: 'akun di file diabaikan di HP Induk');
    await SinkronService.terapkan(await kirimDari(indukLain), store: induk);
    expect(await AdminRepository.withStore(induk).findByLogin('lain'), isNull);
    await indukLain.close();
  });

  test('HP Anggota menolak file dari HP Induk posko lain', () async {
    final indukLain = buka('induk_lain');
    final admin = AdminRepository.withStore(indukLain);
    await admin.add(nama: 'Lain', username: 'lain', email: 'l@x.id', password: 'rahasia123');
    final p = await poskoDi(induk);
    await PoskoRepository.withStore(indukLain).add(Posko.fromMap(p.toMap()..remove('id')));

    final cek = await SinkronService.periksa(await kirimDari(indukLain), store: a);
    expect(cek.ditolak, isNotNull);
    await expectLater(SinkronService.terapkan(await kirimDari(indukLain), store: a),
        throwsA(isA<GabungException>()));
    await indukLain.close();
  });

  test('peringatan jika jam HP pengirim lebih maju', () async {
    final besok = DateTime.now().add(const Duration(days: 1));
    final (_, file) = await SinkronService.buatFile(await poskoDi(a), store: a, waktu: besok);
    final cek = await SinkronService.periksa(file, store: induk);
    expect(cek.peringatanJam, contains('lebih maju'));

    final normal = await SinkronService.periksa(await kirimDari(a), store: induk);
    expect(normal.peringatanJam, isNull);
  });

  test('riwayat: file terakhir yang diterima dari setiap HP', () async {
    await SinkronService.terapkan(await kirimDari(a), store: induk);
    await SinkronService.terapkan(await kirimDari(b), store: induk);
    final r = await SinkronService.riwayat(store: induk);
    expect(r, hasLength(2));
    expect(r.every((x) => x.oleh == 'x' && x.waktu.isNotEmpty), isTrue);
  });

  test('nama file membedakan arah sinkron', () async {
    expect((await SinkronService.buatFile(await poskoDi(a), store: a)).$1,
        contains('_dari-anggota_'));
    expect((await SinkronService.buatFile(await poskoDi(induk), store: induk)).$1,
        contains('_dari-induk_'));
  });
}
