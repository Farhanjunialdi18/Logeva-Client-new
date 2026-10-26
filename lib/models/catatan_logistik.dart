// ============================================================
// catatan_logistik.dart
// CATATAN BARANG MASUK & KELUAR, mengikuti tabel `stok_masuks` dan
// `stok_keluars` website, ditambah [kode] unik untuk Paket Data Posko.
//
// Catatan bersifat TETAP: tidak bisa diedit atau dihapus. Kalau ada
// kesalahan, buat catatan baru (misal barang keluar tujuan "lainnya"
// dengan keterangan "koreksi").
// ============================================================

import '../core/data_options.dart';
import '../utils/kode_unik.dart';
import '../utils/tanggal.dart';
import 'barang.dart';
import 'model_utils.dart';

/// Bagian yang sama dari barang masuk & keluar.
abstract class CatatanLogistik {
  int? get id;
  String get kode;
  int? get poskoId;
  int get barangId;
  int get jumlah;
  DateTime get tanggal;
  String get keterangan;
  String get dicatatOleh;
  DateTime get dibuatPada;

  bool get isMasuk;

  /// Ringkasan untuk daftar, misal "BNPB" atau "Dibagikan ke pengungsi".
  String get ringkasan;
}

class BarangMasuk implements CatatanLogistik {
  @override
  final int? id;
  @override
  final String kode;
  @override
  final int? poskoId;
  @override
  final int barangId;
  @override
  final int jumlah; // jumlah_masuk, >= 1
  final String sumberBantuan;
  @override
  final DateTime tanggal; // tanggal_masuk
  @override
  final String keterangan;
  @override
  final String dicatatOleh;
  @override
  final DateTime dibuatPada;

  const BarangMasuk({
    this.id,
    required this.kode,
    required this.poskoId,
    required this.barangId,
    required this.jumlah,
    required this.sumberBantuan,
    required this.tanggal,
    this.keterangan = '',
    this.dicatatOleh = '',
    required this.dibuatPada,
  });

  factory BarangMasuk.baru({
    required int poskoId,
    required Barang barang,
    required int jumlah,
    required String sumberBantuan,
    required DateTime tanggal,
    String keterangan = '',
    String dicatatOleh = '',
  }) =>
      BarangMasuk(
        kode: KodeUnik.buat(),
        poskoId: poskoId,
        barangId: barang.id!,
        jumlah: jumlah,
        sumberBantuan: sumberBantuan,
        tanggal: tanggal,
        keterangan: keterangan,
        dicatatOleh: dicatatOleh,
        dibuatPada: DateTime.now(),
      );

  @override
  bool get isMasuk => true;

  @override
  String get ringkasan => sumberBantuan;

  Map<String, Object?> toMap() => {
        'id': id,
        'kode': kode,
        'posko_id': poskoId,
        'barang_id': barangId,
        'jumlah_masuk': jumlah,
        'sumber_bantuan': sumberBantuan,
        'tanggal_masuk': Tanggal.format(tanggal),
        'keterangan': keterangan.isEmpty ? null : keterangan,
        'dicatat_oleh': dicatatOleh.isEmpty ? null : dicatatOleh,
        'dibuat_pada': dibuatPada.toIso8601String(),
      };

  factory BarangMasuk.fromMap(Map<String, Object?> map) => BarangMasuk(
        id: asInt(map['id']),
        kode: asText(map['kode']),
        poskoId: asInt(map['posko_id']),
        barangId: asInt(map['barang_id']) ?? 0,
        jumlah: asInt(map['jumlah_masuk']) ?? 0,
        sumberBantuan: asText(map['sumber_bantuan']),
        tanggal: Tanggal.baca(asText(map['tanggal_masuk'])) ??
            asDate(map['dibuat_pada']),
        keterangan: asText(map['keterangan']),
        dicatatOleh: asText(map['dicatat_oleh']),
        dibuatPada: asDate(map['dibuat_pada']),
      );
}

class BarangKeluar implements CatatanLogistik {
  @override
  final int? id;
  @override
  final String kode;
  @override
  final int? poskoId;
  @override
  final int barangId;
  @override
  final int jumlah; // jumlah_keluar, >= 1
  final String tujuan; // kunci DataOptions.tujuanKeluar
  final String penerima;
  @override
  final DateTime tanggal; // tanggal_keluar
  @override
  final String keterangan;
  @override
  final String dicatatOleh;
  @override
  final DateTime dibuatPada;

  const BarangKeluar({
    this.id,
    required this.kode,
    required this.poskoId,
    required this.barangId,
    required this.jumlah,
    required this.tujuan,
    this.penerima = '',
    required this.tanggal,
    this.keterangan = '',
    this.dicatatOleh = '',
    required this.dibuatPada,
  });

  factory BarangKeluar.baru({
    required int poskoId,
    required Barang barang,
    required int jumlah,
    required String tujuan,
    String penerima = '',
    required DateTime tanggal,
    String keterangan = '',
    String dicatatOleh = '',
  }) =>
      BarangKeluar(
        kode: KodeUnik.buat(),
        poskoId: poskoId,
        barangId: barang.id!,
        jumlah: jumlah,
        tujuan: tujuan,
        penerima: penerima,
        tanggal: tanggal,
        keterangan: keterangan,
        dicatatOleh: dicatatOleh,
        dibuatPada: DateTime.now(),
      );

  @override
  bool get isMasuk => false;

  String get tujuanLabel => DataOptions.tujuanKeluar[tujuan] ?? tujuan;

  @override
  String get ringkasan =>
      penerima.isEmpty ? tujuanLabel : '$tujuanLabel · $penerima';

  Map<String, Object?> toMap() => {
        'id': id,
        'kode': kode,
        'posko_id': poskoId,
        'barang_id': barangId,
        'jumlah_keluar': jumlah,
        'tujuan': tujuan,
        'penerima': penerima.isEmpty ? null : penerima,
        'tanggal_keluar': Tanggal.format(tanggal),
        'keterangan': keterangan.isEmpty ? null : keterangan,
        'dicatat_oleh': dicatatOleh.isEmpty ? null : dicatatOleh,
        'dibuat_pada': dibuatPada.toIso8601String(),
      };

  factory BarangKeluar.fromMap(Map<String, Object?> map) => BarangKeluar(
        id: asInt(map['id']),
        kode: asText(map['kode']),
        poskoId: asInt(map['posko_id']),
        barangId: asInt(map['barang_id']) ?? 0,
        jumlah: asInt(map['jumlah_keluar']) ?? 0,
        tujuan: asText(map['tujuan']),
        penerima: asText(map['penerima']),
        tanggal: Tanggal.baca(asText(map['tanggal_keluar'])) ??
            asDate(map['dibuat_pada']),
        keterangan: asText(map['keterangan']),
        dicatatOleh: asText(map['dicatat_oleh']),
        dibuatPada: asDate(map['dibuat_pada']),
      );
}

/// Stok satu barang di satu posko = total masuk − total keluar.
class StokBarang {
  final Barang barang;
  final int jumlah;

  /// Waktu catatan terakhir barang ini (null = belum pernah ada catatan).
  final DateTime? terakhirDiperbarui;

  const StokBarang({
    required this.barang,
    required this.jumlah,
    this.terakhirDiperbarui,
  });
}
