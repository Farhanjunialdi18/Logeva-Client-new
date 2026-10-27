// ============================================================
// table_store.dart
// "Kontrak" penyimpanan data. Ada 2 versi:
//  - SqliteTableStore  -> dipakai di Android (data permanen)
//  - MemoryTableStore  -> dipakai di Chrome/web (hanya untuk coba tampilan)
// ============================================================

abstract class TableStore {
  /// Semua baris, urut dari yang terbaru.
  Future<List<Map<String, Object?>>> getAll(String table);

  Future<int> count(String table);

  /// Simpan satu baris, mengembalikan id baru.
  Future<int> insert(String table, Map<String, Object?> values);

  Future<void> insertMany(String table, List<Map<String, Object?>> rows);

  Future<void> update(String table, int id, Map<String, Object?> values);

  Future<void> delete(String table, int id);

  /// Mengganti SELURUH isi tabel-tabel di [isi] (id ikut dipertahankan)
  /// dalam satu transaksi: gagal di tengah = tidak ada yang berubah.
  /// Dipakai untuk memulihkan cadangan.
  Future<void> gantiSemua(Map<String, List<Map<String, Object?>>> isi);
}
