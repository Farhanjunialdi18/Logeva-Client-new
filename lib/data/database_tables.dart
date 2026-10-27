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

import '../core/data_options.dart';
import '../utils/kode_unik.dart';

class DatabaseTables {
  DatabaseTables._();

  static const String databaseName = 'logeva_client.db';
  static const int version = 9;

  // ---- Data lapangan (versi 1) ----
  static const String pengungsi = 'pengungsi';
  static const String logistik = 'logistik'; // versi 1–6, lalu arsip
  static const String riwayat = 'riwayat_transaksi';

  // ---- Pengguna & posko (versi 2) ----
  static const String admin = 'admin';
  static const String relawan = 'relawan';
  static const String posko = 'posko';

  // ---- Pengaturan perangkat (versi 4) ----
  static const String pengaturan = 'pengaturan';

  // ---- Logistik mengikuti website (versi 7) ----
  static const String kategoriLogistik = 'kategori_logistik';
  static const String barang = 'barang';
  static const String barangMasuk = 'barang_masuk';
  static const String barangKeluar = 'barang_keluar';
  static const String logistikLama = 'logistik_lama';

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
  /// (Sejak versi 5 relawan memakai posko_id; kolom nama hanya cadangan.)
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

  /// Versi 4: pengaturan perangkat (kunci -> nilai), misalnya
  /// kode_perangkat untuk Paket Data Posko.
  static const List<String> _v4 = [
    '''
    CREATE TABLE $pengaturan (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      kunci TEXT NOT NULL UNIQUE,
      nilai TEXT
    )
    ''',
  ];

  /// Versi 5: posko mengikuti tabel `lokasis` website + kode unik,
  /// dan relawan merujuk posko lewat id (posko_id).
  static const List<String> _v5 = [
    // 1. Nama posko yang dipakai relawan/pengungsi/logistik tapi belum
    //    terdaftar di tabel posko -> daftarkan dulu (tanpa beda huruf besar/kecil).
    '''
    INSERT INTO $posko (nama, alamat, dibuat_pada)
    SELECT MIN(trim(nama)), '', MIN(dibuat_pada) FROM (
      SELECT posko AS nama, dibuat_pada FROM $relawan
      UNION ALL SELECT posko, dibuat_pada FROM $pengungsi
      UNION ALL SELECT posko, dibuat_pada FROM $logistik
    )
    WHERE trim(coalesce(nama, '')) NOT IN ('', '-')
      AND lower(trim(nama)) NOT IN (SELECT lower(trim(nama)) FROM $posko)
    GROUP BY lower(trim(nama))
    ''',
    // 2. Kolom baru posko.
    'ALTER TABLE $posko ADD COLUMN kode TEXT',
    "ALTER TABLE $posko ADD COLUMN nama_desa TEXT NOT NULL DEFAULT ''",
    'ALTER TABLE $posko ADD COLUMN luas_lokasi REAL',
    'ALTER TABLE $posko ADD COLUMN kapasitas_pengungsi INTEGER NOT NULL DEFAULT 0',
    "ALTER TABLE $posko ADD COLUMN latitude TEXT NOT NULL DEFAULT ''",
    "ALTER TABLE $posko ADD COLUMN longitude TEXT NOT NULL DEFAULT ''",
    "ALTER TABLE $posko ADD COLUMN status_operasional TEXT NOT NULL DEFAULT 'siaga'",
    'ALTER TABLE $posko ADD COLUMN mulai_beroperasi_at TEXT',
    'ALTER TABLE $posko ADD COLUMN selesai_beroperasi_at TEXT',
    'ALTER TABLE $posko ADD COLUMN diubah_pada TEXT',
    // 3. Isi posko lama: kode unik per baris, desa sementara = nama posko
    //    (admin melengkapi sebelum ekspor), diubah_pada = dibuat_pada.
    'UPDATE $posko SET kode = ${KodeUnik.sql} WHERE kode IS NULL',
    "UPDATE $posko SET nama_desa = nama WHERE nama_desa = ''",
    "UPDATE $posko SET alamat = '' WHERE alamat IS NULL",
    'UPDATE $posko SET diubah_pada = dibuat_pada WHERE diubah_pada IS NULL',
    'CREATE UNIQUE INDEX idx_posko_kode ON $posko (kode)',
    // 4. Relawan merujuk posko lewat id.
    'ALTER TABLE $relawan ADD COLUMN posko_id INTEGER',
    '''
    UPDATE $relawan SET posko_id = (
      SELECT p.id FROM $posko p
      WHERE lower(trim(p.nama)) = lower(trim($relawan.posko))
    )
    WHERE trim(coalesce(posko, '')) <> ''
    ''',
  ];

  /// Versi 6: pengungsi mengikuti tabel `pengungsis` website + kode unik,
  /// merujuk posko lewat id, dan penghapusan hanya ditandai (dihapus_pada).
  ///
  /// SQLite tidak bisa mengganti nama/aturan kolom dengan aman, jadi tabel
  /// dibuat ulang lalu data lama dipindahkan:
  ///  - jenis_kelamin L/P   -> 'Laki-laki' / 'Perempuan'
  ///  - domisili            -> asal
  ///  - kondisi (pilihan lama) -> kondisi_kesehatan + kelompok_rentan
  ///  - nik                 -> nik_lama (disimpan, tidak ditampilkan/diekspor;
  ///                           NIK bukan nomor KK)
  ///  - tanggal_lahir       -> kosong (data lama ditandai "perlu dilengkapi")
  static const List<String> _v6 = [
    '''
    CREATE TABLE pengungsi_v6 (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      kode TEXT NOT NULL UNIQUE,
      posko_id INTEGER,
      nama TEXT NOT NULL,
      asal TEXT NOT NULL DEFAULT '',
      tanggal_lahir TEXT,
      usia INTEGER NOT NULL,
      jenis_kelamin TEXT NOT NULL,
      nomor_kk TEXT,
      kondisi_kesehatan TEXT NOT NULL DEFAULT 'Sehat',
      kelompok_rentan TEXT NOT NULL DEFAULT 'Tidak',
      riwayat_penyakit TEXT,
      nik_lama TEXT,
      dicatat_oleh TEXT,
      dibuat_pada TEXT NOT NULL,
      diubah_pada TEXT NOT NULL,
      dihapus_pada TEXT
    )
    ''',
    '''
    INSERT INTO pengungsi_v6 (id, kode, posko_id, nama, asal, usia,
      jenis_kelamin, kondisi_kesehatan, kelompok_rentan, nik_lama,
      dibuat_pada, diubah_pada)
    SELECT g.id, ${KodeUnik.sql},
      (SELECT p.id FROM $posko p
        WHERE lower(trim(p.nama)) = lower(trim(g.posko))),
      g.nama, coalesce(g.domisili, ''), g.usia,
      CASE WHEN upper(trim(g.jenis_kelamin)) LIKE 'P%'
        THEN 'Perempuan' ELSE 'Laki-laki' END,
      CASE WHEN trim(coalesce(g.kondisi, '')) IN ('', 'Ibu Hamil', 'Disabilitas')
        THEN 'Sehat' ELSE trim(g.kondisi) END,
      CASE trim(coalesce(g.kondisi, ''))
        WHEN 'Ibu Hamil' THEN 'Ibu Hamil'
        WHEN 'Disabilitas' THEN 'Disabilitas'
        WHEN 'Sakit Ringan' THEN 'Sakit'
        WHEN 'Perlu Perawatan' THEN 'Sakit'
        ELSE 'Tidak'
      END,
      nullif(trim(coalesce(g.nik, '')), ''),
      g.dibuat_pada, g.dibuat_pada
    FROM $pengungsi g
    ''',
    'DROP TABLE $pengungsi',
    'ALTER TABLE pengungsi_v6 RENAME TO $pengungsi',
    'CREATE INDEX idx_pengungsi_posko ON $pengungsi (posko_id)',
  ];

  /// Versi 7: logistik mengikuti website. Satu tabel `logistik` lama
  /// (stok yang bisa diedit bebas) dipecah menjadi:
  ///  - kategori_logistik : 10 kategori website (id sama dengan website)
  ///  - barang            : master barang + kebutuhan per orang per hari
  ///  - barang_masuk      : catatan tetap, menambah stok
  ///  - barang_keluar     : catatan tetap, mengurangi stok
  /// Stok TIDAK disimpan: selalu dihitung dari catatan (masuk − keluar).
  ///
  /// Data lama: setiap baris logistik (jumlah > 0) menjadi satu catatan
  /// barang masuk "Saldo awal", sehingga stok di HP tetap sama. Tabel lama
  /// tidak dihapus, hanya diganti nama menjadi logistik_lama (arsip).
  static final List<String> _v7 = [
    '''
    CREATE TABLE $kategoriLogistik (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      nama TEXT NOT NULL UNIQUE COLLATE NOCASE
    )
    ''',
    'INSERT INTO $kategoriLogistik (id, nama) VALUES '
        '${[
      for (final (i, nama) in DataOptions.kategoriLogistik.indexed)
        '(${i + 1}, ${_teks(nama)})',
    ].join(', ')}',
    '''
    CREATE TABLE $barang (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      kategori_id INTEGER NOT NULL,
      nama_item TEXT NOT NULL COLLATE NOCASE,
      satuan TEXT NOT NULL,
      kebutuhan_harian REAL,
      deskripsi TEXT,
      dibuat_pada TEXT NOT NULL,
      diubah_pada TEXT NOT NULL,
      UNIQUE (kategori_id, nama_item)
    )
    ''',
    'INSERT INTO $barang (kategori_id, nama_item, satuan, kebutuhan_harian, '
        'dibuat_pada, diubah_pada) VALUES '
        '${[
      for (final (nama, kategori, satuan, kebutuhan) in DataOptions.barangAwal)
        '($kategori, ${_teks(nama)}, ${_teks(satuan)}, $kebutuhan, '
            '$_sekarang, $_sekarang)',
    ].join(', ')}',
    '''
    CREATE TABLE $barangMasuk (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      kode TEXT NOT NULL UNIQUE,
      posko_id INTEGER,
      barang_id INTEGER NOT NULL,
      jumlah_masuk INTEGER NOT NULL CHECK (jumlah_masuk >= 1),
      sumber_bantuan TEXT NOT NULL,
      tanggal_masuk TEXT NOT NULL,
      keterangan TEXT,
      dicatat_oleh TEXT,
      dibuat_pada TEXT NOT NULL
    )
    ''',
    '''
    CREATE TABLE $barangKeluar (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      kode TEXT NOT NULL UNIQUE,
      posko_id INTEGER,
      barang_id INTEGER NOT NULL,
      jumlah_keluar INTEGER NOT NULL CHECK (jumlah_keluar >= 1),
      tujuan TEXT NOT NULL,
      penerima TEXT,
      tanggal_keluar TEXT NOT NULL,
      keterangan TEXT,
      dicatat_oleh TEXT,
      dibuat_pada TEXT NOT NULL
    )
    ''',
    'CREATE INDEX idx_barang_masuk_posko ON $barangMasuk (posko_id)',
    'CREATE INDEX idx_barang_keluar_posko ON $barangKeluar (posko_id)',

    // ---- Pindahkan data logistik lama ----
    // 1. Barang lama yang belum ada di master -> tambahkan ke master.
    '''
    INSERT INTO $barang (kategori_id, nama_item, satuan, dibuat_pada, diubah_pada)
    SELECT k, MIN(nama), MIN(satuan), MIN(dibuat_pada), MIN(dibuat_pada) FROM (
      SELECT ${_kategoriLama('l.kategori')} AS k,
        trim(l.nama_barang) AS nama,
        coalesce(nullif(lower(trim(l.satuan)), ''), 'buah') AS satuan,
        l.dibuat_pada AS dibuat_pada
      FROM $logistik l
      WHERE trim(l.nama_barang) <> ''
    ) baru
    WHERE NOT EXISTS (
      SELECT 1 FROM $barang b WHERE b.kategori_id = baru.k AND b.nama_item = baru.nama
    )
    GROUP BY k, lower(nama)
    ''',
    // 2. Setiap baris lama (jumlah > 0) -> satu catatan barang masuk.
    '''
    INSERT INTO $barangMasuk (kode, posko_id, barang_id, jumlah_masuk,
      sumber_bantuan, tanggal_masuk, keterangan, dibuat_pada)
    SELECT ${KodeUnik.sql},
      (SELECT p.id FROM $posko p
        WHERE lower(trim(p.nama)) = lower(trim(l.posko))),
      b.id, l.jumlah, 'Saldo awal (data aplikasi lama)',
      substr(l.dibuat_pada, 1, 10),
      'Dipindahkan dari data logistik versi lama' ||
        CASE WHEN lower(trim(l.satuan)) NOT IN ('', lower(b.satuan))
          THEN ' (satuan lama: ' || trim(l.satuan) || ')' ELSE '' END,
      l.dibuat_pada
    FROM $logistik l
    JOIN $barang b ON b.kategori_id = ${_kategoriLama('l.kategori')}
      AND b.nama_item = trim(l.nama_barang)
    WHERE l.jumlah > 0
    ''',
    // 3. Tabel lama disimpan sebagai arsip (tidak dipakai lagi).
    'ALTER TABLE $logistik RENAME TO $logistikLama',
  ];

  /// Versi 8: akun siap dipakai di beberapa HP satu posko (HP Induk & Anggota).
  ///  - admin & relawan mendapat `kode` unik + `diubah_pada`, supaya akun bisa
  ///    dikirim dari HP Induk ke HP Anggota tanpa dobel.
  ///  - relawan.pin_hash = PIN yang diacak (PBKDF2, lihat pin_hasher.dart); dipakai
  ///    LOGIN di semua HP. relawan.pin (PIN asli) hanya ada di HP Induk supaya admin
  ///    bisa melihat & memberitahukannya; di HP Anggota kosong.
  ///    Tabel relawan dibuat ulang karena kolom pin lama wajib terisi (NOT NULL).
  ///    pin_hash data lama diisi otomatis saat aplikasi dipakai (butuh salt HP).
  static final List<String> _v8 = [
    'ALTER TABLE $admin ADD COLUMN kode TEXT',
    'ALTER TABLE $admin ADD COLUMN diubah_pada TEXT',
    'UPDATE $admin SET kode = ${KodeUnik.sql} WHERE kode IS NULL',
    'UPDATE $admin SET diubah_pada = dibuat_pada WHERE diubah_pada IS NULL',
    'CREATE UNIQUE INDEX idx_admin_kode ON $admin (kode)',
    '''
    CREATE TABLE relawan_v8 (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      kode TEXT NOT NULL UNIQUE,
      nama TEXT NOT NULL,
      pin TEXT UNIQUE,
      pin_hash TEXT,
      posko TEXT,
      posko_id INTEGER,
      no_hp TEXT,
      kontak TEXT,
      status TEXT NOT NULL DEFAULT 'Aktif',
      terakhir_login TEXT,
      dibuat_pada TEXT NOT NULL,
      diubah_pada TEXT NOT NULL
    )
    ''',
    '''
    INSERT INTO relawan_v8 (id, kode, nama, pin, posko, posko_id, no_hp, kontak,
      status, terakhir_login, dibuat_pada, diubah_pada)
    SELECT id, ${KodeUnik.sql}, nama, nullif(trim(pin), ''), posko, posko_id, no_hp,
      kontak, coalesce(status, 'Aktif'), terakhir_login, dibuat_pada, dibuat_pada
    FROM $relawan
    ''',
    'DROP TABLE $relawan',
    'ALTER TABLE relawan_v8 RENAME TO $relawan',
  ];

  /// Kategori teks aplikasi lama -> id kategori website.
  /// Obat-obatan -> Medis, Perlengkapan -> Perlengkapan Tidur,
  /// nama yang sama dengan kategori website -> kategori itu, lainnya -> Lainnya.
  static String _kategoriLama(String kolom) {
    final k = DataOptions.kategoriLogistik;
    final sama = [
      for (final (i, nama) in k.indexed)
        "WHEN ${_teks(nama.toLowerCase())} THEN ${i + 1}",
    ].join(' ');
    return "(CASE lower(trim($kolom)) "
        "WHEN 'obat-obatan' THEN ${k.indexOf('Medis') + 1} "
        "WHEN 'perlengkapan' THEN ${k.indexOf('Perlengkapan Tidur') + 1} "
        "$sama ELSE ${k.indexOf('Lainnya') + 1} END)";
  }

  /// Teks SQL dengan tanda kutip aman.
  static String _teks(String nilai) => "'${nilai.replaceAll("'", "''")}'";

  static const String _sekarang =
      "strftime('%Y-%m-%dT%H:%M:%f', 'now', 'localtime')";

  /// Versi 9: pengungsi yang pulang / pindah posko / dirujuk tidak lagi
  /// dihapus, tapi dicatat keberadaannya (data lama = masih di posko).
  static final List<String> _v9 = [
    "ALTER TABLE $pengungsi ADD COLUMN status_keberadaan TEXT NOT NULL DEFAULT 'di_posko'",
    'ALTER TABLE $pengungsi ADD COLUMN keluar_pada TEXT',
    'ALTER TABLE $pengungsi ADD COLUMN keterangan_keluar TEXT',
  ];

  /// Perintah untuk HP yang baru pertama kali memasang aplikasi.
  static final List<String> createStatements = [
    ..._v1,
    ..._v2,
    ..._v3,
    ..._v4,
    ..._v5,
    ..._v6,
    ..._v7,
    ..._v8,
    ..._v9,
  ];

  /// Perintah per versi, untuk HP yang memperbarui aplikasi.
  /// Contoh: HP dengan database versi 1 menjalankan langkah versi 2, 3, lalu 4.
  /// (Langkah versi 1 ikut dicantumkan supaya tes bisa membuat database lama.)
  static final Map<int, List<String>> upgradeSteps = {
    1: _v1,
    2: _v2,
    3: _v3,
    4: _v4,
    5: _v5,
    6: _v6,
    7: _v7,
    8: _v8,
    9: _v9,
  };
}
