// ============================================================
// local_database.dart
// Memilih penyimpanan otomatis:
//  - Android  -> SQLite (permanen)
//  - Chrome   -> memori + data contoh (hilang saat refresh)
// ============================================================

import 'package:flutter/foundation.dart' show kIsWeb;

import 'demo_data.dart';
import 'memory_table_store.dart';
import 'sqlite_table_store.dart';
import 'table_store.dart';

class LocalDatabase {
  LocalDatabase._();

  static final TableStore store = kIsWeb
      ? MemoryTableStore(seed: DemoData.seed())
      : SqliteTableStore();
}
