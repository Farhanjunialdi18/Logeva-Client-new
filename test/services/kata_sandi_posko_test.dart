// Kata sandi posko: dibuat di HP Induk, ikut ke HP Anggota (penyiapan &
// sinkron), dan mengunci Paket Data Posko.

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_application_1/data/repositories/admin_repository.dart';
import 'package:flutter_application_1/data/repositories/pengaturan_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/services/paket_data_service.dart';
import 'package:flutter_application_1/services/penyiapan_service.dart';
import 'package:flutter_application_1/services/sinkron_service.dart';
import 'package:flutter_application_1/utils/berkas_terkunci.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late SqliteTableStore induk, anggota;
  late Posko posko;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_sandi_');
    induk = SqliteTableStore(path: '${folder.path}/induk.db', factory: databaseFactoryFfi);
    anggota = SqliteTableStore(path: '${folder.path}/anggota.db', factory: databaseFactoryFfi);
    final admin = AdminRepository.withStore(induk);
    await admin.ensureDefaultAdmin();
    await admin.gantiPassword((await admin.getAll()).single, 'posko2026');
    posko = await PoskoRepository.withStore(induk).add(Posko.baru(nama: 'Balai Desa'));
  });

  tearDown(() async {
    await induk.close();
    await anggota.close();
    try {
      await folder.delete(recursive: true);
    } catch (_) {}
  });

  test('kata sandi ikut ke HP Anggota lewat penyiapan & sinkron', () async {
    await PengaturanRepository.withStore(induk).setKataSandiBerkas('sandiPosko1');
    final (_, f) = await PenyiapanService.buat(posko, store: induk);
    await PenyiapanService.terapkan(PenyiapanService.baca(f), store: anggota);
    expect(await PengaturanRepository.withStore(anggota).kataSandiBerkas(), 'sandiPosko1');

    // Supervisor mengganti kata sandi -> sampai ke HP Anggota saat sinkron.
    await PengaturanRepository.withStore(induk).setKataSandiBerkas('sandiBaru22');
    await SinkronService.terapkan((await SinkronService.buatFile(posko, store: induk)).$2,
        store: anggota);
    expect(await PengaturanRepository.withStore(anggota).kataSandiBerkas(), 'sandiBaru22');
  });

  test('paket yang diekspor terkunci; tanpa kata sandi ditolak', () async {
    final paket = await PaketDataService.kumpulkan([posko], store: induk);
    await expectLater(PaketDataService.berkasTerkunci(paket, store: induk),
        throwsA(isA<StateError>()));

    await PengaturanRepository.withStore(induk).setKataSandiBerkas('sandiPosko1');
    final berkas = await PaketDataService.berkasTerkunci(paket, store: induk);
    expect(BerkasTerkunci.terkunci(berkas), isTrue);
    final isi = ZipDecoder().decodeBytes(BerkasTerkunci.buka(berkas, 'sandiPosko1'));
    expect(isi.findFile('posko.csv'), isNotNull, reason: 'isi asli = paket biasa');
  });
}
