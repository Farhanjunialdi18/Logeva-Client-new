// ============================================================
// database_tables.dart
// Nama database, nama tabel, dan perintah SQL pembuat tabel.
//
// CARA MENAMBAH TABEL/KOLOM:
//  1. Tulis perintah SQL-nya di [_v1], [_v2], ... (buat daftar baru, misal _v3)
//  2. Masukkan ke [upgradeSteps] dengan nomor versi barunya
//  3. Naikkan [version]
// Dengan begitu HP yang sudah memasang versi lama ikut mendapat tabel baru.
// ============================================================

class DatabaseTables {
  DatabaseTables._();

  static const String databaseName = 'logeva_client.db';
  static const int version = 3;

  // ---- Data lapangan (versi 1) ----
  static const String pengungsi = 'pengungsi';
  static const String logistik = 'logistik';
  static const String riwayat = 'riwayat_transaksi';

  // ---- Pengguna & posko (versi 2) ----
  static const String admin = 'admin';
  static const String relawan = 'relawan';
  static const String posko = 'posko';

  /// Versi 1: tabel data lapangan.
  static const List<String> _v1 = [
    '''
    CREATE TABLE $pengungsi (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nama TEXT NOT NULL,
      nik TEXT,
      jenis_kelamin TEXT NOT NULL,
      usia INTEGER NOT NULL,
      kondisi TEXT NOT NULL,
      domisili TEXT NOT NULL,
      posko TEXT NOT NULL,
      dibuat_pada TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE $logistik (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nama_barang TEXT NOT NULL,
      kategori TEXT NOT NULL,
      jumlah INTEGER NOT NULL,
      satuan TEXT NOT NULL,
      posko TEXT NOT NULL,
      dibuat_pada TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE $riwayat (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      jenis TEXT NOT NULL,
      jenis_data TEXT NOT NULL,
      status TEXT NOT NULL,
      jumlah_baris INTEGER NOT NULL DEFAULT 0,
      keterangan TEXT,
      waktu TEXT NOT NULL
    )
    ''',
  ];

  /// Versi 2: akun admin, akun relawan, dan daftar posko.
  ///
  /// Catatan: relawan.posko berisi NAMA posko (bukan id), sama seperti
  /// kolom posko di tabel pengungsi & logistik, supaya data lama tetap cocok.
  static const List<String> _v2 = [
    '''
    CREATE TABLE $admin (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nama TEXT NOT NULL,
      username TEXT NOT NULL UNIQUE,
      email TEXT NOT NULL UNIQUE,
      password_hash TEXT NOT NULL,
      password_salt TEXT NOT NULL,
      dibuat_pada TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE $posko (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nama TEXT NOT NULL UNIQUE,
      alamat TEXT,
      dibuat_pada TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE $relawan (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nama TEXT NOT NULL,
      pin TEXT NOT NULL UNIQUE,
      posko TEXT,
      no_hp TEXT,
      dibuat_pada TEXT NOT NULL
    )
    ''',
  ];

  /// Versi 3: role & status akun, kontak relawan, waktu login terakhir.
  /// (Kolom relawan.no_hp dari versi 2 tidak dipakai lagi, diganti 'kontak'.)
  static const List<String> _v3 = [
    "ALTER TABLE $admin ADD COLUMN role TEXT NOT NULL DEFAULT 'Super Admin'",
    "ALTER TABLE $admin ADD COLUMN status TEXT NOT NULL DEFAULT 'Aktif'",
    'ALTER TABLE $relawan ADD COLUMN kontak TEXT',
    "ALTER TABLE $relawan ADD COLUMN status TEXT NOT NULL DEFAULT 'Aktif'",
    'ALTER TABLE $relawan ADD COLUMN terakhir_login TEXT',
  ];

  /// Perintah untuk HP yang baru pertama kali memasang aplikasi.
  static const List<String> createStatements = [..._v1, ..._v2, ..._v3];

  /// Perintah tambahan per versi, untuk HP yang memperbarui aplikasi.
  /// Contoh: HP dengan database versi 1 menjalankan langkah versi 2 lalu 3.
  static const Map<int, List<String>> upgradeSteps = {
    2: _v2,
    3: _v3,
  };
}
