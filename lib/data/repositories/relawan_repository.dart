// ============================================================
// relawan_repository.dart
// Semua operasi data AKUN RELAWAN, termasuk membuat PIN otomatis.
// ============================================================

import 'dart:math';

import '../../core/app_constants.dart';
import '../../models/relawan.dart';
import '../data_events.dart';
import '../database_tables.dart';
import '../local_database.dart';

class RelawanRepository {
  RelawanRepository._();
  static final RelawanRepository instance = RelawanRepository._();

  static const String _table = DatabaseTables.relawan;

  // ---------------- AMBIL DATA ----------------

  Future<List<Relawan>> getAll() async {
    final rows = await LocalDatabase.store.getAll(_table);
    return rows.map(Relawan.fromMap).toList();
  }

  Future<int> count() => LocalDatabase.store.count(_table);

  Future<Relawan?> findById(int id) async {
    for (final relawan in await getAll()) {
      if (relawan.id == id) return relawan;
    }
    return null;
  }

  Future<Relawan?> findByPin(String pin) async {
    for (final relawan in await getAll()) {
      if (relawan.pin == pin) return relawan;
    }
    return null;
  }

  // ---------------- PIN ----------------

  /// Buat PIN acak yang belum dipakai relawan lain.
  /// [except] = PIN yang juga harus dihindari (misal PIN lama).
  Future<String> generateUniquePin({String? except}) async {
    final dipakai = (await getAll()).map((r) => r.pin).toSet();
    if (except != null) dipakai.add(except);
    final random = Random.secure();
    String pin;
    do {
      pin = List.generate(AppConstants.pinLength, (_) => random.nextInt(10)).join();
    } while (dipakai.contains(pin));
    return pin;
  }

  /// Ganti PIN relawan dengan PIN acak baru. Hasil: data relawan terbaru.
  Future<Relawan> regeneratePin(Relawan relawan) async {
    final baru = relawan.copyWith(pin: await generateUniquePin(except: relawan.pin));
    await update(baru);
    return baru;
  }

  // ---------------- SIMPAN DATA ----------------

  /// Tambah relawan baru. Kalau PIN dari form ternyata sudah terpakai
  /// (jarang sekali), PIN diganti otomatis. Hasil: relawan yang tersimpan.
  Future<Relawan> add(Relawan relawan) async {
    var data = relawan;
    if (data.pin.length != AppConstants.pinLength ||
        await findByPin(data.pin) != null) {
      data = data.copyWith(pin: await generateUniquePin());
    }
    final id = await LocalDatabase.store.insert(_table, data.toMap());
    DataEvents.instance.notifyChanged();
    return data.copyWith(id: id);
  }

  Future<void> update(Relawan relawan) async {
    if (relawan.id == null) return;
    await LocalDatabase.store.update(_table, relawan.id!, relawan.toMap());
    DataEvents.instance.notifyChanged();
  }

  /// Catat waktu relawan berhasil login ("Terakhir digunakan").
  Future<void> markLogin(Relawan relawan) async {
    await update(relawan.copyWith(terakhirLogin: DateTime.now()));
  }

  Future<void> delete(int id) async {
    await LocalDatabase.store.delete(_table, id);
    DataEvents.instance.notifyChanged();
  }
}
