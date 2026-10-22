// ============================================================
// sqlite_table_store.dart
// Penyimpanan SQLite (sqflite) untuk Android.
// ============================================================

import 'package:sqflite/sqflite.dart';

import 'database_tables.dart';
import 'table_store.dart';

class SqliteTableStore implements TableStore {
  Future<Database>? _dbFuture;

  /// Database dibuka sekali saja, lalu dipakai ulang.
  Future<Database> get _db => _dbFuture ??= _open();

  Future<Database> _open() async {
    final folder = await getDatabasesPath();
    return openDatabase(
      '$folder/${DatabaseTables.databaseName}',
      version: DatabaseTables.version,
      onCreate: (db, version) async {
        for (final sql in DatabaseTables.createStatements) {
          await db.execute(sql);
        }
      },
      // HP yang sudah punya database versi lama: jalankan langkah
      // per versi secara berurutan (misal 1 -> 2 -> 3).
      onUpgrade: (db, oldVersion, newVersion) async {
        for (var v = oldVersion + 1; v <= newVersion; v++) {
          for (final sql in DatabaseTables.upgradeSteps[v] ?? const <String>[]) {
            await db.execute(sql);
          }
        }
      },
    );
  }

  /// Buang kolom 'id' supaya SQLite membuat id otomatis.
  Map<String, Object?> _withoutId(Map<String, Object?> values) {
    return Map<String, Object?>.of(values)..remove('id');
  }

  @override
  Future<List<Map<String, Object?>>> getAll(String table) async {
    final db = await _db;
    return db.query(table, orderBy: 'id DESC');
  }

  @override
  Future<int> count(String table) async {
    final db = await _db;
    final result = await db.rawQuery('SELECT COUNT(*) FROM $table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values) async {
    final db = await _db;
    return db.insert(table, _withoutId(values));
  }

  @override
  Future<void> insertMany(String table, List<Map<String, Object?>> rows) async {
    final db = await _db;
    final batch = db.batch();
    for (final row in rows) {
      batch.insert(table, _withoutId(row));
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> update(String table, int id, Map<String, Object?> values) async {
    final db = await _db;
    await db.update(table, _withoutId(values), where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> delete(String table, int id) async {
    final db = await _db;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }
}
