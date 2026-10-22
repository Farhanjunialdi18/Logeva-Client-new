// ============================================================
// aktivitas_service.dart
// Menyusun daftar "AKTIVITAS TERBARU" di Beranda Admin dari:
//  - riwayat import/export CSV
//  - akun relawan yang baru dibuat
//  - akun admin yang baru dibuat
// Tidak butuh tabel baru: datanya diambil dari tabel yang sudah ada.
// ============================================================

import '../data/repositories/admin_repository.dart';
import '../data/repositories/relawan_repository.dart';
import '../data/repositories/riwayat_repository.dart';

enum JenisAktivitas { impor, ekspor, relawanBaru, adminBaru, gagal }

class Aktivitas {
  final JenisAktivitas jenis;
  final String judul;
  final DateTime waktu;

  const Aktivitas({
    required this.jenis,
    required this.judul,
    required this.waktu,
  });
}

class AktivitasService {
  AktivitasService._();

  /// Ambil [limit] aktivitas terbaru, urut dari yang paling baru.
  static Future<List<Aktivitas>> terbaru({int limit = 5}) async {
    final semua = <Aktivitas>[];

    for (final r in await RiwayatRepository.instance.getAll()) {
      final aksi = r.isImport ? 'Import Data' : 'Export Data';
      final jumlah = r.jumlahBaris > 0 ? ' · ${r.jumlahBaris} data' : '';
      semua.add(Aktivitas(
        jenis: !r.berhasil
            ? JenisAktivitas.gagal
            : (r.isImport ? JenisAktivitas.impor : JenisAktivitas.ekspor),
        judul: r.berhasil
            ? '$aksi · ${r.jenisData}$jumlah'
            : '$aksi Gagal · ${r.jenisData}',
        waktu: r.waktu,
      ));
    }

    for (final r in await RelawanRepository.instance.getAll()) {
      semua.add(Aktivitas(
        jenis: JenisAktivitas.relawanBaru,
        judul: 'Relawan Baru · ${r.nama}',
        waktu: r.dibuatPada,
      ));
    }

    for (final a in await AdminRepository.instance.getAll()) {
      semua.add(Aktivitas(
        jenis: JenisAktivitas.adminBaru,
        judul: 'Admin Baru · ${a.nama}',
        waktu: a.dibuatPada,
      ));
    }

    semua.sort((a, b) => b.waktu.compareTo(a.waktu));
    return semua.take(limit).toList();
  }
}
