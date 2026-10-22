// ============================================================
// admin_data_menu_screen.dart
// HALAMAN DATA (tab "Data"): menu Data Pengungsi, Data Logistik,
// dan Riwayat Transaksi.
// ============================================================

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/menu_card.dart';
import '../../../widgets/page_header.dart';
import '../../relawan/riwayat/riwayat_screen.dart';
import 'admin_logistik_screen.dart';
import 'admin_pengungsi_screen.dart';

/// Halaman-halaman di dalam tab Data.
enum AdminDataPage { pengungsi, logistik, riwayat }

class AdminDataMenuScreen extends StatelessWidget {
  final VoidCallback onBack;

  const AdminDataMenuScreen({super.key, required this.onBack});

  /// Rute untuk membuka satu halaman Data (dipakai juga dari Beranda).
  static Route<void> routeFor(AdminDataPage page) {
    return MaterialPageRoute(
      builder: (context) => switch (page) {
        AdminDataPage.pengungsi => const AdminPengungsiScreen(),
        AdminDataPage.logistik => const AdminLogistikScreen(),
        AdminDataPage.riwayat => RiwayatScreen(
            onBack: () => Navigator.of(context).pop(),
          ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    void buka(AdminDataPage page) => Navigator.of(context).push(routeFor(page));

    return AppBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(title: 'Data', onBack: onBack),
          const SizedBox(height: 16),
          MenuCard(
            icon: Icons.groups_rounded,
            iconColor: AppColors.accentPurple,
            title: 'DATA PENGUNGSI',
            description: 'Kelola dan lihat seluruh data pengungsi',
            onTap: () => buka(AdminDataPage.pengungsi),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.inventory_2_rounded,
            iconColor: AppColors.accentAmber,
            title: 'DATA LOGISTIK',
            description: 'Kelola dan lihat seluruh data logistik',
            onTap: () => buka(AdminDataPage.logistik),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.history_rounded,
            iconColor: AppColors.accentBlue,
            title: 'RIWAYAT TRANSAKSI',
            description: 'Lihat seluruh aktivitas import dan export',
            onTap: () => buka(AdminDataPage.riwayat),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
