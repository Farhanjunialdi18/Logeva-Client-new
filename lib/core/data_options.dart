// ============================================================
// data_options.dart
// Daftar pilihan untuk dropdown (kondisi, kategori, satuan).
// Tambah/ubah pilihan cukup di file ini.
// ============================================================

class DataOptions {
  DataOptions._();

  // ---- Pengungsi ----
  static const List<String> kondisiPengungsi = [
    'Sehat',
    'Sakit Ringan',
    'Perlu Perawatan',
    'Ibu Hamil',
    'Disabilitas',
  ];

  // ---- Logistik ----
  static const String semuaKategori = 'Semua Kategori';

  static const List<String> kategoriLogistik = [
    'Makanan',
    'Minuman',
    'Perlengkapan',
    'Obat-obatan',
    'Pakaian',
    'Lainnya',
  ];

  // ---- Akun admin & relawan ----
  static const String roleSuperAdmin = 'Super Admin';
  static const String roleAdmin = 'Admin';
  static const List<String> roleAdmins = [roleSuperAdmin, roleAdmin];

  static const String statusAktif = 'Aktif';
  static const String statusNonaktif = 'Nonaktif';
  static const List<String> statusAkun = [statusAktif, statusNonaktif];

  static const List<String> satuanLogistik = [
    'Dus',
    'Kg',
    'Buah',
    'Pcs',
    'Liter',
    'Karung',
    'Paket',
    'Lembar',
  ];
}
