// ============================================================
// posko_repository.dart
// Semua operasi data POSKO (ambil, cari, tambah, ubah, status, hapus).
// ============================================================

import '../../models/posko.dart';
import '../../services/session_service.dart';
import '../data_events.dart';
import '../database_tables.dart';
import '../local_database.dart';
import '../table_store.dart';

class PoskoRepository {
  PoskoRepository._(this._store);
  static final PoskoRepository instance = PoskoRepository._(LocalDatabase.store);

  /// Untuk tes: repository dengan penyimpanan sendiri.
  factory PoskoRepository.withStore(TableStore store) =>
      PoskoRepository._(store);

  final TableStore _store;

  static const String _table = DatabaseTables.posko;

  // ---------------- AMBIL DATA ----------------

  Future<List<Posko>> getAll() async {
    final rows = await _store.getAll(_table);
    return rows.map(Posko.fromMap).toList();
  }

  Future<int> count() => _store.count(_table);

  Future<Posko?> findById(int id) async {
    for (final posko in await getAll()) {
      if (posko.id == id) return posko;
    }
    return null;
  }

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

  /// Apakah nama sudah dipakai posko lain? ([exceptId] = posko yang diedit)
  Future<bool> isNamaTaken(String nama, {int? exceptId}) async {
    final cari = nama.trim().toLowerCase();
    return (await getAll())
        .any((p) => p.id != exceptId && p.nama.toLowerCase() == cari);
  }

  // ---------------- SIMPAN DATA ----------------

  /// Tambah posko. Hasil: posko yang tersimpan (dengan id).
  Future<Posko> add(Posko posko) async {
    if (await isNamaTaken(posko.nama)) {
      throw PoskoException('Posko "${posko.nama}" sudah ada.');
    }
    final id = await _store.insert(_table, posko.toMap());
    DataEvents.instance.notifyChanged();
    return Posko.fromMap(posko.toMap()..['id'] = id);
  }

  /// Simpan perubahan. Data lain merujuk posko lewat id, jadi nama posko
  /// boleh diganti tanpa memutus hubungan.
  Future<void> update(Posko posko) async {
    final id = posko.id;
    if (id == null) return;
    if (await isNamaTaken(posko.nama, exceptId: id)) {
      throw PoskoException('Posko "${posko.nama}" sudah ada.');
    }

    await _store.update(_table, id, posko.toMap());
    DataEvents.instance.notifyChanged();
  }

  /// Ubah status operasional (mulai / tutup / kembali siaga).
  /// Melempar [PoskoException] kalau aksi tidak bisa dilakukan.
  Future<Posko> ubahStatus(Posko posko, AksiOperasional aksi) async {
    final baru = posko.ubahStatus(aksi);
    await update(baru);
    return baru;
  }

  // ---------------- HAPUS ----------------

  /// Alasan posko TIDAK boleh dihapus, atau null kalau boleh.
  ///  - Hanya ADMIN yang boleh menghapus posko (relawan hanya mengelola
  ///    data di posko tugasnya).
  ///  - Posko yang masih dipakai relawan, pengungsi, atau logistik tidak
  ///    boleh dihapus supaya datanya tidak kehilangan posko.
  Future<String?> cekHapus(Posko posko) async {
    if (SessionService.instance.admin == null) {
      return 'Hanya admin yang dapat menghapus posko.';
    }

    final relawan = (await _store.getAll(DatabaseTables.relawan))
        .where((r) => r['posko_id'] == posko.id)
        .length;
    if (relawan > 0) return 'Masih ada $relawan relawan di posko ini.';

    // Pengungsi yang sudah ditandai dihapus juga dihitung: penghapusannya
    // masih harus terkirim ke pusat bersama posko ini.
    final pengungsi = (await _store.getAll(DatabaseTables.pengungsi))
        .where((r) => r['posko_id'] == posko.id);
    final aktif = pengungsi.where((r) => r['dihapus_pada'] == null).length;
    if (aktif > 0) return 'Masih ada $aktif pengungsi di posko ini.';
    if (pengungsi.isNotEmpty) {
      return 'Posko ini punya riwayat data pengungsi yang harus tetap '
          'dikirim ke pusat.';
    }

    bool dipakai(Map<String, Object?> row) => row['posko_id'] == posko.id;
    final logistik =
        (await _store.getAll(DatabaseTables.barangMasuk)).where(dipakai).length +
            (await _store.getAll(DatabaseTables.barangKeluar))
                .where(dipakai)
                .length;
    if (logistik > 0) {
      return 'Posko ini punya $logistik catatan barang masuk/keluar yang '
          'harus tetap dikirim ke pusat.';
    }
    return null;
  }

  Future<void> delete(int id) async {
    await _store.delete(_table, id);
    DataEvents.instance.notifyChanged();
  }
}
