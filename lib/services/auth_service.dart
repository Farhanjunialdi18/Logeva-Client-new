// ============================================================
// auth_service.dart
// LOGIKA login, membaca akun dari database (SQLite di Android).
//
// - Admin  : username/email + password (dicek dengan hash)
// - Relawan: PIN 6 digit yang dibuat admin
// ============================================================

import 'package:flutter/foundation.dart' show kDebugMode;

import '../data/repositories/admin_repository.dart';
import '../data/repositories/posko_repository.dart';
import '../data/repositories/relawan_repository.dart';
import '../models/relawan_session.dart';
import '../utils/password_hasher.dart';
import 'session_service.dart';

class AuthResult {
  final bool success;
  final String message;

  /// true = login berhasil tapi password masih bawaan: wajib diganti
  /// dulu sebelum masuk ke aplikasi.
  final bool wajibGantiPassword;

  const AuthResult({
    required this.success,
    required this.message,
    this.wajibGantiPassword = false,
  });
}

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  // ---- PIN DEMO ----
  // Hanya berlaku saat mode debug DAN belum ada satu pun relawan di database,
  // supaya halaman relawan tetap bisa dicoba sebelum admin membuat akun.
  // Di aplikasi rilis (release) PIN ini tidak berlaku.
  static const String demoRelawanPin = '123456';
  static const RelawanSession demoRelawan = RelawanSession(
    nama: 'Andi Saputra',
    posko: 'Desa Panggarangan',
  );

  /// Login admin pakai username ATAU email + password.
  Future<AuthResult> loginAdmin(String identifier, String password) async {
    // Pastikan akun admin pertama sudah ada (dibuat sekali saja).
    await AdminRepository.instance.ensureDefaultAdmin();

    final admin = await AdminRepository.instance.findByLogin(identifier);
    final cocok = admin != null &&
        PasswordHasher.verify(
          password,
          hash: admin.passwordHash,
          salt: admin.passwordSalt,
        );

    if (!cocok) {
      return const AuthResult(
        success: false,
        message: 'Username/email atau password salah.',
      );
    }

    if (!admin.isAktif) {
      return const AuthResult(
        success: false,
        message: 'Akun admin ini dinonaktifkan. Hubungi Super Admin.',
      );
    }

    SessionService.instance.startAdmin(admin);
    return AuthResult(
      success: true,
      message: 'Login berhasil.',
      wajibGantiPassword: AdminRepository.instance.masihPasswordBawaan(admin),
    );
  }

  /// Login relawan pakai PIN 6 digit dari admin.
  Future<AuthResult> loginRelawan(String pin) async {
    final relawan = await RelawanRepository.instance.findByPin(pin);

    if (relawan != null) {
      if (!relawan.isAktif) {
        return const AuthResult(
          success: false,
          message: 'Akun relawan dinonaktifkan. Hubungi admin.',
        );
      }
      if (!relawan.sudahDitempatkan) {
        return const AuthResult(
          success: false,
          message: 'Akun belum ditempatkan di posko. Hubungi admin.',
        );
      }
      await RelawanRepository.instance.markLogin(relawan);
      SessionService.instance.startRelawan(
        RelawanSession(
          nama: relawan.nama,
          poskoId: relawan.poskoId,
          posko: relawan.posko,
          kontak: relawan.kontak,
          relawanId: relawan.id,
        ),
      );
      return const AuthResult(success: true, message: 'PIN terverifikasi.');
    }

    // PIN demo (lihat penjelasan di atas).
    final belumAdaRelawan = await RelawanRepository.instance.count() == 0;
    if (kDebugMode && belumAdaRelawan && pin == demoRelawanPin) {
      // Pakai posko demo kalau ada di database, supaya data bisa dicatat.
      final posko = await PoskoRepository.instance.findByNama(demoRelawan.posko);
      SessionService.instance.startRelawan(RelawanSession(
        nama: demoRelawan.nama,
        poskoId: posko?.id,
        posko: demoRelawan.posko,
      ));
      return const AuthResult(success: true, message: 'PIN demo terverifikasi.');
    }

    return const AuthResult(
      success: false,
      message: 'PIN salah. Hubungi admin/koordinator posko.',
    );
  }
}
