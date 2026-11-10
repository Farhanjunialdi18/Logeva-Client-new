// Import Paket Data Posko dari WEBSITE pusat (website -> HP Induk) dan
// kolom ketinggian posko. Paket dibuat dengan kolom yang sama persis dengan
// website (app/Exports/PaketPoskoExport.php): posko.csv + foto & ketinggian_mdpl,
// info.csv + sumber = website.

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_application_1/data/repositories/admin_repository.dart';
import 'package:flutter_application_1/data/repositories/barang_repository.dart';
import 'package:flutter_application_1/data/repositories/logistik_repository.dart';
import 'package:flutter_application_1/data/repositories/pengungsi_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/services/csv_service.dart';
import 'package:flutter_application_1/services/gabung_paket_service.dart';
import 'package:flutter_application_1/services/paket_data_service.dart';
import 'package:flutter_application_1/services/penyiapan_service.dart';
import 'package:flutter_application_1/utils/berkas_terkunci.dart';
import 'package:flutter_application_1/utils/kode_unik.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _kodeWebsite = '0b7d3c1e-5a2f-4c3d-9e8f-1a2b3c4d5e6f';
const _kodePosko = '7f1c2d3e-4b5a-4c6d-8e9f-0a1b2c3d4e5f';

/// Paket seperti hasil "Export paket untuk aplikasi" di website.
Uint8List paketWebsite({
  String kodePosko = _kodePosko,
  String nama = 'Bukit Evakuasi Pasir Gombong',
  String desa = 'Sawarna',
  String ketinggian = '45.5',
  String diubah = '2026-11-08 10:00:00',
  int stokBeras = 40,
  String sumber = 'website',
  List<List<String>>? pengungsi,
}) {
  final arsip = Archive();
  void tambah(String nama, List<String> judul, List<List<String>> baris) =>
      arsip.addFile(ArchiveFile.string(nama, CsvService.encode(judul, baris)));

  tambah('info.csv', ['versi_format', 'dibuat_pada', 'kode_perangkat', 'diekspor_oleh', 'sumber'],
      [['1', '2026-11-08 12:00:00', _kodeWebsite, 'Admin GMLS', sumber]]);
  tambah('posko.csv', [
    'kode_posko', 'nama_lokasi', 'nama_desa', 'alamat_lokasi', 'luas_lokasi',
    'kapasitas_pengungsi', 'latitude', 'longitude', 'status_operasional',
    'mulai_beroperasi_at', 'selesai_beroperasi_at', 'relawan_penanggung_jawab',
    'diubah_pada', 'foto', 'ketinggian_mdpl',
  ], [
    [kodePosko, nama, desa, 'Titik dari RUinRISK (-6.965, 106.28)', '420', '120',
      '-6.965', '106.28', 'beroperasi', '2026-11-07 08:00:00', '', 'Raja',
      diubah, 'foto/$kodePosko.jpg', ketinggian],
  ]);
  tambah('pengungsi.csv', [
    'kode', 'kode_posko', 'nama', 'asal', 'tanggal_lahir', 'nomor_kk', 'usia',
    'jenis_kelamin', 'kondisi_kesehatan', 'kelompok_rentan', 'riwayat_penyakit',
    'dicatat_oleh', 'dibuat_pada', 'diubah_pada', 'dihapus_pada',
    'status_keberadaan', 'keluar_pada', 'keterangan_keluar',
  ], pengungsi ?? [
    ['a1b2c3d4-0001-4000-8000-000000000001', kodePosko, 'Siti', 'Cikaret', '1990-01-01',
      '', '36', 'Perempuan', 'Sehat', 'Tidak', '', 'Raja', '2026-11-07 09:00:00',
      '2026-11-07 09:00:00', '', 'di_posko', '', ''],
    ['a1b2c3d4-0002-4000-8000-000000000002', kodePosko, 'Ujang', 'Cikaret', '2020-05-05',
      '3602010101010001', '6', 'Laki-laki', 'Sehat', 'Tidak', '', 'Raja',
      '2026-11-07 09:05:00', '2026-11-07 09:05:00', '', 'di_posko', '', ''],
  ]);
  tambah('barang_masuk.csv', [
    'kode', 'kode_posko', 'nama_item', 'kategori', 'satuan', 'jumlah_masuk',
    'sumber_bantuan', 'tanggal_masuk', 'keterangan', 'dicatat_oleh', 'dibuat_pada',
  ], [
    ['b1b2c3d4-0001-4000-8000-000000000001', kodePosko, 'Beras', 'Makanan', 'kg', '50',
      'Kiriman Pusat Logistik GMLS', '2026-11-07', '', 'Admin GMLS', '2026-11-07 10:00:00'],
  ]);
  tambah('barang_keluar.csv', [
    'kode', 'kode_posko', 'nama_item', 'kategori', 'satuan', 'jumlah_keluar',
    'tujuan', 'penerima', 'tanggal_keluar', 'keterangan', 'dicatat_oleh', 'dibuat_pada',
  ], [
    ['c1b2c3d4-0001-4000-8000-000000000001', kodePosko, 'Beras', 'Makanan', 'kg', '10',
      'dibagikan', '', '2026-11-07', '', 'Raja', '2026-11-07 12:00:00'],
  ]);
  tambah('stok.csv', ['kode_posko', 'nama_item', 'satuan', 'jumlah_stok'],
      [[kodePosko, 'Beras', 'kg', '$stokBeras']]);
  tambah('petugas.csv', ['kode_posko', 'peran', 'nama', 'kontak'],
      [[kodePosko, 'relawan', 'Raja', 'r@test.id']]);
  return ZipEncoder().encodeBytes(arsip);
}

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late SqliteTableStore hp;

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_website_');
    hp = SqliteTableStore(path: '${folder.path}/induk.db', factory: databaseFactoryFfi);
    await AdminRepository.withStore(hp).ensureDefaultAdmin();
  });

  tearDown(() async {
    await hp.close();
    await folder.delete(recursive: true);
  });

  Future<List<Posko>> semuaPosko() => PoskoRepository.withStore(hp).getAll();

  Future<int> stokBeras(int poskoId) async {
    final beras = (await BarangRepository.withStore(hp).getAll())
        .firstWhere((b) => b.namaItem == 'Beras');
    return LogistikRepository.withStore(hp).stokBarang(poskoId, beras.id!);
  }

  test('HP baru: posko dari website ditambahkan, pratinjau tidak menyimpan', () async {
    final paket = paketWebsite();

    final cek = await GabungPaketService.periksaWebsite(paket, store: hp);
    expect(cek.ringkasanPosko[BarisGabung.tambah], 1);
    expect(cek.ringkasanPengungsi[BarisGabung.tambah], 2);
    expect(cek.ringkasanMasuk[BarisGabung.tambah], 1);
    expect(cek.ringkasanKeluar[BarisGabung.tambah], 1);
    expect(await semuaPosko(), isEmpty, reason: 'pratinjau tidak menyimpan');

    final hasil = await GabungPaketService.terapkanWebsite(paket, store: hp);
    expect(hasil.selisihStok, isEmpty, reason: 'stok website 40 = 50 masuk - 10 keluar');
    expect(hasil.ringkasan, startsWith('Posko: 1 baru'));

    final posko = (await semuaPosko()).single;
    expect(posko.kode, _kodePosko, reason: 'kode website dipakai, supaya tidak dobel di website');
    expect(posko.nama, 'Bukit Evakuasi Pasir Gombong');
    expect(posko.kapasitas, 120);
    expect(posko.ketinggianMdpl, 45.5);
    expect(posko.statusOperasional, Posko.beroperasi);
    final pengungsi = await PengungsiRepository.withStore(hp).getAll();
    expect(pengungsi.map((p) => p.nama).toSet(), {'Siti', 'Ujang'});
    expect(pengungsi.every((p) => p.poskoId == posko.id), isTrue);
    expect(await stokBeras(posko.id!), 40);

    // Paket dari HP ini ke website membawa kode posko website & ketinggian
    final csv = (await PaketDataService.kumpulkan([posko], store: hp)).csv['posko.csv']!;
    final baris = CsvService.decode(csv).single;
    expect(baris['kode_posko'], _kodePosko);
    expect(baris['ketinggian_mdpl'], '45.5');
  });

  test('impor ulang tidak dobel; data website yang lebih baru memperbarui posko', () async {
    await GabungPaketService.terapkanWebsite(paketWebsite(), store: hp);
    final lagi = await GabungPaketService.periksaWebsite(paketWebsite(), store: hp);
    expect(lagi.adaPerubahan, isFalse);

    final baru = paketWebsite(ketinggian: '50', diubah: '2026-11-09 08:00:00', stokBeras: 55);
    final hasil = await GabungPaketService.terapkanWebsite(baru, store: hp);
    expect(hasil.ringkasanPosko[BarisGabung.perbarui], 1);
    expect((await semuaPosko()).single.ketinggianMdpl, 50);
    expect(await PengungsiRepository.withStore(hp).count(), 2);
    // Stok website berbeda dengan catatan -> diperingatkan, tidak diubah diam-diam
    expect(hasil.selisihStok.single, contains('website 55 kg, HP 40 kg'));
  });

  test('posko yang sudah ada (nama + desa sama, kode lain) disambungkan, bukan dobel', () async {
    final lokal = await PoskoRepository.withStore(hp).add(Posko.baru(
      nama: 'Bukit Evakuasi Pasir Gombong', namaDesa: 'SAWARNA', alamat: 'Jl. 1',
      luasLokasi: 350, latitude: '-6.9', longitude: '106.2',
    ));

    final cek = await GabungPaketService.periksaWebsite(paketWebsite(), store: hp);
    expect(cek.posko.single.alasan, contains('Disambungkan'));
    await GabungPaketService.terapkanWebsite(paketWebsite(), store: hp);

    final posko = (await semuaPosko()).single;
    expect(posko.id, lokal.id);
    expect(posko.kode, lokal.kode, reason: 'kode di HP tidak diganti (HP Anggota memakainya)');
    expect((await PengungsiRepository.withStore(hp).getAll()).every((p) => p.poskoId == lokal.id), isTrue);
  });

  test('nama sama tapi desa berbeda: posko itu tidak diambil', () async {
    await PoskoRepository.withStore(hp).add(Posko.baru(
      nama: 'Bukit Evakuasi Pasir Gombong', namaDesa: 'Bayah', alamat: 'Jl. 1',
      luasLokasi: 350, latitude: '-6.9', longitude: '106.2',
    ));
    await expectLater(GabungPaketService.periksaWebsite(paketWebsite(), store: hp),
        throwsA(isA<GabungException>().having((e) => e.message, 'pesan', contains('desa'))));
    expect((await semuaPosko()).length, 1);
  });

  test('jalur yang salah ditolak', () async {
    // Paket dari HP lain bukan lewat Import dari Website
    await expectLater(GabungPaketService.periksaWebsite(paketWebsite(sumber: ''), store: hp),
        throwsA(isA<GabungException>()));
    // Paket website bukan lewat Sinkron Antar-HP
    await expectLater(GabungPaketService.periksa(paketWebsite(), store: hp),
        throwsA(isA<GabungException>().having((e) => e.message, 'pesan', contains('website'))));
  });

  test('HP Anggota tidak boleh import dari website', () async {
    final posko = await PoskoRepository.withStore(hp).add(Posko.baru(
      nama: 'Balai Desa', namaDesa: 'Panggarangan', alamat: 'Jl. 1',
      luasLokasi: 350, latitude: '-6.9', longitude: '106.1',
    ));
    final admin = AdminRepository.withStore(hp);
    await admin.gantiPassword((await admin.getAll()).single, 'posko2026');
    final anggota = SqliteTableStore(path: '${folder.path}/anggota.db', factory: databaseFactoryFfi);
    final (_, file) = await PenyiapanService.buat(posko, store: hp);
    await PenyiapanService.terapkan(PenyiapanService.baca(file), store: anggota);

    await expectLater(GabungPaketService.periksaWebsite(paketWebsite(), store: anggota),
        throwsA(isA<GabungException>().having((e) => e.message, 'pesan', contains('HP Induk'))));
    await anggota.close();
  });

  test('paket terkunci dari website (PBKDF2 100.000 putaran) bisa dibuka', () {
    final paket = paketWebsite();
    final terkunci = BerkasTerkunci.kunci(paket, 'sandi123', iterasi: 100000);
    expect(BerkasTerkunci.terkunci(terkunci), isTrue);
    expect(BerkasTerkunci.buka(terkunci, 'sandi123'), paket);
    expect(() => BerkasTerkunci.buka(terkunci, 'salah'),
        throwsA(isA<BerkasTerkunciException>()));
  });

  group('ketinggian posko', () {
    test('tersimpan & ikut ke HP Anggota; paket versi lama tidak menghapusnya', () async {
      final repo = PoskoRepository.withStore(hp);
      final posko = await repo.add(Posko.baru(
        nama: 'Balai Desa', namaDesa: 'Panggarangan', alamat: 'Jl. 1',
        luasLokasi: 350, latitude: '-6.9', longitude: '106.1', ketinggianMdpl: 12.5,
      ));
      expect((await repo.findById(posko.id!))!.ketinggianMdpl, 12.5);

      // HP Anggota disiapkan dari HP Induk: ketinggian ikut
      final admin = AdminRepository.withStore(hp);
      await admin.gantiPassword((await admin.getAll()).single, 'posko2026');
      final anggota = SqliteTableStore(path: '${folder.path}/anggota.db', factory: databaseFactoryFfi);
      final (_, file) = await PenyiapanService.buat(posko, store: hp);
      await PenyiapanService.terapkan(PenyiapanService.baca(file), store: anggota);
      expect((await PoskoRepository.withStore(anggota).getAll()).single.ketinggianMdpl, 12.5);

      // Paket dari aplikasi versi lama (tanpa kolom ketinggian_mdpl), lebih baru
      final diAnggota = (await PoskoRepository.withStore(anggota).getAll()).single;
      final paket = await PaketDataService.kumpulkan([
        Posko(
          id: diAnggota.id, kode: diAnggota.kode, nama: 'Balai Desa',
          namaDesa: 'Panggarangan', alamat: 'Jl. 2', luasLokasi: 350,
          latitude: '-6.9', longitude: '106.1', ketinggianMdpl: 12.5,
          dibuatPada: diAnggota.dibuatPada,
          diubahPada: diAnggota.diubahPada.add(const Duration(minutes: 5)),
        ),
      ], store: anggota);
      final csv = Map.of(paket.csv);
      final rows = CsvService.decode(csv['posko.csv']!);
      csv['posko.csv'] = CsvService.encode(
          PaketData.kolomPosko.where((k) => k != 'ketinggian_mdpl').toList(),
          [for (final r in rows) [for (final k in PaketData.kolomPosko) if (k != 'ketinggian_mdpl') r[k] ?? '']]);
      final arsip = Archive();
      for (final e in csv.entries) {
        arsip.addFile(ArchiveFile.string(e.key, e.value));
      }
      await GabungPaketService.terapkan(ZipEncoder().encodeBytes(arsip), store: hp);
      final hasil = (await repo.findById(posko.id!))!;
      expect(hasil.alamat, 'Jl. 2');
      expect(hasil.ketinggianMdpl, 12.5);
      await anggota.close();
    });

    test('kode unik website valid untuk aplikasi', () {
      expect(KodeUnik.valid(_kodePosko), isTrue);
    });
  });
}
