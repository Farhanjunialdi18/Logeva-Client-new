// ============================================================
// pengaturan_repository.dart
// Menyimpan PENGATURAN PERANGKAT (kunci -> nilai), misalnya
// kode_perangkat yang ikut di info.csv Paket Data Posko.
// ============================================================

import '../../utils/kode_unik.dart';
import '../../utils/pin_hasher.dart';
import '../../utils/waktu_wib.dart';
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

  // ---------------- STATUS KIRIM KE HP INDUK (HP Anggota) ----------------
  // Supaya relawan tahu ada catatan yang belum dikirim ke admin, dan apakah
  // admin sudah menggabungkan kirimannya.

  /// Jumlah perubahan yang DICATAT DI HP INI (tambah/ubah/hapus pengungsi,
  /// barang masuk/keluar) sejak terakhir dikirim. Data dari HP lain yang
  /// digabung tidak dihitung (gabung menulis langsung, bukan lewat repository).
  static const String kunciBelumTerkirim = 'perubahan_belum_terkirim';

  /// Waktu (WIB, format paket) File Sinkron terakhir dikirim dari HP ini.
  static const String kunciTerakhirKirim = 'terakhir_kirim_induk';

  /// Waktu kiriman HP ini yang terakhir SUDAH DIGABUNG di HP Induk (dari
  /// tanda terima di file balasan HP Induk).
  static const String kunciDiterimaInduk = 'diterima_induk';

  Future<void> tambahPerubahanLokal([int jumlah = 1]) async {
    final lama = int.tryParse(await get(kunciBelumTerkirim) ?? '') ?? 0;
    await set(kunciBelumTerkirim, '${lama + jumlah}');
  }

  Future<int> perubahanBelumTerkirim() async =>
      int.tryParse(await get(kunciBelumTerkirim) ?? '') ?? 0;

  /// Dipanggil setelah File Sinkron [waktu] dikirim ke HP Induk.
  Future<void> tandaiTerkirim(String waktu) async {
    await set(kunciBelumTerkirim, '0');
    await set(kunciTerakhirKirim, waktu);
  }

  // ---------------- STATUS HP RELAWAN (HP Induk) ----------------
  // Pengingat untuk admin: HP relawan mana yang belum mengirim data, dan
  // mana yang perlu DIBAGIKAN ULANG (akun berubah / ada data gabungan baru).

  /// Waktu (WIB) akun relawan/admin terakhir diubah di HP ini (tambah, edit,
  /// PIN baru, nonaktif, hapus). Perubahan ini baru berlaku di HP relawan
  /// setelah dibagikan ulang.
  static const String kunciAkunBerubah = 'akun_berubah_pada';

  /// Waktu (WIB) HP Induk terakhir menggabungkan data dari HP lain.
  static const String kunciTerakhirGabung = 'terakhir_gabung_pada';

  /// + kode perangkat HP Anggota: laporan dari file kiriman HP itu (JSON).
  static const String awalanHpAnggota = 'hp_anggota_';

  /// + kode relawan: waktu (WIB) file terakhir DIBAGIKAN admin ke relawan itu.
  static const String awalanDibagikan = 'dibagikan_ke_';

  Future<void> tandaiAkunBerubah() =>
      set(kunciAkunBerubah, WaktuWib.tanggalWaktu(DateTime.now()));

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
