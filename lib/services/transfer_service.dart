// ============================================================
// transfer_service.dart
// Proses IMPORT & EXPORT CSV pengungsi (per posko, format website),
// sekaligus mencatat hasilnya ke Riwayat Transaksi.
// ============================================================

import '../data/repositories/pengungsi_repository.dart';
import '../data/repositories/riwayat_repository.dart';
import '../models/pengungsi.dart';
import '../models/posko.dart';
import '../models/riwayat_transaksi.dart';
import '../utils/date_formatter.dart';
import 'csv_service.dart';
import 'file_service.dart';
import 'pengungsi_csv.dart';
import 'session_service.dart';

enum TransferStatus { success, failed, cancelled }

class TransferResult {
  final TransferStatus status;
  final String message;

  const TransferResult(this.status, this.message);

  bool get isError => status == TransferStatus.failed;
}

class TransferService {
  TransferService._();

  static const String _labelPengungsi = 'Data Pengungsi';

  // ================= PENGUNGSI =================
  // Format = template Import Pengungsi website (per posko), lihat
  // pengungsi_csv.dart. Satu file = satu posko.

  static Future<TransferResult> exportPengungsi(Posko posko) async {
    final list = await PengungsiRepository.instance.getByPosko(posko.id);
    final tanpaLahir = list.where((e) => e.perluDilengkapi).length;
    final tanpaKk = list.where((e) => e.nomorKk.isEmpty).length;

    final hasil = await _export<Pengungsi>(
      jenisData: _labelPengungsi,
      filePrefix: 'pengungsi_${_namaFile(posko.nama)}',
      headers: PengungsiCsv.headers,
      load: () async => list,
      toRow: PengungsiCsv.toRow,
    );
    if (hasil.status != TransferStatus.success) return hasil;

    final catatan = [
      if (tanpaLahir > 0) '$tanpaLahir tanpa tanggal lahir',
      if (tanpaKk > 0) '$tanpaKk tanpa nomor KK',
    ];
    if (catatan.isEmpty) return hasil;
    return TransferResult(
      TransferStatus.success,
      '${hasil.message}\n\nPerhatian: ${catatan.join(' dan ')}. Import '
      'Pengungsi di website menolak baris seperti ini; lengkapi datanya '
      'atau kirim lewat Paket Data Posko.',
    );
  }

  /// Import CSV ke posko [posko]. Aturan sama dengan website:
  /// - semua baris harus valid, kalau ada yang salah TIDAK ADA yang disimpan;
  /// - nama + tanggal lahir sama dengan pengungsi di posko ini = diperbarui.
  static Future<TransferResult> importPengungsi(Posko posko) async {
    try {
      final file = await FileService.pickCsv();
      if (file == null) {
        return const TransferResult(
            TransferStatus.cancelled, 'Import dibatalkan.');
      }

      final rows = CsvService.decode(file.content);
      if (rows.isEmpty) throw const FormatException('File CSV kosong.');

      final lama = {
        for (final e in await PengungsiRepository.instance.getByPosko(posko.id))
          if (e.kunci != null) e.kunci!: e,
      };

      final error = <String>[];
      final dipakai = <String, int>{};
      final simpan = <Pengungsi>[];
      var tambah = 0, perbarui = 0;
      final pencatat = SessionService.instance.namaPencatat;

      for (var i = 0; i < rows.length; i++) {
        final nomor = i + 2; // baris 1 = judul kolom
        final baris = PengungsiCsv.baca(rows[i]);
        final masalah = [...baris.error];
        final kunci = baris.kunci;
        if (kunci != null && dipakai.containsKey(kunci)) {
          masalah.add('Pengungsi sama dengan baris ${dipakai[kunci]}');
        } else if (kunci != null) {
          dipakai[kunci] = nomor;
        }
        if (masalah.isNotEmpty) {
          error.add('Baris $nomor: ${masalah.join('; ')}');
          continue;
        }

        final ada = lama[kunci];
        if (ada == null) {
          simpan.add(baris.keBaru(posko.id!, pencatat));
          tambah++;
        } else {
          simpan.add(baris.perbarui(ada));
          perbarui++;
        }
      }

      if (error.isNotEmpty) {
        final contoh = error.take(3).join('\n');
        final sisa =
            error.length > 3 ? '\n...dan ${error.length - 3} lainnya' : '';
        throw FormatException(
            '${error.length} baris bermasalah, tidak ada data yang disimpan.'
            '\n$contoh$sisa');
      }

      await PengungsiRepository.instance.simpanBanyak(simpan);
      await RiwayatRepository.instance.log(
        jenis: RiwayatTransaksi.jenisImport,
        jenisData: _labelPengungsi,
        berhasil: true,
        jumlahBaris: simpan.length,
        keterangan: '${posko.label}: $tambah baru, $perbarui diperbarui',
      );
      return TransferResult(
        TransferStatus.success,
        '${simpan.length} baris diimpor ke ${posko.label}: '
        '$tambah baru, $perbarui diperbarui.',
      );
    } catch (e) {
      final pesan = e is FormatException ? e.message : '$e';
      await RiwayatRepository.instance.log(
        jenis: RiwayatTransaksi.jenisImport,
        jenisData: _labelPengungsi,
        berhasil: false,
        keterangan: pesan,
      );
      return TransferResult(TransferStatus.failed, 'Import gagal: $pesan');
    }
  }

  /// "Posko Balai Desa" -> "Posko_Balai_Desa" (aman untuk nama file).
  static String _namaFile(String nama) =>
      nama.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');

  // ================= PROSES UMUM =================

  static Future<TransferResult> _export<T>({
    required String jenisData,
    required String filePrefix,
    required List<String> headers,
    required Future<List<T>> Function() load,
    required List<String> Function(T item) toRow,
  }) async {
    try {
      final items = await load();
      if (items.isEmpty) {
        return TransferResult(
          TransferStatus.failed,
          'Belum ada ${jenisData.toLowerCase()} untuk diekspor.',
        );
      }

      final csv = CsvService.encode(headers, items.map(toRow).toList());
      final fileName =
          '${filePrefix}_${DateFormatter.fileStamp(DateTime.now())}.csv';

      final saved = await FileService.saveCsv(fileName, csv);
      if (!saved) {
        return const TransferResult(
            TransferStatus.cancelled, 'Ekspor dibatalkan.');
      }

      await RiwayatRepository.instance.log(
        jenis: RiwayatTransaksi.jenisExport,
        jenisData: jenisData,
        berhasil: true,
        jumlahBaris: items.length,
      );
      return TransferResult(
        TransferStatus.success,
        '${items.length} baris berhasil diekspor ke $fileName',
      );
    } catch (e) {
      await RiwayatRepository.instance.log(
        jenis: RiwayatTransaksi.jenisExport,
        jenisData: jenisData,
        berhasil: false,
        keterangan: '$e',
      );
      return TransferResult(TransferStatus.failed, 'Ekspor gagal: $e');
    }
  }
}
