// ============================================================
// admin_data_menu_screen.dart
// HALAMAN DATA (tab "Data"): menu Data Posko, Data Pengungsi,
// Data Logistik, Master Barang, Paket Data Posko, dan Riwayat Transaksi.
// ============================================================

import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/menu_card.dart';
import '../../../widgets/page_header.dart';
import '../../relawan/riwayat/riwayat_screen.dart';
import '../barang/master_barang_screen.dart';
import '../paket/paket_data_screen.dart';
import '../../sinkron/sinkron_screen.dart';
import '../posko/kelola_posko_screen.dart';
import 'admin_logistik_screen.dart';
import 'admin_pengungsi_screen.dart';

/// Halaman-halaman di dalam tab Data.
enum AdminDataPage { posko, pengungsi, logistik, barang, sinkron, paket, riwayat }

class AdminDataMenuScreen extends StatelessWidget {
  final VoidCallback onBack;

  const AdminDataMenuScreen({super.key, required this.onBack});

  /// Rute untuk membuka satu halaman Data (dipakai juga dari Beranda).
  static Route<void> routeFor(AdminDataPage page) {
    return MaterialPageRoute(
      builder: (context) => switch (page) {
        AdminDataPage.posko => const KelolaPoskoScreen(),
        AdminDataPage.pengungsi => const AdminPengungsiScreen(),
        AdminDataPage.logistik => const AdminLogistikScreen(),
        AdminDataPage.barang => const MasterBarangScreen(),
        AdminDataPage.sinkron => const SinkronScreen(),
        AdminDataPage.paket => const PaketDataScreen(),
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
            icon: Icons.home_work_rounded,
            iconColor: AppColors.primary,
            title: 'DATA POSKO',
            description: 'Kelola posko, kapasitas, dan status operasional',
            onTap: () => buka(AdminDataPage.posko),
          ),
          const SizedBox(height: 12),
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
            description: 'Stok, barang masuk & keluar per posko',
            onTap: () => buka(AdminDataPage.logistik),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.category_rounded,
            iconColor: AppColors.accentAmber,
            title: 'MASTER BARANG',
            description: 'Daftar barang & kebutuhan per orang per hari',
            onTap: () => buka(AdminDataPage.barang),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.sync_alt_rounded,
            iconColor: AppColors.accentBlue,
            title: 'SINKRON ANTAR-HP',
            description: 'Tukar data dengan HP lain di posko ini (Bluetooth)',
            onTap: () => buka(AdminDataPage.sinkron),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.archive_rounded,
            iconColor: AppColors.success,
            title: 'EKSPOR PAKET DATA POSKO',
            description: 'File ZIP untuk dibawa ke pusat lewat USB',
            onTap: () => buka(AdminDataPage.paket),
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
