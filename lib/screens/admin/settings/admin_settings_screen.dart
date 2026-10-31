// ============================================================
// admin_settings_screen.dart
// HALAMAN SETTINGS (tab "Settings"):
// Akun, Appearance, Data, Aplikasi, dan tombol Logout Admin.
// ============================================================

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/theme_controller.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/logout_button.dart';
import '../../../widgets/menu_card.dart';
import '../../../widgets/page_header.dart';
import '../../cadangan/cadangan_screen.dart';
import 'kata_sandi_posko_screen.dart';
import 'keamanan_screen.dart';
import 'pengaturan_data_screen.dart';
import 'penyimpanan_screen.dart';
import 'profil_admin_screen.dart';
import '../../tentang/tentang_screen.dart';

class AdminSettingsScreen extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onLogout;

  const AdminSettingsScreen({
    super.key,
    required this.onBack,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    void buka(Widget halaman) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => halaman));
    }

    Widget judul(String text) => Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 12),
          child: Text(text, style: AppTextStyles.label(p)),
        );

    return AppBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: 'Settings', onBack: onBack),

          // ---- AKUN ----
          judul('AKUN'),
          MenuCard(
            icon: Icons.person_rounded,
            iconColor: AppColors.accentPurple,
            title: 'Profil Admin',
            description: 'Kelola informasi akun',
            onTap: () => buka(const ProfilAdminScreen()),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.lock_rounded,
            iconColor: AppColors.accentAmber,
            title: 'Keamanan',
            description: 'Password dan keamanan akun',
            onTap: () => buka(const KeamananScreen()),
          ),

          // ---- APPEARANCE ----
          judul('APPEARANCE'),
          // Ketuk kartu langsung mengganti mode gelap/terang.
          ValueListenableBuilder<ThemeMode>(
            valueListenable: ThemeController.instance.mode,
            builder: (context, mode, _) {
              final gelap = mode == ThemeMode.dark;
              return MenuCard(
                icon: gelap ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                iconColor: AppColors.sun,
                title: 'Dark Mode / Light Mode',
                description: gelap
                    ? 'Mode gelap aktif · ketuk untuk mode terang'
                    : 'Mode terang aktif · ketuk untuk mode gelap',
                onTap: ThemeController.instance.toggle,
              );
            },
          ),

          // ---- DATA ----
          judul('DATA'),
          MenuCard(
            icon: Icons.bar_chart_rounded,
            iconColor: AppColors.accentBlue,
            title: 'Pengaturan Data',
            description: 'Pengaturan import dan export',
            onTap: () => buka(const PengaturanDataScreen()),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.save_rounded,
            iconColor: AppColors.accentBlue,
            title: 'Penyimpanan',
            description: 'Informasi penyimpanan lokal',
            onTap: () => buka(const PenyimpananScreen()),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.lock_rounded,
            iconColor: AppColors.accentAmber,
            title: 'Kata Sandi Posko',
            description: 'Mengunci paket ke pusat & file cadangan',
            onTap: () => buka(const KataSandiPoskoScreen()),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.backup_rounded,
            iconColor: AppColors.success,
            title: 'Cadangan & Pemulihan',
            description: 'Cadangkan semua data, pulihkan di HP pengganti',
            onTap: () => buka(const CadanganScreen()),
          ),

          // ---- APLIKASI ----
          judul('APLIKASI'),
          MenuCard(
            icon: Icons.info_rounded,
            iconColor: AppColors.accentBlue,
            title: 'Tentang LOGEVA',
            description: 'Tentang sistem, tim pengembang, dan versi',
            onTap: () => buka(const TentangScreen()),
          ),
          const SizedBox(height: 24),

          LogoutButton(text: 'Logout Admin', onPressed: onLogout),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
