// ============================================================
// admin_shell_screen.dart
// "Bingkai" halaman admin: isi halaman + menu bawah.
//
// Setiap tab punya Navigator sendiri, jadi halaman Detail / Tambah / Edit
// dibuka DI DALAM tab dan menu bawah tetap terlihat (sesuai desain Canva).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../widgets/admin_bottom_nav.dart';
import '../relawan/logout/logout_dialog.dart';
import 'beranda/admin_beranda_screen.dart';
import 'data/admin_data_menu_screen.dart';
import 'kelola_admin/kelola_admin_screen.dart';
import 'kelola_relawan/kelola_relawan_screen.dart';
import 'settings/admin_settings_screen.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({super.key});

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  // Urutan tab (harus sama dengan urutan di AdminBottomNav)
  static const int tabBeranda = 0;
  static const int tabAdmin = 1;
  static const int tabRelawan = 2;
  static const int tabData = 3;
  static const int tabSettings = 4;

  int _index = tabBeranda;

  /// Satu Navigator untuk setiap tab.
  final List<GlobalKey<NavigatorState>> _navKeys =
      List.generate(5, (_) => GlobalKey<NavigatorState>());

  void _goTo(int index) {
    if (index == _index) {
      // Ketuk tab yang sedang aktif -> kembali ke halaman awal tab itu.
      _navKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _index = index);
  }

  void _backToBeranda() => _goTo(tabBeranda);

  /// Dari Beranda: pindah ke tab Data lalu langsung buka halamannya.
  void _openDataPage(AdminDataPage page) {
    setState(() => _index = tabData);
    final nav = _navKeys[tabData].currentState;
    if (nav == null) return;
    nav.popUntil((route) => route.isFirst);
    nav.push(AdminDataMenuScreen.routeFor(page));
  }

  // Pakai context milik shell (bukan context di dalam tab),
  // supaya logout memakai Navigator utama aplikasi.
  void _logout() => LogoutDialog.show(context);

  /// Tombol back Android.
  void _handleBack() {
    final nav = _navKeys[_index].currentState;
    if (nav != null && nav.canPop()) {
      nav.pop(); // tutup halaman detail/form di tab ini
    } else if (_index != tabBeranda) {
      _backToBeranda();
    } else {
      SystemNavigator.pop(); // di Beranda: keluar aplikasi
    }
  }

  Widget _tab(int index, Widget halamanAwal) {
    return Navigator(
      key: _navKeys[index],
      onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => halamanAwal),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            _tab(
              tabBeranda,
              AdminBerandaScreen(
                onOpenTab: _goTo,
                onOpenDataPage: _openDataPage,
                onLogout: _logout,
              ),
            ),
            _tab(tabAdmin, KelolaAdminScreen(onBack: _backToBeranda)),
            _tab(tabRelawan, KelolaRelawanScreen(onBack: _backToBeranda)),
            _tab(tabData, AdminDataMenuScreen(onBack: _backToBeranda)),
            _tab(
              tabSettings,
              AdminSettingsScreen(onBack: _backToBeranda, onLogout: _logout),
            ),
          ],
        ),
        bottomNavigationBar: AdminBottomNav(
          currentIndex: _index,
          onTap: _goTo,
        ),
      ),
    );
  }
}
