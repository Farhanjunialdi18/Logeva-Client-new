// ============================================================
// admin_repository.dart
// Semua operasi data AKUN ADMIN (ambil, cari, tambah, ubah, hapus).
// Aturan "boleh/tidak boleh" ada di services/admin_rules.dart.
// ============================================================

import '../../core/data_options.dart';
import '../../models/admin.dart';
import '../../utils/kode_unik.dart';
import '../../utils/password_hasher.dart';
import '../data_events.dart';
import '../database_tables.dart';
import '../local_database.dart';
import '../table_store.dart';

class AdminRepository {
  AdminRepository._(this._store);
  static final AdminRepository instance = AdminRepository._(LocalDatabase.store);

  /// Untuk tes: repository dengan penyimpanan sendiri.
  factory AdminRepository.withStore(TableStore store) =>
      AdminRepository._(store);

  final TableStore _store;

  static const String _table = DatabaseTables.admin;

  // ---- Akun admin pertama (dibuat otomatis kalau tabel masih kosong) ----
  // Segera ganti password ini lewat menu Kelola Admin / Settings.
  static const String defaultNama = 'Admin GMLS';
  static const String defaultUsername = 'admin';
  static const String defaultEmail = 'admin@gmls.id';
  static const String defaultPassword = 'admin123';

  // ---------------- AMBIL DATA ----------------

  Future<List<Admin>> getAll() async {
    final rows = await _store.getAll(_table);
    return rows.map(Admin.fromMap).toList();
  }

  Future<int> count() => _store.count(_table);

  Future<Admin?> findById(int id) async {
    for (final admin in await getAll()) {
      if (admin.id == id) return admin;
    }
    return null;
  }

  /// Cari admin berdasarkan username ATAU email (tidak peduli huruf besar/kecil).
  Future<Admin?> findByLogin(String identifier) async {
    final id = identifier.trim().toLowerCase();
    for (final admin in await getAll()) {
      if (admin.username.toLowerCase() == id || admin.email.toLowerCase() == id) {
        return admin;
      }
    }
    return null;
  }

  /// Apakah username sudah dipakai admin lain? ([exceptId] = admin yang sedang diedit)
  Future<bool> isUsernameTaken(String username, {int? exceptId}) async {
    final cari = username.trim().toLowerCase();
    return (await getAll())
        .any((a) => a.id != exceptId && a.username.toLowerCase() == cari);
  }

  Future<bool> isEmailTaken(String email, {int? exceptId}) async {
    final cari = email.trim().toLowerCase();
    return (await getAll())
        .any((a) => a.id != exceptId && a.email.toLowerCase() == cari);
  }

  /// Jumlah Super Admin yang masih aktif (minimal harus ada 1).
  Future<int> countActiveSuperAdmin() async {
    return (await getAll()).where((a) => a.isSuperAdmin && a.isAktif).length;
  }

  // ---------------- SIMPAN DATA ----------------

  /// Buat akun admin pertama kalau belum ada admin sama sekali.
  Future<void> ensureDefaultAdmin() async {
    if (await count() > 0) return;
    await add(
      nama: defaultNama,
      username: defaultUsername,
      email: defaultEmail,
      password: defaultPassword,
      role: DataOptions.roleSuperAdmin,
    );
  }

  /// Tambah admin baru. Password otomatis di-hash.
  Future<void> add({
    required String nama,
    required String username,
    required String email,
    required String password,
    String role = DataOptions.roleAdmin,
    String status = DataOptions.statusAktif,
  }) async {
    final hashed = PasswordHasher.create(password);
    final admin = Admin(
      kode: KodeUnik.buat(),
      nama: nama.trim(),
      username: username.trim().toLowerCase(),
      email: email.trim().toLowerCase(),
      passwordHash: hashed.hash,
      passwordSalt: hashed.salt,
      role: role,
      status: status,
      dibuatPada: DateTime.now(),
    );
    await _store.insert(_table, admin.toMap());
    DataEvents.instance.notifyChanged();
  }

  /// Simpan perubahan. Kalau [newPassword] diisi, password ikut diganti.
  Future<Admin> update(Admin admin, {String? newPassword}) async {
    var data = admin.copyWith(
      nama: admin.nama.trim(),
      username: admin.username.trim().toLowerCase(),
      email: admin.email.trim().toLowerCase(),
      // Dipakai saat akun dikirim ke HP Anggota (versi terbaru yang dipakai).
      diubahPada: DateTime.now(),
    );
    if (newPassword != null && newPassword.isNotEmpty) {
      final hashed = PasswordHasher.create(newPassword);
      data = data.copyWith(passwordHash: hashed.hash, passwordSalt: hashed.salt);
    }
    if (data.id != null) {
      await _store.update(_table, data.id!, data.toMap());
      DataEvents.instance.notifyChanged();
    }
    return data;
  }

  // ---------------- PASSWORD ----------------

  /// Apakah admin ini masih memakai password bawaan (admin123)?
  /// Semua HP memasang akun bawaan yang sama, jadi password ini WAJIB
  /// diganti sebelum aplikasi dipakai.
  bool masihPasswordBawaan(Admin admin) => PasswordHasher.verify(
        defaultPassword,
        hash: admin.passwordHash,
        salt: admin.passwordSalt,
      );

  /// Ganti password. Hasil: pesan kesalahan, atau null kalau berhasil.
  /// [lama] diisi = password lama dicek dulu (halaman Keamanan).
  Future<String?> gantiPassword(Admin admin, String baru, {String? lama}) async {
    if (lama != null &&
        !PasswordHasher.verify(lama,
            hash: admin.passwordHash, salt: admin.passwordSalt)) {
      return 'Password lama salah.';
    }
    if (PasswordHasher.verify(baru,
        hash: admin.passwordHash, salt: admin.passwordSalt)) {
      return 'Password baru harus berbeda dari password lama.';
    }
    await update(admin, newPassword: baru);
    return null;
  }

  Future<void> delete(int id) async {
    await _store.delete(_table, id);
    DataEvents.instance.notifyChanged();
  }
}
