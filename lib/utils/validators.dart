// ============================================================
// validators.dart
// Aturan pengecekan isian form (dipisah agar mudah dicari).
// ============================================================

import '../core/app_constants.dart';
import '../data/repositories/admin_repository.dart';
import '../models/posko.dart';
import 'angka.dart';
import 'tanggal.dart';
import 'waktu_wib.dart';

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

  // ---------------- PENGUNGSI (aturan sama dengan website) ----------------

  /// Tanggal lahir wajib, tidak boleh setelah hari ini, tahun >= 1900.
  static String? tanggalLahir(DateTime? value) {
    if (value == null) return 'Tanggal lahir wajib diisi.';
    if (value.isAfter(WaktuWib.hariIni()) || value.year < 1900) {
      return 'Tanggal lahir tidak masuk akal (${Tanggal.tampil(value)}).';
    }
    return null;
  }

  /// Nomor KK tanpa spasi, titik, tanda hubung, dan petik.
  static String bersihkanKk(String? value) =>
      (value ?? '').replaceAll(RegExp(r"[\s'.\-]"), '');

  /// Nomor KK boleh kosong (dokumen bisa hilang saat bencana),
  /// tapi kalau diisi harus 16 digit angka.
  static String? nomorKkOptional(String? value) {
    final kk = bersihkanKk(value);
    if (kk.isEmpty) return null;
    if (!RegExp(r'^\d{16}$').hasMatch(kk)) {
      return 'Nomor KK harus 16 digit angka.';
    }
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

  /// Password BARU (aturan sama dengan website): minimal 8 karakter,
  /// berisi huruf dan angka. Password bawaan tidak boleh dipakai lagi.
  /// Login tetap memakai [password] supaya password lama masih bisa masuk.
  static String? passwordBaru(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Password wajib diisi.';
    if (v.length < 8) return 'Password minimal 8 karakter.';
    if (!RegExp(r'[A-Za-z]').hasMatch(v) || !RegExp(r'\d').hasMatch(v)) {
      return 'Password harus berisi huruf dan angka.';
    }
    if (v == AdminRepository.defaultPassword) {
      return 'Jangan memakai password bawaan.';
    }
    return null;
  }

  /// Password saat EDIT akun: boleh kosong (artinya tidak diganti).
  static String? passwordBaruOptional(String? value) =>
      (value ?? '').isEmpty ? null : passwordBaru(value);

  /// Konfirmasi harus sama dengan [password] (dibaca saat validasi).
  static String? Function(String?) konfirmasiPassword(
    String Function() password,
  ) {
    return (value) {
      if ((value ?? '') != password()) return 'Konfirmasi password tidak sama.';
      return null;
    };
  }

  // ---------------- POSKO ----------------
  // Batas wilayah Indonesia sama dengan website (LokasiImportController).

  static const double _latMin = -11.5, _latMax = 6.5;
  static const double _lngMin = 94.5, _lngMax = 141.5;

  /// Luas wajib, angka > 0, dan cukup besar untuk minimal 1 orang.
  static String? luasLokasi(String? value) {
    if ((value ?? '').trim().isEmpty) return 'Luas lokasi wajib diisi.';
    final luas = Angka.baca(value);
    if (luas == null) return 'Luas harus berupa angka, contoh: 1050.';
    if (luas <= 0) return 'Luas harus lebih dari 0.';
    if (Posko.hitungKapasitas(luas) == 0) {
      return 'Luas terlalu kecil (kapasitas 0 orang).';
    }
    return null;
  }

  /// Latitude boleh kosong dulu (wajib sebelum ekspor paket).
  static String? latitude(String? value) => _koordinat(
        value,
        min: _latMin,
        max: _latMax,
        pesan: 'Latitude di luar wilayah Indonesia '
            '(mungkin tertukar dengan longitude).',
      );

  static String? longitude(String? value) => _koordinat(
        value,
        min: _lngMin,
        max: _lngMax,
        pesan: 'Longitude di luar wilayah Indonesia '
            '(mungkin tertukar dengan latitude).',
      );

  static String? _koordinat(
    String? value, {
    required double min,
    required double max,
    required String pesan,
  }) {
    if ((value ?? '').trim().isEmpty) return null;
    final n = Angka.bacaKoordinat(value);
    if (n == null) return 'Harus berupa angka desimal, contoh: -6.9195.';
    if (n < min || n > max) return pesan;
    return null;
  }

  static String? jumlah(String? value) {
    final n = int.tryParse(value?.trim() ?? '');
    if (n == null) return 'Jumlah wajib diisi angka.';
    if (n <= 0) return 'Jumlah harus lebih dari 0.';
    return null;
  }
}
