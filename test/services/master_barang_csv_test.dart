import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/models/barang.dart';
import 'package:flutter_application_1/services/csv_service.dart';
import 'package:flutter_application_1/services/master_barang_csv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final kategori = [
    for (final (i, nama) in DataOptions.kategoriLogistik.indexed)
      KategoriLogistik(id: i + 1, nama: nama),
  ];
  final berasLama = Barang.fromMap(Barang.baru(
    kategoriId: 1,
    namaItem: 'Beras',
    satuan: 'kg',
    kebutuhanHarian: 0.3,
    deskripsi: 'Lama',
  ).toMap()
    ..['id'] = 1);

  // File "Export Master Logistik" website yang disimpan sebagai CSV dari
  // Excel: ada baris judul laporan di atas tabel, pemisah titik koma.
  const fileWebsite = 'MASTER LOGISTIK - GMLS LOGEVA;;;;;\r\n'
      ';;;;;\r\n'
      'No;Nama Item;Kategori;Satuan;Kebutuhan Harian;Deskripsi\r\n'
      '1;Beras;Makanan;kg;0,4;\r\n'
      '2;Air Mineral;Minuman;liter;3;Botol 600 ml\r\n'
      '3;Popok Bayi;Bayi & Anak;pcs;;\r\n';

  List<Map<String, String>> decode(String isi) =>
      CsvService.decode(isi, cariJudul: const ['kategori', 'satuan']);

  test('baris judul laporan dilewati, kolom terbaca', () {
    final rows = decode(fileWebsite);
    expect(rows, hasLength(3));
    expect(rows.first['nama_item'], 'Beras');
  });

  test('barang lama diperbarui, barang baru ditambah', () {
    final hasil = MasterBarangCsv.baca(
      decode(fileWebsite),
      kategori: kategori,
      lama: [berasLama],
    );
    expect(hasil, hasLength(3));

    final beras = hasil.first;
    expect(beras.id, 1, reason: 'kategori + nama sama = diperbarui');
    expect(beras.kebutuhanHarian, 0.4);
    expect(beras.deskripsi, 'Lama', reason: 'kolom kosong tidak menghapus');

    final air = hasil[1];
    expect(air.id, isNull);
    expect(air.kategoriId, 2);
    expect(air.kebutuhanHarian, 3);

    expect(hasil[2].kebutuhanHarian, isNull);
    expect(hasil[2].isPokok, isFalse);
  });

  test('ada baris salah -> tidak ada yang disimpan', () {
    const isi = 'Nama Item,Kategori,Satuan,Kebutuhan Harian\r\n'
        'Beras,Makanan,kg,0.3\r\n'
        'Terpal,Alat Berat,lembar,\r\n'
        ',Makanan,kg,\r\n'
        'Gula,Makanan,kg,-1\r\n'
        'beras,makanan,kg,\r\n';
    expect(
      () => MasterBarangCsv.baca(decode(isi), kategori: kategori, lama: []),
      throwsA(isA<FormatException>()
          .having((e) => e.message, 'pesan', contains('4 baris bermasalah'))
          .having((e) => e.message, 'pesan',
              contains('Kategori "Alat Berat" tidak ada di sistem'))),
    );
  });

  test('file tanpa kolom wajib -> kosong', () {
    expect(decode('a,b,c\r\n1,2,3\r\n'), isEmpty);
  });

  test('file "Export CSV (Aplikasi)" website langsung terbaca', () {
    // Persis keluaran LogistikImportController::exportCsv (BOM, koma,
    // kolom berspasi diberi tanda kutip, desimal pakai koma).
    const isi = '﻿"Nama Item",Kategori,Satuan,"Kebutuhan Harian",Deskripsi\n'
        '"Air, kemasan ""gelas""",Minuman,liter,"2,5",\n'
        'Beras,Makanan,kg,0,\n'
        '"Popok Bayi","Bayi & Anak",pcs,,"Ukuran M"\n';
    final hasil =
        MasterBarangCsv.baca(decode(isi), kategori: kategori, lama: []);
    expect(hasil.map((b) => b.namaItem),
        ['Air, kemasan "gelas"', 'Beras', 'Popok Bayi']);
    expect(hasil.first.kebutuhanHarian, 2.5);
    expect(hasil[2].deskripsi, 'Ukuran M');
  });
}
