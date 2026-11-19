// ============================================================
// app_constants.dart
// Nilai tetap yang dipakai di banyak tempat.
// ============================================================

class AppConstants {
  AppConstants._();

  static const String appName = 'LOGEVA Client';
  static const String appVersion = '1.0.15'; // samakan dengan pubspec.yaml
  static const String appTagline =
      'Sistem Informasi Geografis Manajemen TEA dan Logistik';
  static const String organization = 'Gugus Mitigasi Lebak Selatan';

  /// Path logo. Ganti file ini dengan logo GMLS asli.
  // Logo LOGEVA "golden hour" (sama dengan ikon aplikasi).
  static const String logoPath = 'assets/images/logo_logeva1.png';

  /// Panjang PIN relawan.
  static const int pinLength = 6;
}
