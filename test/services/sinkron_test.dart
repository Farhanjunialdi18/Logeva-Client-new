// Tahap D: sinkron dua arah antar 3 HP satu posko (1 Induk + 2 Anggota).
// Tiga database terpisah = tiga HP; file dipertukarkan seperti lewat
// Bluetooth / Quick Share. Tanpa internet.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/repositories/admin_repository.dart';
import 'package:flutter_application_1/data/repositories/barang_repository.dart';
import 'package:flutter_application_1/data/repositories/logistik_repository.dart';
import 'package:flutter_application_1/data/repositories/pengaturan_repository.dart';
import 'package:flutter_application_1/data/repositories/pengungsi_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/data/repositories/relawan_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/catatan_logistik.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/models/relawan.dart';
import 'package:flutter_application_1/services/berkas_masuk_service.dart';
import 'package:flutter_application_1/services/gabung_paket_service.dart';
import 'package:flutter_application_1/services/csv_service.dart';
import 'package:flutter_application_1/services/paket_data_service.dart';
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

  test('pilih data: hanya pengungsi / hanya logistik yang ikut', () async {
    await catat(a, 'Siti', masuk: 50);
    final posko = await poskoDi(a);

    final (_, hanyaPengungsi) = await SinkronService.buatFile(posko,
        store: a, dibuatOleh: 'x', logistik: false);
    await SinkronService.terapkan(hanyaPengungsi, store: induk);
    expect(await namaPengungsi(induk), contains('Siti'));
    expect(await stokBeras(induk), 0);

    final (_, hanyaLogistik) = await SinkronService.buatFile(posko,
        store: a, dibuatOleh: 'x', pengungsi: false);
    await SinkronService.terapkan(hanyaLogistik, store: b);
    expect(await namaPengungsi(b), isNot(contains('Siti')));
    expect(await stokBeras(b), 50);

    // Kirim sebagian tidak menghapus data lain di HP tujuan.
    await SinkronService.terapkan(hanyaLogistik, store: induk);
    expect(await namaPengungsi(induk), contains('Siti'));
    expect(await stokBeras(induk), 50);
  });

  test('Buka dengan LOGEVA: file sinkron & penyiapan dikenali', () async {
    final (nSinkron, fSinkron) =
        await SinkronService.buatFile(await poskoDi(induk), store: induk);
    expect(BerkasMasukService.kenali(nSinkron, fSinkron), JenisBerkas.sinkron);
    // Nama diubah (misal oleh WhatsApp) tetap dikenali dari isinya.
    expect(BerkasMasukService.kenali('dokumen.zip', fSinkron), JenisBerkas.sinkron);

    final (nSiap, fSiap) = await PenyiapanService.buat(await poskoDi(induk), store: induk);
    expect(BerkasMasukService.kenali(nSiap, fSiap), JenisBerkas.penyiapan);
    expect(BerkasMasukService.kenali('foto.zip', [1, 2, 3]), JenisBerkas.tidakDikenal);
  });

  test('HP relawan baru: satu file dari HP Induk = akun + data langsung muncul',
      () async {
    await catat(induk, 'Ani', masuk: 30);
    final baru = buka('anggota_baru');
    addTearDown(baru.close);

    final (nama, file) = await SinkronService.buatFile(await poskoDi(induk),
        store: induk, dibuatOleh: 'Admin', awalanNama: 'LOGEVA_penyiapan_');
    expect(nama, startsWith('LOGEVA_penyiapan_BalaiDesa_dari-induk_'));
    expect(BerkasMasukService.kenali(nama, file), JenisBerkas.sinkron);
    // HP baru (dan HP Anggota posko yang sama) boleh disiapkan dari file ini.
    expect(await SinkronService.bisaMenyiapkan(file, store: baru), isTrue);
    expect(await SinkronService.bisaMenyiapkan(file, store: a), isTrue);
    // File dari HP Anggota tidak bisa menyiapkan HP lain.
    expect(await SinkronService.bisaMenyiapkan(await kirimDari(a), store: baru), isFalse);

    final isi = SinkronService.ringkasanIsi(file)!;
    expect((isi.pengungsi, isi.masuk), (1, 1));

    // Yang dilakukan tombol SIAPKAN & SINKRONKAN.
    await PenyiapanService.terapkan(PenyiapanService.baca(file), store: baru);
    await GabungPaketService.terapkan(file, store: baru);

    expect(await namaPengungsi(baru), {'Ani'});
    expect(await stokBeras(baru), 30);
    expect((await RelawanRepository.withStore(baru).getAll()).single.nama, 'Andi');

    // Relawan di HP baru lalu bisa mengirim balik ke HP Induk.
    await catat(baru, 'Rina');
    await SinkronService.terapkan(await kirimDari(baru), store: induk);
    expect(await namaPengungsi(induk), {'Ani', 'Rina'});
  });

  test('status kirim: belum terkirim dihitung, tanda terima dari HP Induk', () async {
    final pengaturanA = PengaturanRepository.withStore(a);
    var status = await SinkronService.statusKirim(store: a);
    expect(status.belumTerkirim, 0);
    expect(status.terakhirKirim, isNull);

    // Relawan A mencatat 1 pengungsi + 1 barang masuk = 2 perubahan.
    await catat(a, 'Siti', masuk: 10);
    expect((await SinkronService.statusKirim(store: a)).belumTerkirim, 2);

    // A mengirim ke HP Induk (seperti tombol KIRIM DATA KE ADMIN).
    final waktuKirim = DateTime.now().subtract(const Duration(minutes: 5));
    final (_, fileA) = await SinkronService.buatFile(await poskoDi(a),
        store: a, dibuatOleh: 'Andi', waktu: waktuKirim);
    await pengaturanA.tandaiTerkirim(WaktuWib.tanggalWaktu(waktuKirim));
    status = await SinkronService.statusKirim(store: a);
    expect(status.belumTerkirim, 0);
    expect(status.terakhirKirim, isNotNull);
    expect(status.sudahDikonfirmasi, isFalse, reason: 'admin belum menggabungkan');

    // HP Induk menggabungkan, lalu mengirim data gabungan (berisi data B juga).
    await catat(b, 'Budi');
    await SinkronService.terapkan(fileA, store: induk);
    await SinkronService.terapkan(await kirimDari(b), store: induk);
    final gabungan = await kirimDari(induk);
    await SinkronService.terapkan(gabungan, store: a);

    status = await SinkronService.statusKirim(store: a);
    expect(status.sudahDikonfirmasi, isTrue, reason: 'tanda terima dari HP Induk');
    expect(status.terakhirDariInduk, isNotNull);
    expect(status.belumTerkirim, 0,
        reason: 'data Budi dari HP lain tidak dihitung sebagai "belum terkirim"');
    expect(await namaPengungsi(a), {'Siti', 'Budi'});

    // HP B belum pernah mengirim lewat tombol -> tanda terima ada, tapi
    // tidak dianggap konfirmasi karena terakhirKirim kosong.
    await SinkronService.terapkan(gabungan, store: b);
    expect((await SinkronService.statusKirim(store: b)).sudahDikonfirmasi, isFalse);

    // Catatan baru setelah dikonfirmasi = belum terkirim lagi.
    await catat(a, 'Rina');
    expect((await SinkronService.statusKirim(store: a)).belumTerkirim, 1);
  });

  test('pengingat admin: HP relawan perlu dibagikan ulang & belum kirim', () async {
    final relawanInduk = RelawanRepository.withStore(induk);
    final andi = (await relawanInduk.getAll()).single;

    // Belum pernah dibagikan dari Detail Relawan / belum pernah kirim.
    var semua = await SinkronService.statusHpRelawan(store: induk);
    var s = SinkronService.statusUntuk(semua, andi.kode);
    expect(s.belumPernahDibagikan, isTrue);
    expect(s.perluDibagikan, isTrue);
    expect(s.belumKirimHariIni(), isTrue);

    // Admin membagikan ke HP Andi.
    await SinkronService.tandaiDibagikan(
        andi.kode, DateTime.now().add(const Duration(seconds: 2)), store: induk);
    s = SinkronService.statusUntuk(
        await SinkronService.statusHpRelawan(store: induk), andi.kode);
    expect(s.perluDibagikan, isFalse);

    // Andi mengirim data dari HP A -> laporan tercatat di HP Induk.
    await catat(a, 'Siti');
    final (_, fileA) = await SinkronService.buatFile(await poskoDi(a),
        store: a, dibuatOleh: 'Andi', kodeRelawan: andi.kode);
    await SinkronService.terapkan(fileA, store: induk);
    s = SinkronService.statusUntuk(
        await SinkronService.statusHpRelawan(store: induk), andi.kode);
    expect(s.terakhirKirim, isNotNull);
    expect(s.belumKirimHariIni(), isFalse);

    // Admin mengganti PIN Andi -> akun di HP Andi belum berlaku.
    await Future<void>.delayed(const Duration(seconds: 3));
    await relawanInduk.regeneratePin(andi);
    s = SinkronService.statusUntuk(
        await SinkronService.statusHpRelawan(store: induk), andi.kode);
    expect(s.akunBelumBerlaku, isTrue);
    expect(s.perluDibagikan, isTrue);

    // Admin membagikan ulang -> pengingat hilang.
    await SinkronService.tandaiDibagikan(
        andi.kode, DateTime.now().add(const Duration(seconds: 2)), store: induk);
    s = SinkronService.statusUntuk(
        await SinkronService.statusHpRelawan(store: induk), andi.kode);
    expect(s.akunBelumBerlaku, isFalse);
    expect(s.adaDataBaru, isFalse);
    expect(s.perluDibagikan, isFalse);
  });

  test('pengungsi usia saja: Anggota -> Induk -> paket website, tanpa dobel', () async {
    final posko = await poskoDi(a);
    await PengungsiRepository.withStore(a).add(Pengungsi.baru(
      poskoId: posko.id, nama: 'Mak Inah', asal: 'X', usia: 72,
      jenisKelamin: DataOptions.perempuan,
    ));
    for (var i = 0; i < 2; i++) {
      await SinkronService.terapkan(await kirimDari(a), store: induk);
    }
    final diInduk = (await PengungsiRepository.withStore(induk).getAll())
        .where((p) => p.nama == 'Mak Inah')
        .toList();
    expect(diInduk, hasLength(1), reason: 'kirim 2x tidak dobel');
    expect(diInduk.single.tanggalLahir, isNull);
    expect(diInduk.single.usia, 72);

    final paket = await PaketDataService.kumpulkan([await poskoDi(induk)], store: induk);
    final baris = CsvService.decode(paket.csv['pengungsi.csv']!)
        .firstWhere((r) => r['nama'] == 'Mak Inah');
    expect(baris['tanggal_lahir'], '');
    expect(baris['usia'], '72');
  });
}
