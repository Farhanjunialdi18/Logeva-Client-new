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

  /// MASTER BARANG BAKU, sama persis dengan website
  /// (app/Support/MasterLogistikBaku.php). Ubah di kedua tempat.
  /// (nama, id kategori, satuan, kebutuhan per orang per hari; null = bukan
  /// barang habis pakai harian, tidak dihitung "cukup berapa hari").
  static const List<(String, int, String, double?)> barangAwal = [
    ('Beras', 1, 'kg', 0.3),
    ('Mie Instan', 1, 'bungkus', null),
    ('Telur Ayam', 1, 'butir', null),
    ('Air Mineral', 2, 'liter', 2),
    ('Baju', 3, 'potong', null),
    ('Celana', 3, 'potong', null),
    ('Selimut', 4, 'lembar', null),
    ('Tikar', 4, 'lembar', null),
    ('Pembalut', 5, 'pak', null),
    ('Sabun Mandi', 5, 'batang', null),
    ('Masker', 6, 'kotak', null),
    ('Paracetamol', 6, 'strip', null),
    ('Popok Bayi', 7, 'pak', null),
    ('Susu Formula', 7, 'kaleng', null),
    ('Minyak Goreng', 8, 'liter', null),
  ];

  /// Nama lama barang yang sudah digabung (huruf kecil) -> nama baku.
  /// Sama dengan MasterLogistikBaku::ALIAS di website.
  static const Map<String, String> aliasBarang = {
    'pakaian layak pakai': 'Baju',
  };

  /// Nama baku untuk [nama] (nama lama -> nama baru; lainnya tetap).
  static String namaBakuBarang(String nama) =>
      aliasBarang[nama.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase()] ?? nama;

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
