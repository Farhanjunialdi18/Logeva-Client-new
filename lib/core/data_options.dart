// ============================================================
// data_options.dart
// Daftar pilihan untuk dropdown (kondisi, kategori, satuan).
// Tambah/ubah pilihan cukup di file ini.
// ============================================================

class DataOptions {
  DataOptions._();

  // ---- Pengungsi (nilai sama persis dengan website) ----
  static const String lakiLaki = 'Laki-laki';
  static const String perempuan = 'Perempuan';
  static const List<String> jenisKelamin = [lakiLaki, perempuan];

  /// Kondisi kesehatan = teks bebas; kosong berarti 'Sehat'.
  static const String kondisiSehat = 'Sehat';

  static const String bukanRentan = 'Tidak';
  static const List<String> kelompokRentan = [
    bukanRentan,
    'Ibu Hamil',
    'Lansia',
    'Bayi',
    'Disabilitas',
    'Sakit',
  ];

  /// Keberadaan pengungsi (kolom status_keberadaan, sama dengan website).
  /// Hanya yang masih "di posko" dihitung untuk kapasitas & kebutuhan.
  static const String diPosko = 'di_posko';
  static const String pulang = 'pulang';
  static const String pindah = 'pindah';
  static const String dirujuk = 'dirujuk';
  static const Map<String, String> statusKeberadaan = {
    diPosko: 'Di posko',
    pulang: 'Pulang ke rumah',
    pindah: 'Pindah ke posko lain',
    dirujuk: 'Dirujuk ke RS / Puskesmas',
  };

  // ---- Logistik (nilai sama persis dengan website) ----
  static const String semuaKategori = 'Semua Kategori';

  /// Kategori bawaan website, urutan = id 1–10 (KategoriLogistikSeeder).
  static const List<String> kategoriLogistik = [
    'Makanan',
    'Minuman',
    'Pakaian',
    'Perlengkapan Tidur',
    'Kebersihan',
    'Medis',
    'Bayi & Anak',
    'Dapur Umum',
    'Sanitasi',
    'Lainnya',
  ];

  /// Master barang bawaan website: (nama, id kategori, satuan,
  /// kebutuhan per orang per hari).
  static const List<(String, int, String, double)> barangAwal = [
    ('Beras', 1, 'kg', 0.3),
    ('Air Mineral', 2, 'liter', 3),
  ];

  /// Untuk apa barang dikeluarkan (StokKeluar::TUJUAN): kunci -> label.
  static const Map<String, String> tujuanKeluar = {
    'dibagikan': 'Dibagikan ke pengungsi',
    'dapur_umum': 'Dimasak di dapur umum',
    'dikirim': 'Dikirim ke posko lain',
    'rusak': 'Rusak / kedaluwarsa / hilang',
    'lainnya': 'Lainnya',
  };

  // ---- Akun admin & relawan ----
  static const String roleSuperAdmin = 'Super Admin';
  static const String roleAdmin = 'Admin';
  static const List<String> roleAdmins = [roleSuperAdmin, roleAdmin];

  static const String statusAktif = 'Aktif';
  static const String statusNonaktif = 'Nonaktif';
  static const List<String> statusAkun = [statusAktif, statusNonaktif];

  /// Saran satuan (huruf kecil seperti di website). Satuan lain boleh.
  static const List<String> satuanLogistik = [
    'kg',
    'liter',
    'dus',
    'karung',
    'paket',
    'buah',
    'pcs',
    'botol',
    'bungkus',
    'lembar',
  ];
}
