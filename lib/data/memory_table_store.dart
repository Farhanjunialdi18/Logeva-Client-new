// ============================================================
// memory_table_store.dart
// Penyimpanan SEMENTARA di memori, khusus saat dijalankan di Chrome.
// Data hilang setiap aplikasi di-refresh. Di Android tidak dipakai.
// ============================================================

import 'table_store.dart';

class MemoryTableStore implements TableStore {
  final Map<String, List<Map<String, Object?>>> _tables = {};
  final Map<String, int> _nextId = {};

  MemoryTableStore({Map<String, List<Map<String, Object?>>> seed = const {}}) {
    seed.forEach((table, rows) {
      for (final row in rows) {
        _insertSync(table, row);
      }
    });
  }

  List<Map<String, Object?>> _rows(String table) =>
      _tables.putIfAbsent(table, () => []);

  int _insertSync(String table, Map<String, Object?> values) {
    final id = (_nextId[table] ?? 0) + 1;
    _nextId[table] = id;
    _rows(table).add(Map<String, Object?>.of(values)..['id'] = id);
    return id;
  }

  @override
  Future<List<Map<String, Object?>>> getAll(String table) async {
    return _rows(table).reversed.map((r) => Map<String, Object?>.of(r)).toList();
  }

  @override
  Future<int> count(String table) async => _rows(table).length;

  @override
  Future<int> insert(String table, Map<String, Object?> values) async {
    return _insertSync(table, values);
  }

  @override
  Future<void> insertMany(String table, List<Map<String, Object?>> rows) async {
    for (final row in rows) {
      _insertSync(table, row);
    }
  }

  @override
  Future<void> update(String table, int id, Map<String, Object?> values) async {
    final rows = _rows(table);
    final index = rows.indexWhere((r) => r['id'] == id);
    if (index >= 0) {
      rows[index] = Map<String, Object?>.of(values)..['id'] = id;
    }
  }

  @override
  Future<void> delete(String table, int id) async {
    _rows(table).removeWhere((r) => r['id'] == id);
  }

  @override
  Future<void> gantiSemua(Map<String, List<Map<String, Object?>>> isi) async {
    isi.forEach((table, rows) {
      _tables[table] = [for (final r in rows) Map<String, Object?>.of(r)];
      _nextId[table] = rows.fold<int>(0, (m, r) {
        final id = (r['id'] as num?)?.toInt() ?? 0;
        return id > m ? id : m;
      });
    });
  }
}
