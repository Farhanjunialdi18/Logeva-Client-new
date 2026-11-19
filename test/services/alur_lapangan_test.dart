// ALUR LAPANGAN UJUNG-KE-UJUNG (sisi aplikasi):
//   2 HP relawan mencatat data -> setor ke HP admin -> admin menggabungkan
//   -> admin EKSPOR Paket Data Posko (dikunci kata sandi posko).
// File ZIP hasil ekspor disimpan sebagai fixture website
// (GMLS-Logeva-abimanyun/tests/Fixtures/paket_alur_lapangan.zip) lalu diimpor
// oleh tests/Feature/AlurLapanganTest.php di website.
// Langkah fisik (flashdisk OTG -> PC) hanya memindahkan file, tidak diuji.

import 'dart:io';

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
import 'package:flutter_application_1/services/csv_service.dart';
import 'package:flutter_application_1/services/paket_data_service.dart';
import 'package:flutter_application_1/services/penyiapan_service.dart';
import 'package:flutter_application_1/services/sinkron_service.dart';
import 'package:flutter_application_1/utils/berkas_terkunci.dart';
import 'package:flutter_application_1/utils/waktu_wib.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const kataSandiPosko = 'SandiPosko2026';
const fixtureWebsite =
    '../GMLS-Logeva-abimanyun/tests/Fixtures/paket_alur_lapangan.zip';

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late SqliteTableStore admin, andi, rina;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_alur_');
    SqliteTableStore buka(String n) =>
        SqliteTableStore(path: '${folder.path}/$n.db', factory: databaseFactoryFfi);
    admin = buka('hp_admin');
    andi = buka('hp_andi');
    rina = buka('hp_rina');
  });

  tearDown(() async {
    for (final s in [admin, andi, rina]) {
      await s.close();
    }
    await folder.delete(recursive: true);
  });

  Future<Posko> poskoDi(SqliteTableStore s) async =>
      (await PoskoRepository.withStore(s).getAll()).single;

  Future<dynamic> barang(SqliteTableStore s, String nama) async =>
      (await BarangRepository.withStore(s).getAll()).firstWhere((b) => b.namaItem == nama);

  /// Tombol KIRIM DATA KE ADMIN di HP relawan.
  Future<List<int>> setor(SqliteTableStore hp, String nama) async =>
      (await SinkronService.buatFile(await poskoDi(hp), store: hp, dibuatOleh: nama)).$2;

  test('relawan setor -> admin gabung -> ekspor paket terkunci', () async {
    // ---- 1. HP admin disiapkan ----
    final adminRepo = AdminRepository.withStore(admin);
    await adminRepo.ensureDefaultAdmin();
    var a = (await adminRepo.getAll()).single;
    await adminRepo.gantiPassword(a.copyWith(nama: 'Budi Santoso'), 'posko2026');
    a = (await adminRepo.getAll()).single;
    expect(adminRepo.perluDilengkapi(a), isFalse);
    await PengaturanRepository.withStore(admin).setKataSandiBerkas(kataSandiPosko);

    final posko = await PoskoRepository.withStore(admin).add(Posko.baru(
      nama: 'Posko Alur Lapangan', namaDesa: 'Panggarangan',
      alamat: 'Jl. Raya Panggarangan No. 5', luasLokasi: 300,
      latitude: '-6.9500', longitude: '106.1500',
    ));
    final relawanRepo = RelawanRepository.withStore(admin);
    await relawanRepo.add(Relawan(nama: 'Andi', pin: '111111', dibuatPada: DateTime(2026)).tempatkan(posko));
    await relawanRepo.add(Relawan(nama: 'Rina', pin: '222222', dibuatPada: DateTime(2026)).tempatkan(posko));

    // ---- 2. HP relawan disiapkan dari HP admin ----
    final (_, siap) = await PenyiapanService.buat(posko, store: admin);
    for (final hp in [andi, rina]) {
      await PenyiapanService.terapkan(PenyiapanService.baca(siap), store: hp);
      expect(await PengaturanRepository.withStore(hp).kataSandiBerkas(), kataSandiPosko);
    }

    // ---- 3. Relawan mencatat data ----
    final pA = await poskoDi(andi);
    final pengAndi = PengungsiRepository.withStore(andi);
    await pengAndi.add(Pengungsi.baru(
      poskoId: pA.id, nama: 'Siti Aminah', asal: 'Cikaret',
      tanggalLahir: DateTime(1990, 5, 17), jenisKelamin: DataOptions.perempuan,
      kondisiKesehatan: 'Sakit ringan - demam', dicatatOleh: 'Andi',
    ));
    await pengAndi.add(Pengungsi.baru(
      poskoId: pA.id, nama: 'Mak Inah', asal: 'Cikaret', usia: 72,
      jenisKelamin: DataOptions.perempuan, kelompokRentan: 'Lansia', dicatatOleh: 'Andi',
    ));
    await LogistikRepository.withStore(andi).catatMasuk(BarangMasuk.baru(
      poskoId: pA.id!, barang: await barang(andi, 'Beras'), jumlah: 50,
      sumberBantuan: 'BPBD Lebak', tanggal: WaktuWib.hariIni(), dicatatOleh: 'Andi',
    ));
    expect(await PengaturanRepository.withStore(andi).perubahanBelumTerkirim(), greaterThan(0),
        reason: 'pengingat "belum disetor" di beranda relawan');

    final pR = await poskoDi(rina);
    await PengungsiRepository.withStore(rina).add(Pengungsi.baru(
      poskoId: pR.id, nama: 'Budi Kecil', asal: 'Sukajadi',
      tanggalLahir: DateTime(2020, 1, 1), jenisKelamin: DataOptions.lakiLaki, dicatatOleh: 'Rina',
    ));
    final air = await barang(rina, 'Air Mineral');
    final logRina = LogistikRepository.withStore(rina);
    await logRina.catatMasuk(BarangMasuk.baru(
      poskoId: pR.id!, barang: air, jumlah: 100, sumberBantuan: 'Donatur warga',
      tanggal: WaktuWib.hariIni(), dicatatOleh: 'Rina',
    ));
    await logRina.catatKeluar(
        BarangKeluar.baru(poskoId: pR.id!, barang: air, jumlah: 20, tujuan: 'dibagikan',
            tanggal: WaktuWib.hariIni(), dicatatOleh: 'Rina'),
        barang: air);

    // ---- 4. Setor ke admin (relawan -> relawan ditolak) ----
    final dariAndi = await setor(andi, 'Andi');
    expect((await SinkronService.periksa(dariAndi, store: rina)).ditolak, isNotNull,
        reason: 'tidak boleh antar-relawan');
    await SinkronService.terapkan(dariAndi, store: admin);
    await SinkronService.terapkan(await setor(rina, 'Rina'), store: admin);

    // Andi memperbaiki data, Rina menghapus data salah input, lalu setor lagi.
    // (Versi dibandingkan per detik, sama dengan website: beri jeda seperti
    // di lapangan.)
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    final siti = (await pengAndi.getAll()).firstWhere((p) => p.nama == 'Siti Aminah');
    await pengAndi.update(siti.ubahData(
      poskoId: siti.poskoId, nama: siti.nama, asal: siti.asal,
      tanggalLahir: siti.tanggalLahir, jenisKelamin: siti.jenisKelamin,
      nomorKk: '', kondisiKesehatan: 'Sehat', kelompokRentan: 'Ibu Hamil',
      riwayatPenyakit: '',
    ));
    final budiKecil = (await PengungsiRepository.withStore(rina).getAll()).single;
    await PengungsiRepository.withStore(rina).hapus(budiKecil);
    await SinkronService.terapkan(await setor(andi, 'Andi'), store: admin);
    await SinkronService.terapkan(await setor(rina, 'Rina'), store: admin);
    // Setor ulang file yang sama tidak membuat dobel.
    await SinkronService.terapkan(await setor(andi, 'Andi'), store: admin);

    // ---- 5. HP admin berisi data semua relawan ----
    final semua = await PengungsiRepository.withStore(admin).getAll();
    expect(semua.map((p) => p.nama).toSet(), {'Siti Aminah', 'Mak Inah'});
    final sitiAdmin = semua.firstWhere((p) => p.nama == 'Siti Aminah');
    expect(sitiAdmin.kondisiKesehatan, 'Sehat');
    expect(sitiAdmin.kelompokRentan, 'Ibu Hamil');
    expect(semua.firstWhere((p) => p.nama == 'Mak Inah').usia, 72);
    final logAdmin = LogistikRepository.withStore(admin);
    expect((await logAdmin.getMasuk()).length, 2);
    expect((await logAdmin.getKeluar()).length, 1);
    final pAdm = await poskoDi(admin);
    expect(await logAdmin.stokBarang(pAdm.id!, (await barang(admin, 'Beras')).id), 50);
    expect(await logAdmin.stokBarang(pAdm.id!, (await barang(admin, 'Air Mineral')).id), 80);

    // ---- 6. Ekspor Paket Data Posko (EKSPOR KE USB) ----
    final paket = await PaketDataService.kumpulkan([pAdm], store: admin, dieksporOleh: 'Budi Santoso');
    final cek = PaketDataService.periksa(paket);
    expect(cek.penghalang, isEmpty, reason: 'tombol ekspor aktif');
    expect(paket.namaFile, startsWith('LOGEVA_paket_PoskoAlurLapangan_'));
    final csv = CsvService.decode(paket.csv['pengungsi.csv']!);
    expect(csv.where((r) => (r['dihapus_pada'] ?? '').isNotEmpty).map((r) => r['nama']),
        ['Budi Kecil'], reason: 'penghapusan ikut ke pusat');

    final berkas = await PaketDataService.berkasTerkunci(paket, store: admin);
    expect(BerkasTerkunci.terkunci(berkas), isTrue);
    expect(BerkasTerkunci.buka(berkas, kataSandiPosko), isNotEmpty);

    // Simpan sebagai fixture website kalau belum ada, atau kalau diminta:
    //   LOGEVA_TULIS_FIXTURE=1 flutter test test/services/alur_lapangan_test.dart
    // (tidak ditulis ulang setiap tes supaya file di git tidak berubah terus).
    final dir = Directory('../GMLS-Logeva-abimanyun/tests/Fixtures');
    final tulis = Platform.environment['LOGEVA_TULIS_FIXTURE'] == '1' ||
        !File(fixtureWebsite).existsSync();
    if (dir.existsSync() && tulis) File(fixtureWebsite).writeAsBytesSync(berkas);
  });
}
