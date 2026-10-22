// ============================================================
// logistik_repository.dart
// Semua operasi data LOGISTIK (ambil, tambah, ubah, hapus).
// ============================================================

import '../../models/logistik.dart';
import '../data_events.dart';
import '../database_tables.dart';
import '../local_database.dart';

class LogistikRepository {
  LogistikRepository._();
  static final LogistikRepository instance = LogistikRepository._();

  static const String _table = DatabaseTables.logistik;

  Future<List<Logistik>> getAll() async {
    final rows = await LocalDatabase.store.getAll(_table);
    return rows.map(Logistik.fromMap).toList();
  }

  Future<int> count() => LocalDatabase.store.count(_table);

  Future<void> add(Logistik data) async {
    await LocalDatabase.store.insert(_table, data.toMap());
    DataEvents.instance.notifyChanged();
  }

  Future<void> addMany(List<Logistik> list) async {
    await LocalDatabase.store.insertMany(
      _table,
      list.map((e) => e.toMap()).toList(),
    );
    DataEvents.instance.notifyChanged();
  }

  Future<void> update(Logistik data) async {
    if (data.id == null) return;
    await LocalDatabase.store.update(_table, data.id!, data.toMap());
    DataEvents.instance.notifyChanged();
  }

  Future<void> delete(int id) async {
    await LocalDatabase.store.delete(_table, id);
    DataEvents.instance.notifyChanged();
  }
}
