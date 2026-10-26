// ============================================================
// relawan_repository.dart
// Semua operasi data AKUN RELAWAN, termasuk membuat PIN otomatis
// dan login PIN lewat hash (berlaku di HP Induk maupun HP Anggota).
// ============================================================

import 'dart:math';

import '../../core/app_constants.dart';
import '../../models/relawan.dart';
import '../../utils/kode_unik.dart';
import '../../utils/pin_hasher.dart';
import '../data_events.dart';
import '../database_tables.dart';
import '../local_database.dart';
import '../table_store.dart';
import 'pengaturan_repository.dart';
import 'posko_repository.dart';

class RelawanRepository {
  RelawanRepository._(this._store);
  static final RelawanRepository instance =
      RelawanRepository._(LocalDatabase.store);

  /// Untuk tes: repository dengan penyimpanan sendiri.
  factory RelawanRepository.withStore(TableStore store) =>
      RelawanRepository._(store);

  final TableStore _store;

  static const String _table = DatabaseTables.relawan;

  // ---------------- AMBIL DATA ----------------

  /// Semua relawan. Nama posko diambil dari tabel posko (lewat posko_id),
  /// jadi tetap benar walaupun nama posko diubah.
  Future<List<Relawan>> getAll() async {
    final rows = await _store.getAll(_table);
    final posko = {
      for (final p in await PoskoRepository.withStore(_store).getAll()) p.id: p,
    };
    return rows.map((row) {
      final r = Relawan.fromMap(row);
      final tempat = posko[r.poskoId];
      return tempat == null ? r : r.tempatkan(tempat);
    }).toList();
  }

  /// Relawan yang ditempatkan di posko [poskoId].
  Future<List<Relawan>> getByPosko(int poskoId) async =>
      (await getAll()).where((r) => r.poskoId == poskoId).toList();

  Future<int> count() => _store.count(_table);

  Future<Relawan?> findById(int id) async {
    for (final relawan in await getAll()) {
      if (relawan.id == id) return relawan;
    }
    return null;
  }

  /// Cari relawan dari PIN yang diketik saat login. Dicocokkan lewat
  /// PIN yang diacak (pin_hash), jadi bekerja juga di HP Anggota yang
  /// tidak menyimpan PIN asli.
  Future<Relawan?> findByPin(String pin) async {
    await lengkapiPinHash();
    final hash = PinHasher.hash(pin, await _salt());
    for (final relawan in await getAll()) {
      if (relawan.pinHash == hash) return relawan;
    }
    return null;
  }

  Future<String> _salt() => PengaturanRepository.withStore(_store).saltPin();

  /// Isi pin_hash untuk akun yang punya PIN asli tapi belum punya hash
  /// (data dari versi aplikasi sebelumnya). Cepat kalau sudah lengkap.
  Future<void> lengkapiPinHash() async {
    final kurang = (await getAll())
        .where((r) => r.pin.isNotEmpty && r.pinHash.isEmpty)
        .toList();
    if (kurang.isEmpty) return;
    final salt = await _salt();
    for (final r in kurang) {
      await _simpan(r.copyWith(pinHash: PinHasher.hash(r.pin, salt)));
    }
  }

  // ---------------- PIN ----------------

  /// Buat PIN acak yang belum dipakai relawan lain.
  /// [except] = PIN yang juga harus dihindari (misal PIN lama).
  Future<String> generateUniquePin({String? except}) async {
    final semua = await getAll();
    final dipakai = semua.map((r) => r.pin).where((p) => p.isNotEmpty).toSet();
    final hashDipakai = semua.map((r) => r.pinHash).where((h) => h.isNotEmpty).toSet();
    if (except != null) dipakai.add(except);
    final salt = await _salt();
    final random = Random.secure();
    String pin;
    do {
      pin = List.generate(AppConstants.pinLength, (_) => random.nextInt(10)).join();
    } while (dipakai.contains(pin) ||
        // Akun dari HP lain hanya punya hash: pastikan PIN baru juga beda.
        (hashDipakai.length > dipakai.length &&
            hashDipakai.contains(PinHasher.hash(pin, salt))));
    return pin;
  }

  /// Ganti PIN relawan dengan PIN acak baru. Hasil: data relawan terbaru.
  Future<Relawan> regeneratePin(Relawan relawan) async {
    final baru = relawan.copyWith(pin: await generateUniquePin(except: relawan.pin));
    await update(baru);
    return (await findById(relawan.id!))!;
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
    final now = DateTime.now();
    data = data.copyWith(
      kode: data.kode.isEmpty ? KodeUnik.buat() : data.kode,
      pinHash: PinHasher.hash(data.pin, await _salt()),
      diubahPada: now,
    );
    final id = await _store.insert(_table, data.toMap());
    DataEvents.instance.notifyChanged();
    return data.copyWith(id: id);
  }

  /// Simpan perubahan akun oleh admin. diubah_pada ikut diperbarui
  /// (dipakai saat akun dikirim ke HP Anggota) dan hash PIN dihitung ulang.
  Future<void> update(Relawan relawan) async {
    if (relawan.id == null) return;
    var data = relawan.copyWith(diubahPada: DateTime.now());
    if (data.pin.isNotEmpty) {
      data = data.copyWith(pinHash: PinHasher.hash(data.pin, await _salt()));
    }
    await _simpan(data);
  }

  /// Simpan apa adanya (tanpa mengubah diubah_pada).
  Future<void> _simpan(Relawan relawan) async {
    await _store.update(_table, relawan.id!, relawan.toMap());
    DataEvents.instance.notifyChanged();
  }

  /// Catat waktu relawan berhasil login ("Terakhir digunakan").
  /// Kejadian lokal di HP ini: TIDAK mengubah diubah_pada akun.
  Future<void> markLogin(Relawan relawan) async {
    await _simpan(relawan.copyWith(terakhirLogin: DateTime.now()));
  }

  Future<void> delete(int id) async {
    await _store.delete(_table, id);
    DataEvents.instance.notifyChanged();
  }
}
