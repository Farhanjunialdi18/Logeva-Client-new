// ============================================================
// app_routes.dart
// Daftar semua halaman (rute) aplikasi.
// ============================================================

import 'package:flutter/material.dart';

import '../screens/admin/admin_shell_screen.dart';
import '../screens/admin_login/admin_login_screen.dart';
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

  static Map<String, WidgetBuilder> get routes => {
        roleSelection: (_) => const RoleSelectionScreen(),
        adminLogin: (_) => const AdminLoginScreen(),
        relawanLogin: (_) => const RelawanLoginScreen(),
        adminDashboard: (_) => const AdminShellScreen(),
        relawanHome: (_) => const RelawanShellScreen(),
      };
}
