// ============================================================
// relawan_shell_screen.dart
// "Bingkai" halaman relawan: isi halaman + menu bawah.
// Mengatur perpindahan Beranda / Pengungsi / Logistik / Riwayat,
// dan memunculkan popup saat menu Logout ditekan.
// ============================================================

import 'package:flutter/material.dart';

import '../../widgets/relawan_bottom_nav.dart';
import 'beranda/beranda_screen.dart';
import 'logistik/logistik_screen.dart';
import 'logout/logout_dialog.dart';
import 'pengungsi/pengungsi_screen.dart';
import 'riwayat/riwayat_screen.dart';

class RelawanShellScreen extends StatefulWidget {
  const RelawanShellScreen({super.key});

  @override
  State<RelawanShellScreen> createState() => _RelawanShellScreenState();
}

class _RelawanShellScreenState extends State<RelawanShellScreen> {
  // Urutan tab (harus sama dengan urutan di RelawanBottomNav)
  static const int tabBeranda = 0;
  static const int tabPengungsi = 1;
  static const int tabLogistik = 2;
  static const int tabRiwayat = 3;
  static const int tabLogout = 4;

  int _index = tabBeranda;

  void _goTo(int index) {
    if (index == tabLogout) {
      LogoutDialog.show(context);
      return;
    }
    setState(() => _index = index);
  }

  void _backToBeranda() => _goTo(tabBeranda);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Tombol back Android: kalau bukan di Beranda, kembali ke Beranda dulu
      canPop: _index == tabBeranda,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _backToBeranda();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            BerandaScreen(onOpenMenu: _goTo),
            PengungsiScreen(onBack: _backToBeranda),
            LogistikScreen(onBack: _backToBeranda),
            RiwayatScreen(onBack: _backToBeranda),
          ],
        ),
        bottomNavigationBar: RelawanBottomNav(
          currentIndex: _index,
          onTap: _goTo,
        ),
      ),
    );
  }
}
