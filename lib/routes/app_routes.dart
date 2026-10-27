// ============================================================
// app_routes.dart
// Daftar semua halaman (rute) aplikasi.
// ============================================================

import 'package:flutter/material.dart';

import '../screens/admin/admin_shell_screen.dart';
import '../screens/admin_login/admin_login_screen.dart';
import '../screens/admin_login/ganti_password_wajib_screen.dart';
import '../screens/cadangan/cadangan_screen.dart';
import '../screens/penyiapan/terima_penyiapan_screen.dart';
import '../screens/relawan/relawan_shell_screen.dart';
import '../screens/relawan_login/relawan_login_screen.dart';
import '../screens/role_selection/role_selection_screen.dart';

class AppRoutes {
  AppRoutes._();

  static const String roleSelection = '/';
  static const String adminLogin = '/admin-login';
  static const String relawanLogin = '/relawan-login';
  static const String adminDashboard = '/admin-dashboard';
  static const String relawanHome = '/relawan-home';
  static const String gantiPasswordWajib = '/ganti-password-wajib';
  static const String terimaPenyiapan = '/terima-penyiapan';
  static const String pulihkanCadangan = '/pulihkan-cadangan';

  static Map<String, WidgetBuilder> get routes => {
        roleSelection: (_) => const RoleSelectionScreen(),
        adminLogin: (_) => const AdminLoginScreen(),
        relawanLogin: (_) => const RelawanLoginScreen(),
        adminDashboard: (_) => const AdminShellScreen(),
        relawanHome: (_) => const RelawanShellScreen(),
        gantiPasswordWajib: (_) => const GantiPasswordWajibScreen(),
        terimaPenyiapan: (_) => const TerimaPenyiapanScreen(),
        pulihkanCadangan: (_) => const CadanganScreen(dariLayarAwal: true),
      };
}
