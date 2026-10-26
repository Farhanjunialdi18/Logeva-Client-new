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

  /// Hanya diganti oleh tes tampilan (sebelum repository pertama dipakai).
  static TableStore store = kIsWeb
      ? MemoryTableStore(seed: DemoData.seed())
      : SqliteTableStore();
}
