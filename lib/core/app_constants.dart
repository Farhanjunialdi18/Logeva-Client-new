// ============================================================
// app_constants.dart
// Nilai tetap yang dipakai di banyak tempat.
// ============================================================

class AppConstants {
  AppConstants._();

  static const String appName = 'LOGEVA Client';
  static const String appVersion = '1.0.0'; // samakan dengan pubspec.yaml
  static const String appTagline = 'Sistem Pendataan Kebencanaan';
  static const String organization = 'Gugus Mitigasi Lebak Selatan';

  /// Path logo. Ganti file ini dengan logo GMLS asli.
  static const String logoPath = 'assets/images/logo_gmls.png';

  /// Panjang PIN relawan.
  static const int pinLength = 6;
}
