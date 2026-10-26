// ============================================================
// pengungsi_repository.dart
// Semua operasi data PENGUNGSI (ambil, cari, tambah, ubah, hapus).
//
// Hapus = DITANDAI (dihapus_pada diisi), bukan dihapus permanen, supaya
// penghapusan ikut terkirim ke pusat lewat Paket Data Posko.
// Data yang sudah ditandai tidak tampil di aplikasi.
// ============================================================

import '../../models/pengungsi.dart';
import '../data_events.dart';
import '../database_tables.dart';
import '../local_database.dart';
import '../table_store.dart';
import 'posko_repository.dart';

class PengungsiRepository {
  PengungsiRepository._(this._store);
  static final PengungsiRepository instance =
      PengungsiRepository._(LocalDatabase.store);

  /// Untuk tes: repository dengan penyimpanan sendiri.
  factory PengungsiRepository.withStore(TableStore store) =>
      PengungsiRepository._(store);

  final TableStore _store;

  static const String _table = DatabaseTables.pengungsi;

  // ---------------- AMBIL DATA ----------------

  /// Semua pengungsi (tanpa yang sudah dihapus), lengkap dengan nama posko.
  /// [termasukDihapus] = true hanya untuk Paket Data Posko.
  Future<List<Pengungsi>> getAll({bool termasukDihapus = false}) async {
    final posko = {
      for (final p in await PoskoRepository.withStore(_store).getAll())
        p.id: p.nama,
    };
    return (await _store.getAll(_table))
        .map(Pengungsi.fromMap)
        .where((e) => termasukDihapus || !e.isDihapus)
        .map((e) => e.denganNamaPosko(posko[e.poskoId] ?? ''))
        .toList();
  }

  Future<List<Pengungsi>> getByPosko(int? poskoId) async =>
      (await getAll()).where((e) => e.poskoId == poskoId).toList();

  /// Jumlah pengungsi (tanpa yang sudah dihapus).
  /// [poskoId] diisi = hanya posko tersebut.
  Future<int> count({int? poskoId}) async {
    final semua = await getAll();
    if (poskoId == null) return semua.length;
    return semua.where((e) => e.poskoId == poskoId).length;
  }

  /// Pengungsi yang dianggap ORANG YANG SAMA (aturan website): nama tanpa
  /// beda huruf besar/kecil + tanggal lahir sama, di posko yang sama.
  Future<Pengungsi?> cariSama(Pengungsi data) async {
    final kunci = data.kunci;
    if (kunci == null) return null;
    for (final e in await getByPosko(data.poskoId)) {
      if (e.id != data.id && e.kunci == kunci) return e;
    }
    return null;
  }

  // ---------------- SIMPAN DATA ----------------

  Future<void> add(Pengungsi data) async {
    await _store.insert(_table, data.toMap());
    DataEvents.instance.notifyChanged();
  }

  Future<void> addMany(List<Pengungsi> list) async {
    await _store.insertMany(_table, list.map((e) => e.toMap()).toList());
    DataEvents.instance.notifyChanged();
  }

  Future<void> update(Pengungsi data) async {
    if (data.id == null) return;
    await _store.update(_table, data.id!, data.toMap());
    DataEvents.instance.notifyChanged();
  }

  /// Simpan banyak sekaligus (import): baris dengan id = perbarui,
  /// tanpa id = tambah.
  Future<void> simpanBanyak(List<Pengungsi> list) async {
    final baru = <Pengungsi>[];
    for (final e in list) {
      if (e.id == null) {
        baru.add(e);
      } else {
        await _store.update(_table, e.id!, e.toMap());
      }
    }
    if (baru.isNotEmpty) {
      await _store.insertMany(_table, baru.map((e) => e.toMap()).toList());
    }
    DataEvents.instance.notifyChanged();
  }

  /// Tandai dihapus (tidak dihapus permanen).
  Future<void> hapus(Pengungsi data) async {
    if (data.id == null) return;
    await _store.update(_table, data.id!, data.tandaiDihapus().toMap());
    DataEvents.instance.notifyChanged();
  }
}
