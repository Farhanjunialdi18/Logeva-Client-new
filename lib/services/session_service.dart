// ============================================================
// session_service.dart
// Menyimpan siapa yang sedang login: relawan ATAU admin.
// ============================================================

import '../models/admin.dart';
import '../models/relawan_session.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  // ---------------- RELAWAN ----------------

  RelawanSession? relawan;

  String get namaRelawan => relawan?.nama ?? 'Relawan';
  String get posko => relawan?.posko ?? '-';
  String get poskoLabel => relawan?.poskoLabel ?? 'Posko belum ditentukan';

  void startRelawan(RelawanSession session) {
    admin = null;
    relawan = session;
  }

  // ---------------- ADMIN ----------------

  Admin? admin;

  String get namaAdmin => admin?.nama ?? 'Admin';

  void startAdmin(Admin session) {
    relawan = null;
    admin = session;
  }

  // ---------------- PENCATAT ----------------

  /// Nama akun yang sedang login, untuk kolom dicatat_oleh.
  String get namaPencatat => relawan?.nama ?? admin?.nama ?? '';

  /// Posko tugas relawan yang login (null = admin / belum ditempatkan).
  int? get poskoId => relawan?.poskoId;

  // ---------------- LOGOUT ----------------

  void clear() {
    relawan = null;
    admin = null;
  }
}
