// ============================================================
// relawan_shell_screen.dart
// "Bingkai" halaman relawan: isi halaman + menu bawah.
// Mengatur perpindahan Beranda / Pengungsi / Logistik / Riwayat
// (di HP Anggota: Sinkron),
// dan memunculkan popup saat menu Logout ditekan.
// ============================================================

import 'package:flutter/material.dart';

import '../../services/perangkat_service.dart';
import '../../widgets/relawan_bottom_nav.dart';
import '../sinkron/sinkron_screen.dart';
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
  // Tab 1–3: Pengungsi, Logistik, Riwayat/Sinkron (dibuka lewat indeks).
  static const int _tabBeranda = 0;
  static const int _tabLogout = 4;

  int _index = _tabBeranda;

  void _goTo(int index) {
    if (index == _tabLogout) {
      LogoutDialog.show(context);
      return;
    }
    setState(() => _index = index);
  }

  void _backToBeranda() => _goTo(_tabBeranda);

  @override
  Widget build(BuildContext context) {
    final hpAnggota = PerangkatService.isAnggota;

    return PopScope(
      // Tombol back Android: kalau bukan di Beranda, kembali ke Beranda dulu
      canPop: _index == _tabBeranda,
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
            hpAnggota
                ? SinkronScreen(onBack: _backToBeranda)
                : RiwayatScreen(onBack: _backToBeranda),
          ],
        ),
        bottomNavigationBar: RelawanBottomNav(
          currentIndex: _index,
          onTap: _goTo,
          hpAnggota: hpAnggota,
        ),
      ),
    );
  }
}
