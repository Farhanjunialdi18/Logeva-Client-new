// ============================================================
// perangkat_service.dart
// PERAN HP ini dalam satu posko, untuk dibaca layar secara langsung:
//  - HP Induk   : dipegang admin/supervisor. Membuat posko, master barang,
//                 dan akun; menyiapkan HP Anggota.
//  - HP Anggota : dipakai relawan, disiapkan dari File Penyiapan HP Induk.
//                 Akun, posko, dan master barang hanya bisa DILIHAT
//                 (dikelola di HP Induk, perubahan masuk lewat sinkron).
// ============================================================

import 'package:flutter/foundation.dart';

import '../data/local_database.dart';
import '../data/repositories/pengaturan_repository.dart';
import '../data/table_store.dart';

class PerangkatService {
  PerangkatService._();

  /// true = HP Anggota. Diperbarui saat aplikasi dibuka & setelah penyiapan.
  static final ValueNotifier<bool> anggota = ValueNotifier(false);

  static bool get isAnggota => anggota.value;

  static Future<void> muat({TableStore? store}) async {
    anggota.value = await PengaturanRepository.withStore(
            store ?? LocalDatabase.store)
        .isAnggota();
  }

  /// Teks untuk tombol yang disembunyikan di HP Anggota.
  static const String pesanDikelolaInduk =
      'Dikelola di HP Induk (admin/supervisor posko). Perubahan dari HP Induk '
      'masuk ke HP ini lewat sinkron.';
}
