// Tes Paket Data Posko (§8): isi ZIP, judul kolom persis, format nilai,
// data dihapus ikut, posko lain tidak ikut, dan pemeriksaan sebelum ekspor.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
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
import 'package:flutter_application_1/services/csv_service.dart';
import 'package:flutter_application_1/services/paket_data_service.dart';
import 'package:flutter_application_1/utils/kode_unik.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late Directory folder;
  late SqliteTableStore store;
  late Posko posko;
  late Posko lain;

  // 23 Okt 2026 07:05 UTC = 14:05 WIB
  final waktu = DateTime.utc(2026, 10, 23, 7, 5);

  setUp(() async {
    folder = await Directory.systemTemp.createTemp('logeva_paket_');
    store = SqliteTableStore(
        path: '${folder.path}/logeva.db', factory: databaseFactoryFfi);
    final poskoRepo = PoskoRepository.withStore(store);
    posko = await poskoRepo.add(Posko.baru(
      nama: 'Balai Desa Panggarangan',
      namaDesa: 'Panggarangan',
      alamat: 'Jl. Raya, No. 1',
      luasLokasi: 1050.5,
      latitude: '-6.9195',
      longitude: '106.1297',
    ));
    lain = await poskoRepo.add(Posko.baru(nama: 'Cisolok'));

    final admin = AdminRepository.withStore(store);
    await admin.add(
      nama: 'Bu Rina',
      username: 'rina',
      email: 'rina@gmls.id',
      password: 'posko2026',
    );
    await admin.add(
      nama: 'Nonaktif',
      username: 'lama',
      email: 'lama@gmls.id',
      password: 'posko2026',
      status: DataOptions.statusNonaktif,
    );
    final relawanRepo = RelawanRepository.withStore(store);
    await relawanRepo.add(Relawan(
      nama: 'Andi',
      kontak: '0812-3456-7890',
      pin: '111111',
      dibuatPada: DateTime(2026),
    ).tempatkan(posko));
    await relawanRepo.add(Relawan(
      nama: 'Relawan Nonaktif',
      kontak: 'x',
      pin: '222222',
      status: DataOptions.statusNonaktif,
      dibuatPada: DateTime(2026),
    ).tempatkan(posko));

    final pengungsi = PengungsiRepository.withStore(store);
    await pengungsi.add(Pengungsi.baru(
      poskoId: posko.id,
      nama: 'Siti "Uti", Aminah',
      asal: 'Desa Cikaret',
      tanggalLahir: DateTime(1958, 3, 12),
      jenisKelamin: DataOptions.perempuan,
      nomorKk: '3602011203580001',
      kelompokRentan: 'Lansia',
      dicatatOleh: 'Andi',
    ));
    await pengungsi.add(Pengungsi.baru(
      poskoId: posko.id,
      nama: 'Budi',
      asal: 'X',
      tanggalLahir: DateTime(1990, 7, 25),
      jenisKelamin: DataOptions.lakiLaki,
    ));
    await pengungsi.add(Pengungsi.baru(
      poskoId: lain.id,
      nama: 'Orang Posko Lain',
      asal: 'Y',
      tanggalLahir: DateTime(1990, 1, 1),
      jenisKelamin: DataOptions.lakiLaki,
    ));
    final budi =
        (await pengungsi.getByPosko(posko.id)).firstWhere((e) => e.nama == 'Budi');
    await pengungsi.hapus(budi);

    final beras = (await BarangRepository.withStore(store).getAll()).first;
    final logistik = LogistikRepository.withStore(store);
    await logistik.catatMasuk(BarangMasuk.baru(
      poskoId: posko.id!,
      barang: beras,
      jumlah: 50,
      sumberBantuan: 'BPBD',
      tanggal: DateTime(2026, 10, 20),
    ));
    await logistik.catatKeluar(
      BarangKeluar.baru(
        poskoId: posko.id!,
        barang: beras,
        jumlah: 12,
        tujuan: 'dapur_umum',
        tanggal: DateTime(2026, 10, 21),
      ),
      barang: beras,
    );
  });

  tearDown(() async {
    await store.close();
    await folder.delete(recursive: true);
  });

  Future<PaketData> kumpulkan(List<Posko> list) => PaketDataService.kumpulkan(
        list,
        store: store,
        kodePerangkat: '11111111-1111-4111-8111-111111111111',
        dieksporOleh: 'Admin GMLS',
        waktu: waktu,
      );

  /// Buka ZIP lalu baca setiap CSV.
  Map<String, List<Map<String, String>>> bukaZip(PaketData paket) {
    final arsip = ZipDecoder().decodeBytes(paket.zip);
    return {
      for (final f in arsip.files)
        f.name: CsvService.decode(utf8.decode(f.content)),
    };
  }

  test('nama file sesuai §8', () async {
    final paket = await kumpulkan([posko]);
    expect(paket.namaFile, 'paket_BalaiDesaPanggarangan_20261023-1405.zip');
    expect((await kumpulkan([posko, lain])).namaFile,
        'paket_SemuaPosko_20261023-1405.zip');
  });

  test('ZIP berisi 7 CSV di akar dengan judul kolom persis', () async {
    final paket = await kumpulkan([posko]);
    final arsip = ZipDecoder().decodeBytes(paket.zip);
    expect(arsip.files.map((f) => f.name).toSet(), {
      'info.csv', 'posko.csv', 'pengungsi.csv', 'barang_masuk.csv',
      'barang_keluar.csv', 'stok.csv', 'petugas.csv',
    });
    String judul(String nama) => utf8
        .decode(arsip.files.firstWhere((f) => f.name == nama).content)
        .split('\r\n')
        .first;
    expect(judul('info.csv'),
        'versi_format,dibuat_pada,kode_perangkat,diekspor_oleh,peran_perangkat');
    expect(judul('posko.csv'), PaketData.kolomPosko.join(','));
    expect(judul('pengungsi.csv'), PaketData.kolomPengungsi.join(','));
    expect(judul('barang_masuk.csv'), PaketData.kolomMasuk.join(','));
    expect(judul('barang_keluar.csv'), PaketData.kolomKeluar.join(','));
    expect(judul('stok.csv'), 'kode_posko,nama_item,satuan,jumlah_stok');
    expect(judul('petugas.csv'), 'kode_posko,peran,nama,kontak,kode_akun');
    final info = utf8.decode(arsip.files.firstWhere((f) => f.name == 'info.csv').content);
    expect(info.startsWith('\ufeff'), isFalse, reason: 'UTF-8 tanpa BOM');
  });

  test('isi & format nilai', () async {
    final isi = bukaZip(await kumpulkan([posko]));

    final info = isi['info.csv']!.single;
    expect(info['versi_format'], '1');
    expect(info['dibuat_pada'], '2026-10-23 14:05:00');
    expect(info['kode_perangkat'], '11111111-1111-4111-8111-111111111111');
    expect(info['diekspor_oleh'], 'Admin GMLS');
    expect(info['peran_perangkat'], 'induk');

    final p = isi['posko.csv']!.single;
    expect(p['kode_posko'], posko.kode);
    expect(p['nama_lokasi'], 'Balai Desa Panggarangan');
    expect(p['alamat_lokasi'], 'Jl. Raya, No. 1', reason: 'koma dikutip');
    expect(p['luas_lokasi'], '1050.5', reason: 'desimal titik');
    expect(p['kapasitas_pengungsi'], '300');
    expect(p['status_operasional'], 'siaga');
    expect(p['mulai_beroperasi_at'], '');
    expect(p['relawan_penanggung_jawab'], 'Andi');
    expect(p['diubah_pada'], matches(RegExp(r'^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$')));

    final pengungsi = isi['pengungsi.csv']!;
    expect(pengungsi, hasLength(2), reason: 'posko lain tidak ikut');
    final siti = pengungsi.firstWhere((r) => r['nama']!.startsWith('Siti'));
    expect(siti['nama'], 'Siti "Uti", Aminah');
    expect(siti['kode_posko'], posko.kode);
    expect(siti['tanggal_lahir'], '1958-03-12');
    expect(siti['nomor_kk'], '3602011203580001');
    expect(siti['jenis_kelamin'], 'Perempuan');
    expect(siti['kelompok_rentan'], 'Lansia');
    expect(siti['kondisi_kesehatan'], 'Sehat');
    expect(siti['riwayat_penyakit'], '');
    expect(siti['dicatat_oleh'], 'Andi');
    expect(siti['dihapus_pada'], '');

    final budi = pengungsi.firstWhere((r) => r['nama'] == 'Budi');
    expect(budi['dihapus_pada'], isNotEmpty, reason: 'penghapusan ikut terkirim');
    expect(budi['nomor_kk'], '');

    final masuk = isi['barang_masuk.csv']!.single;
    expect(masuk['nama_item'], 'Beras');
    expect(masuk['kategori'], 'Makanan');
    expect(masuk['satuan'], 'kg');
    expect(masuk['jumlah_masuk'], '50');
    expect(masuk['sumber_bantuan'], 'BPBD');
    expect(masuk['tanggal_masuk'], '2026-10-20');

    final keluar = isi['barang_keluar.csv']!.single;
    expect(keluar['tujuan'], 'dapur_umum');
    expect(keluar['jumlah_keluar'], '12');
    expect(keluar['tanggal_keluar'], '2026-10-21');

    final stok = isi['stok.csv']!.single;
    expect(stok, {
      'kode_posko': posko.kode,
      'nama_item': 'Beras',
      'satuan': 'kg',
      'jumlah_stok': '38',
    });
  });

  test('petugas: admin & relawan AKTIF dengan kontak, tanpa PIN/password',
      () async {
    final paket = await kumpulkan([posko]);
    final isi = bukaZip(paket);
    final petugas = isi['petugas.csv']!;
    expect(petugas.map((r) => [r['kode_posko'], r['peran'], r['nama'], r['kontak']]), [
      ['', 'admin', 'Bu Rina', 'rina@gmls.id'],
      [posko.kode, 'relawan', 'Andi', '0812-3456-7890'],
    ]);
    expect(petugas.every((r) => KodeUnik.valid(r['kode_akun']!)), isTrue,
        reason: 'kode akun sama di semua HP -> pusat tidak menampilkan dobel');
    // Tidak ada PIN / password / hash di file mana pun (isi CSV setelah diekstrak).
    for (final rows in isi.values) {
      for (final r in rows) {
        expect(r.keys.any((k) => k.contains('pin') || k.contains('password')),
            isFalse);
        expect(r.values, isNot(contains('111111')), reason: 'PIN relawan');
        expect(r.values.any((v) => v.contains('posko2026')), isFalse,
            reason: 'password admin');
      }
    }
  });

  test('peringatan kontak admin bawaan & posko tanpa relawan', () async {
    await AdminRepository.withStore(store).ensureDefaultAdmin(); // tidak menambah
    await AdminRepository.withStore(store).add(
      nama: 'Admin GMLS 2',
      username: 'admin2',
      email: AdminRepository.defaultEmail,
      password: 'posko2026',
    );
    final hasil = PaketDataService.periksa(await kumpulkan([posko, lain]));
    final semua = hasil.peringatan.join(' | ');
    expect(semua, contains('Kontak admin Admin GMLS 2'));
    expect(semua, contains('Posko Cisolok: belum ada relawan aktif'));
  });

  test('ekspor dua kali menghasilkan kode yang sama (aman diimpor ulang)',
      () async {
    final a = bukaZip(await kumpulkan([posko]));
    final b = bukaZip(await kumpulkan([posko]));
    for (final file in ['pengungsi.csv', 'barang_masuk.csv', 'barang_keluar.csv']) {
      expect(b[file]!.map((r) => r['kode']), a[file]!.map((r) => r['kode']));
    }
  });

  test('posko belum lengkap menghalangi ekspor', () async {
    expect(PaketDataService.periksa(await kumpulkan([posko])).bisaEkspor, isTrue);
    final hasil = PaketDataService.periksa(await kumpulkan([posko, lain]));
    expect(hasil.bisaEkspor, isFalse);
    expect(hasil.penghalang.single, contains('Posko Cisolok'));
    expect(hasil.penghalang.single, contains('Latitude'));
    expect(PaketDataService.periksa(await kumpulkan([])).bisaEkspor, isFalse);
  });

  test('pengungsi lama tanpa tanggal lahir hanya diperingatkan', () async {
    await store.insert('pengungsi', {
      'kode': '22222222-2222-4222-8222-222222222222',
      'posko_id': posko.id,
      'nama': 'Data Lama',
      'asal': '',
      'usia': 40,
      'jenis_kelamin': 'Laki-laki',
      'dibuat_pada': '2026-10-01T08:00:00.000',
      'diubah_pada': '2026-10-01T08:00:00.000',
    });
    final paket = await kumpulkan([posko]);
    final hasil = PaketDataService.periksa(paket);
    expect(hasil.bisaEkspor, isTrue);
    expect(hasil.peringatan.single, contains('1 pengungsi belum punya tanggal'));
    final lama = bukaZip(paket)['pengungsi.csv']!
        .firstWhere((r) => r['nama'] == 'Data Lama');
    expect(lama['tanggal_lahir'], '');
  });
}
