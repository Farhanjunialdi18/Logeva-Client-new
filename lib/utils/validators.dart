// ============================================================
// validators.dart
// Aturan pengecekan isian form (dipisah agar mudah dicari).
// ============================================================

import '../core/app_constants.dart';

class Validators {
  Validators._();

  // ---------------- LOGIN ----------------

  static String? usernameOrEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Username atau email wajib diisi.';
    if (v.contains('@') && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Format email tidak valid.';
    }
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password wajib diisi.';
    if (v.length < 6) return 'Password minimal 6 karakter.';
    return null;
  }

  static String? pin(String value) {
    if (value.length != AppConstants.pinLength) {
      return 'PIN harus ${AppConstants.pinLength} digit.';
    }
    return null;
  }

  // ---------------- FORM DATA ----------------

  /// Contoh pakai: validator: Validators.wajib('Nama')
  static String? Function(String?) wajib(String label) {
    return (value) {
      if ((value ?? '').trim().isEmpty) return '$label wajib diisi.';
      return null;
    };
  }

  static String? nikOptional(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (!RegExp(r'^\d{16}$').hasMatch(v)) return 'NIK harus 16 digit angka.';
    return null;
  }

  static String? usia(String? value) {
    final n = int.tryParse(value?.trim() ?? '');
    if (n == null) return 'Usia wajib diisi angka.';
    if (n < 0 || n > 120) return 'Usia tidak wajar (0–120).';
    return null;
  }

  // ---------------- AKUN ADMIN / RELAWAN ----------------

  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Username wajib diisi.';
    if (v.length < 3) return 'Username minimal 3 karakter.';
    if (!RegExp(r'^[a-zA-Z0-9_.]+$').hasMatch(v)) {
      return 'Username hanya boleh huruf, angka, titik, dan garis bawah.';
    }
    return null;
  }

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email wajib diisi.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)) {
      return 'Format email tidak valid.';
    }
    return null;
  }

  /// Password saat EDIT: boleh kosong (artinya tidak diganti).
  static String? passwordOptional(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return null;
    if (v.length < 6) return 'Password minimal 6 karakter.';
    return null;
  }

  /// Konfirmasi harus sama dengan [password] (dibaca saat validasi).
  static String? Function(String?) konfirmasiPassword(
    String Function() password,
  ) {
    return (value) {
      if ((value ?? '') != password()) return 'Konfirmasi password tidak sama.';
      return null;
    };
  }

  static String? jumlah(String? value) {
    final n = int.tryParse(value?.trim() ?? '');
    if (n == null) return 'Jumlah wajib diisi angka.';
    if (n <= 0) return 'Jumlah harus lebih dari 0.';
    return null;
  }
}
