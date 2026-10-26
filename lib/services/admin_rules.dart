// ============================================================
// admin_rules.dart
// ATURAN pengelolaan akun admin, dipisah dari tampilan supaya
// mudah dicari dan diubah:
//  1. Hanya Super Admin yang boleh menambah/mengubah/menghapus admin.
//  2. Admin tidak boleh menonaktifkan atau menghapus akunnya sendiri.
//  3. Minimal harus selalu ada 1 Super Admin yang aktif.
//  4. Di HP Anggota akun admin tidak bisa diubah (dikelola di HP Induk).
// Setiap fungsi mengembalikan PESAN ERROR, atau null kalau boleh.
// ============================================================

import '../core/data_options.dart';
import '../data/repositories/admin_repository.dart';
import '../models/admin.dart';
import 'perangkat_service.dart';
import 'session_service.dart';

class AdminRules {
  AdminRules._();

  static Admin? get _me => SessionService.instance.admin;

  /// Apakah admin yang sedang login boleh mengelola akun admin?
  static bool get bolehKelola =>
      (_me?.isSuperAdmin ?? false) && !PerangkatService.isAnggota;

  /// Pesan saat tombol kelola admin disembunyikan.
  static String get pesanTidakBoleh => PerangkatService.isAnggota
      ? PerangkatService.pesanDikelolaInduk
      : pesanBukanSuperAdmin;

  static const String pesanBukanSuperAdmin =
      'Hanya Super Admin yang dapat mengelola akun admin.';

  /// Cek sebelum menyimpan perubahan role/status admin [target].
  static Future<String?> cekUbah(
    Admin target, {
    required String roleBaru,
    required String statusBaru,
  }) async {
    if (!bolehKelola) return pesanTidakBoleh;

    final akunSendiri = target.id != null && target.id == _me?.id;
    if (akunSendiri && statusBaru == DataOptions.statusNonaktif) {
      return 'Anda tidak bisa menonaktifkan akun sendiri.';
    }

    final kehilanganSuperAdmin = target.isSuperAdmin &&
        target.isAktif &&
        (roleBaru != DataOptions.roleSuperAdmin ||
            statusBaru == DataOptions.statusNonaktif);
    if (kehilanganSuperAdmin &&
        await AdminRepository.instance.countActiveSuperAdmin() <= 1) {
      return 'Minimal harus ada 1 Super Admin yang aktif.';
    }
    return null;
  }

  /// Cek sebelum menghapus admin [target].
  static Future<String?> cekHapus(Admin target) async {
    if (!bolehKelola) return pesanTidakBoleh;
    if (target.id == _me?.id) return 'Anda tidak bisa menghapus akun sendiri.';
    if (target.isSuperAdmin &&
        target.isAktif &&
        await AdminRepository.instance.countActiveSuperAdmin() <= 1) {
      return 'Minimal harus ada 1 Super Admin yang aktif.';
    }
    return null;
  }
}
