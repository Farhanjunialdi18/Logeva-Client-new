// ============================================================
// riwayat_repository.dart
// Menyimpan & membaca RIWAYAT TRANSAKSI (import/export CSV).
// ============================================================

import '../../models/riwayat_transaksi.dart';
import '../data_events.dart';
import '../database_tables.dart';
import '../local_database.dart';

class RiwayatRepository {
  RiwayatRepository._();
  static final RiwayatRepository instance = RiwayatRepository._();

  static const String _table = DatabaseTables.riwayat;

  Future<List<RiwayatTransaksi>> getAll() async {
    final rows = await LocalDatabase.store.getAll(_table);
    return rows.map(RiwayatTransaksi.fromMap).toList();
  }

  Future<void> log({
    required String jenis,
    required String jenisData,
    required bool berhasil,
    int jumlahBaris = 0,
    String keterangan = '',
  }) async {
    final item = RiwayatTransaksi(
      jenis: jenis,
      jenisData: jenisData,
      berhasil: berhasil,
      jumlahBaris: jumlahBaris,
      keterangan: keterangan,
      waktu: DateTime.now(),
    );
    await LocalDatabase.store.insert(_table, item.toMap());
    DataEvents.instance.notifyChanged();
  }
}
