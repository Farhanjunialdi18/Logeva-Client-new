// ============================================================
// posko_repository.dart
// Semua operasi data POSKO (ambil, cari, tambah, ubah, hapus).
// ============================================================

import '../../models/posko.dart';
import '../data_events.dart';
import '../database_tables.dart';
import '../local_database.dart';

class PoskoRepository {
  PoskoRepository._();
  static final PoskoRepository instance = PoskoRepository._();

  static const String _table = DatabaseTables.posko;

  Future<List<Posko>> getAll() async {
    final rows = await LocalDatabase.store.getAll(_table);
    return rows.map(Posko.fromMap).toList();
  }

  Future<int> count() => LocalDatabase.store.count(_table);

  Future<Posko?> findByNama(String nama) async {
    final cari = nama.trim().toLowerCase();
    for (final posko in await getAll()) {
      if (posko.nama.toLowerCase() == cari) return posko;
    }
    return null;
  }

  /// Daftar nama posko urut abjad (untuk dropdown).
  Future<List<String>> getNames() async {
    final names = (await getAll()).map((p) => p.nama).toList();
    names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  /// Tambah posko hanya dengan nama. Hasil false = nama sudah ada.
  Future<bool> addByName(String nama) async {
    final bersih = nama.trim();
    if (bersih.isEmpty || await findByNama(bersih) != null) return false;
    await add(Posko(nama: bersih, dibuatPada: DateTime.now()));
    return true;
  }

  Future<void> add(Posko posko) async {
    await LocalDatabase.store.insert(_table, posko.toMap());
    DataEvents.instance.notifyChanged();
  }

  Future<void> update(Posko posko) async {
    if (posko.id == null) return;
    await LocalDatabase.store.update(_table, posko.id!, posko.toMap());
    DataEvents.instance.notifyChanged();
  }

  Future<void> delete(int id) async {
    await LocalDatabase.store.delete(_table, id);
    DataEvents.instance.notifyChanged();
  }
}
