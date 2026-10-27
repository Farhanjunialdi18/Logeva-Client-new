// ============================================================
// kunci_otomatis.dart
// KUNCI OTOMATIS: kalau aplikasi tidak disentuh selama [batas] (atau
// ditinggal di latar belakang selama itu), pengguna dikeluarkan dan
// kembali ke layar awal. Data pribadi pengungsi tidak terbuka saat HP
// posko tergeletak / dipinjam orang lain.
// Hanya berlaku saat ada yang login (admin atau relawan).
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../routes/app_routes.dart';
import 'session_service.dart';

class KunciOtomatis with WidgetsBindingObserver {
  KunciOtomatis._();
  static final KunciOtomatis instance = KunciOtomatis._();

  static const Duration batas = Duration(minutes: 10);

  /// Navigator aplikasi (dipasang di MaterialApp.navigatorKey).
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Untuk tes: jam pengganti.
  DateTime Function() jam = DateTime.now;

  DateTime _terakhir = DateTime.now();
  bool _aktif = false;

  bool get _adaYangLogin =>
      SessionService.instance.admin != null || SessionService.instance.relawan != null;

  void mulai() {
    if (_aktif) return;
    _aktif = true;
    WidgetsBinding.instance.addObserver(this);
    _terakhir = jam();
    Timer.periodic(const Duration(seconds: 30), (_) => periksa());
  }

  /// Dipanggil setiap layar disentuh.
  void sentuh() => _terakhir = jam();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali dari latar belakang: hitung waktu selama ditinggal.
    if (state == AppLifecycleState.resumed) periksa();
  }

  /// Keluarkan pengguna kalau sudah melewati batas. Hasil: true = dikunci.
  bool periksa() {
    if (!_adaYangLogin) {
      _terakhir = jam();
      return false;
    }
    if (jam().difference(_terakhir) < batas) return false;

    SessionService.instance.clear();
    _terakhir = jam();
    final nav = navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
      final ctx = navigatorKey.currentContext;
      if (ctx != null) {
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(SnackBar(
          content: Text('Aplikasi dikunci karena tidak dipakai '
              '${batas.inMinutes} menit. Silakan login lagi.'),
        ));
      }
    }
    return true;
  }

  /// Pembungkus untuk MaterialApp.builder: setiap sentuhan = masih dipakai.
  Widget bungkus(Widget child) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => sentuh(),
        child: child,
      );
}
