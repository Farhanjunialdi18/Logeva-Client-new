// ============================================================
// transfer_service.dart
// Proses IMPORT & EXPORT CSV untuk pengungsi dan logistik,
// sekaligus mencatat hasilnya ke Riwayat Transaksi.
// ============================================================

import '../data/repositories/logistik_repository.dart';
import '../data/repositories/pengungsi_repository.dart';
import '../data/repositories/riwayat_repository.dart';
import '../models/logistik.dart';
import '../models/pengungsi.dart';
import '../models/riwayat_transaksi.dart';
import '../utils/date_formatter.dart';
import 'csv_service.dart';
import 'file_service.dart';
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
  static const String _labelLogistik = 'Data Logistik';

  // ================= PENGUNGSI =================

  static Future<TransferResult> exportPengungsi() {
    return _export<Pengungsi>(
      jenisData: _labelPengungsi,
      filePrefix: 'pengungsi',
      headers: Pengungsi.csvHeaders,
      load: PengungsiRepository.instance.getAll,
      toRow: (e) => e.toCsvRow(),
    );
  }

  /// [defaultPosko] dipakai untuk baris CSV yang kolom posko-nya kosong.
  /// Kosongkan untuk memakai posko relawan yang sedang login.
  static Future<TransferResult> importPengungsi({String? defaultPosko}) {
    final posko = defaultPosko ?? SessionService.instance.posko;
    return _import<Pengungsi>(
      jenisData: _labelPengungsi,
      parse: (row) => Pengungsi.fromCsv(row, posko),
      save: PengungsiRepository.instance.addMany,
    );
  }

  // ================= LOGISTIK =================

  static Future<TransferResult> exportLogistik() {
    return _export<Logistik>(
      jenisData: _labelLogistik,
      filePrefix: 'logistik',
      headers: Logistik.csvHeaders,
      load: LogistikRepository.instance.getAll,
      toRow: (e) => e.toCsvRow(),
    );
  }

  /// [defaultPosko]: lihat penjelasan di importPengungsi.
  static Future<TransferResult> importLogistik({String? defaultPosko}) {
    final posko = defaultPosko ?? SessionService.instance.posko;
    return _import<Logistik>(
      jenisData: _labelLogistik,
      parse: (row) => Logistik.fromCsv(row, posko),
      save: LogistikRepository.instance.addMany,
    );
  }

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

  static Future<TransferResult> _import<T>({
    required String jenisData,
    required T? Function(Map<String, String> row) parse,
    required Future<void> Function(List<T> items) save,
  }) async {
    try {
      final file = await FileService.pickCsv();
      if (file == null) {
        return const TransferResult(
            TransferStatus.cancelled, 'Import dibatalkan.');
      }

      final rows = CsvService.decode(file.content);
      if (rows.isEmpty) {
        throw const FormatException('File CSV kosong.');
      }

      final items = rows.map(parse).whereType<T>().toList();
      if (items.isEmpty) {
        throw const FormatException(
            'Tidak ada baris yang valid. Periksa nama kolom CSV.');
      }

      await save(items);

      final dilewati = rows.length - items.length;
      await RiwayatRepository.instance.log(
        jenis: RiwayatTransaksi.jenisImport,
        jenisData: jenisData,
        berhasil: true,
        jumlahBaris: items.length,
        keterangan: dilewati > 0 ? '$dilewati baris dilewati' : '',
      );

      final extra = dilewati > 0 ? ' ($dilewati baris tidak valid dilewati)' : '';
      return TransferResult(
        TransferStatus.success,
        '${items.length} baris berhasil diimpor$extra.',
      );
    } catch (e) {
      final pesan = e is FormatException ? e.message : '$e';
      await RiwayatRepository.instance.log(
        jenis: RiwayatTransaksi.jenisImport,
        jenisData: jenisData,
        berhasil: false,
        keterangan: pesan,
      );
      return TransferResult(TransferStatus.failed, 'Import gagal: $pesan');
    }
  }
}
