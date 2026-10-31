// ============================================================
// pengaturan_repository.dart
// Menyimpan PENGATURAN PERANGKAT (kunci -> nilai), misalnya
// kode_perangkat yang ikut di info.csv Paket Data Posko.
// ============================================================

import '../../utils/kode_unik.dart';
import '../../utils/pin_hasher.dart';
import '../database_tables.dart';
import '../local_database.dart';
import '../table_store.dart';

class PengaturanRepository {
  PengaturanRepository._(this._store);
  static final PengaturanRepository instance =
      PengaturanRepository._(LocalDatabase.store);

  /// Untuk tes: repository dengan penyimpanan sendiri.
  factory PengaturanRepository.withStore(TableStore store) =>
      PengaturanRepository._(store);

  final TableStore _store;

  static const String _table = DatabaseTables.pengaturan;
  static const String kunciKodePerangkat = 'kode_perangkat';

  Future<Map<String, Object?>?> _cari(String kunci) async {
    for (final row in await _store.getAll(_table)) {
      if (row['kunci'] == kunci) return row;
    }
    return null;
  }

  /// Nilai pengaturan, atau null kalau belum pernah disimpan.
  Future<String?> get(String kunci) async =>
      (await _cari(kunci))?['nilai'] as String?;

  Future<void> set(String kunci, String nilai) async {
    final row = await _cari(kunci);
    final data = {'kunci': kunci, 'nilai': nilai};
    if (row == null) {
      await _store.insert(_table, data);
    } else {
      await _store.update(_table, row['id'] as int, data);
    }
  }

  Future<String>? _kodePerangkat;

  /// Setelah data dipulihkan dari cadangan: baca ulang kode perangkat.
  void lupakanCache() => _kodePerangkat = null;

  /// UUID tetap untuk instalasi aplikasi ini. Dibuat sekali saat pertama
  /// kali dibutuhkan, lalu selalu sama (sampai aplikasi dihapus dari HP).
  Future<String> kodePerangkat() async {
    final proses = _kodePerangkat ??= _ambilAtauBuatKode();
    try {
      return await proses;
    } catch (_) {
      _kodePerangkat = null; // gagal: coba lagi di panggilan berikutnya
      rethrow;
    }
  }

  Future<String> _ambilAtauBuatKode() async {
    final ada = await get(kunciKodePerangkat);
    if (ada != null && KodeUnik.valid(ada)) return ada;
    final baru = KodeUnik.buat();
    await set(kunciKodePerangkat, baru);
    return baru;
  }

  // ---------------- SALT PIN ----------------

  static const String kunciSaltPin = 'salt_pin';

  /// Salt untuk mengacak PIN relawan (pin_hasher.dart). Dibuat sekali di
  /// HP Induk; HP Anggota memakai salt dari HP Induk (File Penyiapan).
  Future<String> saltPin() async {
    final ada = await get(kunciSaltPin);
    if (ada != null && ada.isNotEmpty) return ada;
    final baru = PinHasher.saltBaru();
    await set(kunciSaltPin, baru);
    return baru;
  }

  // ---------------- PERAN HP ----------------

  static const String kunciPeranPerangkat = 'peran_perangkat';

  /// HP Induk = dipegang admin/supervisor posko: membuat posko, master
  /// barang, dan akun; menggabungkan data dari HP Anggota.
  /// Semua HP yang sudah dipakai sebelum fitur ini = HP Induk.
  static const String peranInduk = 'induk';

  /// HP Anggota = dipakai relawan; disiapkan dari File Penyiapan HP Induk.
  static const String peranAnggota = 'anggota';

  Future<String> peranPerangkat() async =>
      await get(kunciPeranPerangkat) == peranAnggota ? peranAnggota : peranInduk;

  Future<bool> isAnggota() async => await peranPerangkat() == peranAnggota;

  Future<void> setPeranPerangkat(String peran) async {
    assert(peran == peranInduk || peran == peranAnggota);
    await set(kunciPeranPerangkat, peran);
  }

  // ---------------- KATA SANDI POSKO ----------------
  // Mengunci Paket Data Posko & Cadangan (berkas_terkunci.dart). Dibuat
  // supervisor di HP Induk, ikut ke HP Anggota lewat penyiapan/sinkron.
  // Disimpan di HP ini karena HP sendiri sudah berisi datanya.

  static const String kunciKataSandiBerkas = 'kata_sandi_berkas';

  /// Kosong = belum diatur (paket & cadangan belum bisa dibuat).
  Future<String> kataSandiBerkas() async => await get(kunciKataSandiBerkas) ?? '';

  Future<void> setKataSandiBerkas(String kataSandi) =>
      set(kunciKataSandiBerkas, kataSandi);
}
