// ============================================================
// main.dart
// Titik awal aplikasi LOGEVA Client.
// File ini HANYA mengatur tema & rute, tidak berisi tampilan.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'routes/app_routes.dart';
import 'services/kunci_otomatis.dart';
import 'services/perangkat_service.dart';
import 'services/peringatan_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Peran HP (Induk/Anggota) dibaca sekali saat aplikasi dibuka.
  await PerangkatService.muat();
  runApp(const LogevaApp());
  // Keluar otomatis setelah 10 menit tidak dipakai (data pribadi pengungsi).
  KunciOtomatis.instance.mulai();
  // Notifikasi lokal posko hampir/sudah penuh & stok < 7 hari (tanpa
  // internet). Setelah runApp supaya jendela izin bisa tampil.
  PeringatanService.mulai();
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
          // Bahasa Indonesia untuk widget bawaan (kalender, tombol dialog):
          // tanggal tampil & diketik sebagai hari/bulan/tahun.
          locale: const Locale('id', 'ID'),
          supportedLocales: const [Locale('id', 'ID')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          navigatorKey: KunciOtomatis.instance.navigatorKey,
          builder: (context, child) => KunciOtomatis.instance.bungkus(child!),
          initialRoute: AppRoutes.roleSelection,
          routes: AppRoutes.routes,
        );
      },
    );
  }
}
