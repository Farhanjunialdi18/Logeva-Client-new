// ============================================================
// riwayat_transaksi.dart
// Catatan setiap proses IMPORT / EXPORT CSV.
// ============================================================

import 'model_utils.dart';

class RiwayatTransaksi {
  static const String jenisImport = 'IMPORT';
  static const String jenisExport = 'EXPORT';

  final int? id;
  final String jenis; // IMPORT / EXPORT
  final String jenisData; // 'Data Pengungsi' / 'Data Logistik'
  final bool berhasil;
  final int jumlahBaris;
  final String keterangan;
  final DateTime waktu;

  const RiwayatTransaksi({
    this.id,
    required this.jenis,
    required this.jenisData,
    required this.berhasil,
    this.jumlahBaris = 0,
    this.keterangan = '',
    required this.waktu,
  });

  bool get isImport => jenis == jenisImport;

  Map<String, Object?> toMap() => {
        'id': id,
        'jenis': jenis,
        'jenis_data': jenisData,
        'status': berhasil ? 'BERHASIL' : 'GAGAL',
        'jumlah_baris': jumlahBaris,
        'keterangan': keterangan,
        'waktu': waktu.toIso8601String(),
      };

  factory RiwayatTransaksi.fromMap(Map<String, Object?> map) => RiwayatTransaksi(
        id: asInt(map['id']),
        jenis: asText(map['jenis']),
        jenisData: asText(map['jenis_data']),
        berhasil: asText(map['status']) == 'BERHASIL',
        jumlahBaris: asInt(map['jumlah_baris']) ?? 0,
        keterangan: asText(map['keterangan']),
        waktu: asDate(map['waktu']),
      );
}
