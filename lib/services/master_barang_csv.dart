// ============================================================
// master_barang_csv.dart
// IMPORT MASTER BARANG dari file "Export CSV (Aplikasi)" Master Logistik
// website (atau file Export Excel yang disimpan sebagai CSV). Kolom & aturan
// sama dengan import Master Logistik website (LogistikImportController):
//   Nama Item*, Kategori*, Satuan*, Kebutuhan Harian, Deskripsi
// Barang sama = kategori + nama sama -> diperbarui. Kalau ada baris
// yang salah, TIDAK ADA yang disimpan.
// ============================================================

import '../data/repositories/barang_repository.dart';
import '../data/repositories/riwayat_repository.dart';
import '../models/barang.dart';
import '../models/riwayat_transaksi.dart';
import '../utils/angka.dart';
import 'csv_service.dart';
import 'file_service.dart';
import 'transfer_service.dart';

class MasterBarangCsv {
  MasterBarangCsv._();

  static const String _label = 'Master Barang';

  static const List<String> headers = [
    'Nama Item',
    'Kategori',
    'Satuan',
    'Kebutuhan Harian',
    'Deskripsi',
  ];

  static const Map<String, List<String>> _alias = {
    'nama_item': ['nama_item', 'item', 'nama_barang', 'nama_logistik'],
    'kategori': ['kategori', 'kategori_logistik', 'nama_kategori'],
    'satuan': ['satuan', 'unit'],
    'kebutuhan_harian': [
      'kebutuhan_harian', 'kebutuhan_per_hari', 'kebutuhan',
    ],
    'deskripsi': ['deskripsi', 'keterangan'],
  };

  static String? _ambil(Map<String, String> row, String kolom) {
    for (final nama in _alias[kolom]!) {
      final v = row[nama]?.trim().replaceAll(RegExp(r'\s+'), ' ');
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  /// Baca semua baris jadi daftar barang siap simpan. Melempar
  /// FormatException berisi daftar kesalahan kalau ada baris yang salah.
  static List<Barang> baca(
    List<Map<String, String>> rows, {
    required List<KategoriLogistik> kategori,
    required List<Barang> lama,
  }) {
    final kategoriByNama = {for (final k in kategori) k.nama.toLowerCase(): k};
    final lamaByKunci = {for (final b in lama) b.kunci: b};
    final dipakai = <String, int>{};
    final error = <String>[];
    final hasil = <Barang>[];

    for (var i = 0; i < rows.length; i++) {
      final nomor = i + 1;
      final r = rows[i];
      final masalah = <String>[];

      final nama = _ambil(r, 'nama_item');
      final katNama = _ambil(r, 'kategori');
      final satuan = _ambil(r, 'satuan');
      final teksKebutuhan = _ambil(r, 'kebutuhan_harian');
      final deskripsi = _ambil(r, 'deskripsi');
      final kat = katNama == null ? null : kategoriByNama[katNama.toLowerCase()];

      if (nama == null) masalah.add('Nama item kosong');
      if (katNama == null) {
        masalah.add('Kategori kosong');
      } else if (kat == null) {
        masalah.add('Kategori "$katNama" tidak ada di sistem');
      }
      if (satuan == null) masalah.add('Satuan kosong');

      final kebutuhan = Angka.baca(teksKebutuhan);
      if (teksKebutuhan != null && kebutuhan == null) {
        masalah.add('Kebutuhan harian harus berupa angka');
      } else if (kebutuhan != null && kebutuhan < 0) {
        masalah.add('Kebutuhan harian tidak boleh negatif');
      }

      final kunci =
          kat != null && nama != null ? Barang.kunciSama(kat.id, nama) : null;
      if (kunci != null && dipakai.containsKey(kunci)) {
        masalah.add('Item sama dengan baris ${dipakai[kunci]}');
      } else if (kunci != null) {
        dipakai[kunci] = nomor;
      }

      if (masalah.isNotEmpty) {
        error.add('Baris data $nomor: ${masalah.join('; ')}');
        continue;
      }

      // Dibulatkan 2 desimal seperti DECIMAL(10,2) di website.
      final bulat =
          kebutuhan == null ? null : (kebutuhan * 100).roundToDouble() / 100;
      final ada = lamaByKunci[kunci];
      hasil.add(ada == null
          ? Barang.baru(
              kategoriId: kat!.id,
              namaItem: nama!,
              satuan: satuan!,
              kebutuhanHarian: bulat,
              deskripsi: deskripsi ?? '',
            )
          : ada.ubahData(
              kategoriId: ada.kategoriId,
              namaItem: nama!,
              satuan: satuan!,
              kebutuhanHarian: bulat ?? ada.kebutuhanHarian,
              deskripsi: deskripsi ?? ada.deskripsi,
            ));
    }

    if (error.isNotEmpty) {
      final sisa = error.length > 3 ? '\n...dan ${error.length - 3} lainnya' : '';
      throw FormatException(
          '${error.length} baris bermasalah, tidak ada data yang disimpan.\n'
          '${error.take(3).join('\n')}$sisa');
    }
    return hasil;
  }

  /// Pilih file CSV lalu simpan ke master barang.
  static Future<TransferResult> import() async {
    try {
      final file = await FileService.pickCsv();
      if (file == null) {
        return const TransferResult(
            TransferStatus.cancelled, 'Import dibatalkan.');
      }

      final rows = CsvService.decode(
        file.content,
        cariJudul: const ['kategori', 'satuan'],
      );
      if (rows.isEmpty) {
        throw const FormatException(
            'Tidak ada data. Pastikan file berisi kolom Nama Item, Kategori, '
            'dan Satuan.');
      }

      final repo = BarangRepository.instance;
      final list = baca(
        rows,
        kategori: await repo.getKategori(),
        lama: await repo.getAll(),
      );
      final baru = list.where((b) => b.id == null).length;
      await repo.simpanBanyak(list);

      await RiwayatRepository.instance.log(
        jenis: RiwayatTransaksi.jenisImport,
        jenisData: _label,
        berhasil: true,
        jumlahBaris: list.length,
        keterangan: '$baru baru, ${list.length - baru} diperbarui',
      );
      return TransferResult(
        TransferStatus.success,
        '${list.length} barang diimpor: $baru baru, '
        '${list.length - baru} diperbarui.',
      );
    } catch (e) {
      final pesan = e is FormatException ? e.message : '$e';
      await RiwayatRepository.instance.log(
        jenis: RiwayatTransaksi.jenisImport,
        jenisData: _label,
        berhasil: false,
        keterangan: pesan,
      );
      return TransferResult(TransferStatus.failed, 'Import gagal: $pesan');
    }
  }
}
