// Keberadaan pengungsi: pulang / pindah / dirujuk tidak dihapus, tapi tidak
// lagi dihitung untuk kapasitas & kebutuhan. Status ikut sinkron antar-HP
// dan paket; database lama otomatis "di posko".

import 'dart:io';

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/database_tables.dart';
import 'package:flutter_application_1/data/repositories/admin_repository.dart';
import 'package:flutter_application_1/data/repositories/pengungsi_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/services/dashboard_service.dart';
import 'package:flutter_application_1/services/paket_data_service.dart';
import 'package:flutter_application_1/services/penyiapan_service.dart';
import 'package:flutter_application_1/services/ringkasan_posko_service.dart';
import 'package:flutter_application_1/services/sinkron_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late SqliteTableStore induk, anggota;
  late Posko posko;

  Pengungsi orang(String nama) => Pengungsi.baru(
        poskoId: posko.id, nama: nama, asal: 'X',
        tanggalLahir: DateTime(1985), jenisKelamin: DataOptions.lakiLaki);

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_keberadaan_');
    induk = SqliteTableStore(path: '${folder.path}/induk.db', factory: databaseFactoryFfi);
    anggota = SqliteTableStore(path: '${folder.path}/anggota.db', factory: databaseFactoryFfi);
    final admin = AdminRepository.withStore(induk);
    await admin.ensureDefaultAdmin();
    await admin.gantiPassword((await admin.getAll()).single, 'posko2026');
    posko = await PoskoRepository.withStore(induk)
        .add(Posko.baru(nama: 'Balai Desa', luasLokasi: 35)); // 10 orang
    posko = await PoskoRepository.withStore(induk).ubahStatus(posko, AksiOperasional.mulai);
    final (_, f) = await PenyiapanService.buat(posko, store: induk);
    await PenyiapanService.terapkan(PenyiapanService.baca(f), store: anggota);
  });

  tearDown(() async {
    await induk.close();
    await anggota.close();
    await folder.delete(recursive: true);
  });

  test('yang keluar posko tidak dihitung, tapi tetap tercatat', () async {
    final repo = PengungsiRepository.withStore(induk);
    for (final n in ['Siti', 'Budi', 'Rahmat']) {
      await repo.add(orang(n));
    }
    final budi = (await repo.getAll()).firstWhere((e) => e.nama == 'Budi');
    await repo.update(budi.catatKeluar(DataOptions.pindah, DateTime(2026, 10, 27), 'Posko SDN 2'));

    expect(await repo.count(poskoId: posko.id), 2);
    expect((await repo.getByPosko(posko.id)).length, 3, reason: 'daftar tetap lengkap');
    final b = (await repo.getAll()).firstWhere((e) => e.nama == 'Budi');
    expect((b.masihDiPosko, b.labelKeberadaan, b.keteranganKeluar),
        (false, 'Pindah ke posko lain', 'Posko SDN 2'));
    expect(b.keluarPada, DateTime(2026, 10, 27));

    final r = await RingkasanPoskoService.muat(posko, store: induk);
    expect(r.komposisi.total, 2);
    final d = await DashboardService.muat(store: induk);
    expect((d.komposisi.total, d.jumlahKeluar, d.keluarPosko[DataOptions.pindah]), (2, 1, 1));
    expect(d.pengungsiBaru7Hari, 3, reason: 'tren kedatangan tetap menghitung semua');

    // Batal pindah: kembali dihitung.
    await repo.update(b.kembaliKePosko());
    expect(await repo.count(poskoId: posko.id), 3);
  });

  test('status keluar ikut sinkron antar-HP dan Paket Data Posko', () async {
    final repoAnggota = PengungsiRepository.withStore(anggota);
    await repoAnggota.add(orang('Siti'));
    final siti = (await repoAnggota.getAll()).single;
    await repoAnggota.update(siti.catatKeluar(DataOptions.dirujuk, DateTime(2026, 10, 26), 'RSUD Pandeglang'));

    await SinkronService.terapkan(
        (await SinkronService.buatFile((await PoskoRepository.withStore(anggota).getAll()).single,
                store: anggota))
            .$2,
        store: induk);
    final diInduk = (await PengungsiRepository.withStore(induk).getAll()).single;
    expect((diInduk.statusKeberadaan, diInduk.keluarPada, diInduk.keteranganKeluar),
        (DataOptions.dirujuk, DateTime(2026, 10, 26), 'RSUD Pandeglang'));

    final paket = await PaketDataService.kumpulkan(
        await PoskoRepository.withStore(induk).getAll(), store: induk);
    final csv = paket.csv['pengungsi.csv']!;
    expect(csv.split('\n').first.trim(), endsWith('status_keberadaan,keluar_pada,keterangan_keluar'));
    expect(csv, contains('dirujuk,2026-10-26,RSUD Pandeglang'));
  });

  test('upgrade database v8 -> v9: pengungsi lama otomatis di posko', () async {
    final path = '${folder.path}/lama.db';
    final lama = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 8,
          onCreate: (db, _) async {
            for (var v = 1; v <= 8; v++) {
              for (final sql in DatabaseTables.upgradeSteps[v]!) {
                await db.execute(sql);
              }
            }
          },
        ));
    await lama.insert(DatabaseTables.pengungsi, orang('Lama').toMap()
      ..remove('id')
      ..remove('status_keberadaan')
      ..remove('keluar_pada')
      ..remove('keterangan_keluar'));
    await lama.close();

    final s = SqliteTableStore(path: path, factory: databaseFactoryFfi);
    final p = (await PengungsiRepository.withStore(s).getAll()).single;
    expect((p.nama, p.masihDiPosko), ('Lama', true));
    await s.close();
  });
}
