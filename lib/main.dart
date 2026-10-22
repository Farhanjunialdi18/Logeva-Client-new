// ============================================================
// main.dart
// Titik awal aplikasi LOGEVA Client.
// File ini HANYA mengatur tema & rute, tidak berisi tampilan.
// ============================================================

import 'package:flutter/material.dart';

import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() {
  runApp(const LogevaApp());
}

class LogevaApp extends StatelessWidget {
  const LogevaApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Mendengarkan perubahan mode tema (gelap/terang)
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance.mode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'LOGEVA Client',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          initialRoute: AppRoutes.roleSelection,
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
