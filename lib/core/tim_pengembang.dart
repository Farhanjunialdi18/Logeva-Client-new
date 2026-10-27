// ============================================================
// tim_pengembang.dart
// Daftar anggota tim pengembang untuk halaman Tentang.
// Ganti nama & peran. Foto disimpan di assets/images/tim/.
// Kalau foto belum ada, otomatis tampil inisial nama.
// ============================================================

class AnggotaTim {
  final String nama;
  final String peran;
  final String? foto; // path foto, boleh null

  const AnggotaTim({required this.nama, required this.peran, this.foto});
}

class TimPengembang {
  TimPengembang._();

  static const String judul = 'Tim Pengembang Aplikasi';

  static const List<AnggotaTim> anggota = [
    AnggotaTim(
      nama: 'Anis Faisal Reza',
      peran: 'Pembimbing',
      foto: 'assets/images/tim/anggota_1.jpeg',
    ),
    AnggotaTim(
      nama: 'Septian Abimanyu',
      peran: 'Frontend Developer Aplikasi',
      foto: 'assets/images/tim/anggota_2.jpg',
    ),
    AnggotaTim(
      nama: 'Mohammad Farhan Junialdi',
      peran: 'Backend Developer Aplikasi',
      foto: 'assets/images/tim/anggota_3.jpg',
    ),
    AnggotaTim(
      nama: 'Samuel Christophorus Wijaya',
      peran: 'Backend Developer Website',
      foto: 'assets/images/tim/anggota_4.jpeg',
    ),
    AnggotaTim(
      nama: 'Farrel',
      peran: 'Frontend Developer Website',
      foto: 'assets/images/tim/anggota_5.jpeg',
    ),
  ];
}