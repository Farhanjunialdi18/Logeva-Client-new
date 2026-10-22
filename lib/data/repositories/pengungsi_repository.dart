// ============================================================
// pengungsi_repository.dart
// Semua operasi data PENGUNGSI (ambil, tambah, ubah, hapus).
// ============================================================

import '../../models/pengungsi.dart';
import '../data_events.dart';
import '../database_tables.dart';
import '../local_database.dart';

class PengungsiRepository {
  PengungsiRepository._();
  static final PengungsiRepository instance = PengungsiRepository._();

  static const String _table = DatabaseTables.pengungsi;

  Future<List<Pengungsi>> getAll() async {
    final rows = await LocalDatabase.store.getAll(_table);
    return rows.map(Pengungsi.fromMap).toList();
  }

  Future<int> count() => LocalDatabase.store.count(_table);

  Future<void> add(Pengungsi data) async {
    await LocalDatabase.store.insert(_table, data.toMap());
    DataEvents.instance.notifyChanged();
  }

  Future<void> addMany(List<Pengungsi> list) async {
    await LocalDatabase.store.insertMany(
      _table,
      list.map((e) => e.toMap()).toList(),
    );
    DataEvents.instance.notifyChanged();
  }

  Future<void> update(Pengungsi data) async {
    if (data.id == null) return;
    await LocalDatabase.store.update(_table, data.id!, data.toMap());
    DataEvents.instance.notifyChanged();
  }

  Future<void> delete(int id) async {
    await LocalDatabase.store.delete(_table, id);
    DataEvents.instance.notifyChanged();
  }
}
