// ============================================================
// barang_repository.dart
// MASTER BARANG & KATEGORI (ambil, cari, tambah, ubah, hapus).
// Hanya admin yang mengelola master barang (sama dengan website);
// relawan memilih barang dari daftar ini saat mencatat masuk/keluar.
// ============================================================

import '../../models/barang.dart';
import '../data_events.dart';
import '../database_tables.dart';
import '../local_database.dart';
import '../table_store.dart';

/// Aksi master barang ditolak; [message] siap ditampilkan.
class BarangException implements Exception {
  final String message;
  const BarangException(this.message);

  @override
  String toString() => message;
}

class BarangRepository {
  BarangRepository._(this._store);
  static final BarangRepository instance =
      BarangRepository._(LocalDatabase.store);

  /// Untuk tes: repository dengan penyimpanan sendiri.
  factory BarangRepository.withStore(TableStore store) =>
      BarangRepository._(store);

  final TableStore _store;

  static const String _table = DatabaseTables.barang;

  // ---------------- KATEGORI ----------------

  Future<List<KategoriLogistik>> getKategori() async {
    final list = (await _store.getAll(DatabaseTables.kategoriLogistik))
        .map(KategoriLogistik.fromMap)
        .toList();
    return list..sort((a, b) => a.id.compareTo(b.id));
  }

  /// Cari kategori dari nama (tanpa beda huruf besar/kecil).
  Future<KategoriLogistik?> findKategori(String nama) async {
    final cari = nama.trim().toLowerCase();
    for (final k in await getKategori()) {
      if (k.nama.toLowerCase() == cari) return k;
    }
    return null;
  }

  // ---------------- BARANG ----------------

  /// Semua barang urut kategori lalu nama, lengkap dengan nama kategori.
  Future<List<Barang>> getAll() async {
    final kategori = {for (final k in await getKategori()) k.id: k.nama};
    final list = (await _store.getAll(_table))
        .map((r) {
          final b = Barang.fromMap(r);
          return b.denganKategori(kategori[b.kategoriId] ?? '');
        })
        .toList();
    list.sort((a, b) {
      final k = a.kategoriId.compareTo(b.kategoriId);
      return k != 0
          ? k
          : a.namaItem.toLowerCase().compareTo(b.namaItem.toLowerCase());
    });
    return list;
  }

  Future<int> count() => _store.count(_table);

  Future<Barang?> findById(int id) async {
    for (final b in await getAll()) {
      if (b.id == id) return b;
    }
    return null;
  }

  Future<Barang?> findSama(int kategoriId, String nama, {int? exceptId}) async {
    final kunci = Barang.kunciSama(kategoriId, nama);
    for (final b in await getAll()) {
      if (b.id != exceptId && b.kunci == kunci) return b;
    }
    return null;
  }

  Future<Barang> add(Barang barang) async {
    if (await findSama(barang.kategoriId, barang.namaItem) != null) {
      throw BarangException(
          'Barang "${barang.namaItem}" sudah ada di kategori ini.');
    }
    final id = await _store.insert(_table, barang.toMap());
    DataEvents.instance.notifyChanged();
    return Barang.fromMap(barang.toMap()..['id'] = id);
  }

  Future<void> update(Barang barang) async {
    if (barang.id == null) return;
    if (await findSama(barang.kategoriId, barang.namaItem,
            exceptId: barang.id) !=
        null) {
      throw BarangException(
          'Barang "${barang.namaItem}" sudah ada di kategori ini.');
    }
    await _store.update(_table, barang.id!, barang.toMap());
    DataEvents.instance.notifyChanged();
  }

  /// Alasan barang TIDAK boleh dihapus, atau null kalau boleh.
  /// Barang yang sudah punya catatan masuk/keluar tidak boleh dihapus,
  /// karena catatannya harus tetap terkirim ke pusat.
  Future<String?> cekHapus(Barang barang) async {
    bool dipakai(Map<String, Object?> r) => r['barang_id'] == barang.id;
    final masuk =
        (await _store.getAll(DatabaseTables.barangMasuk)).where(dipakai).length;
    final keluar =
        (await _store.getAll(DatabaseTables.barangKeluar)).where(dipakai).length;
    if (masuk + keluar > 0) {
      return 'Barang ini sudah punya ${masuk + keluar} catatan masuk/keluar.';
    }
    return null;
  }

  Future<void> delete(int id) async {
    await _store.delete(_table, id);
    DataEvents.instance.notifyChanged();
  }

  /// Simpan banyak sekaligus (import master): id ada = perbarui.
  Future<void> simpanBanyak(List<Barang> list) async {
    final baru = <Barang>[];
    for (final b in list) {
      if (b.id == null) {
        baru.add(b);
      } else {
        await _store.update(_table, b.id!, b.toMap());
      }
    }
    if (baru.isNotEmpty) {
      await _store.insertMany(_table, baru.map((b) => b.toMap()).toList());
    }
    DataEvents.instance.notifyChanged();
  }
}
