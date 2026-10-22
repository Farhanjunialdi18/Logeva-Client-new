// ============================================================
// beranda_screen.dart
// HALAMAN BERANDA RELAWAN:
// sapaan, info posko, ringkasan data, dan menu utama.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../data/data_events.dart';
import '../../../data/repositories/logistik_repository.dart';
import '../../../data/repositories/pengungsi_repository.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/menu_card.dart';
import '../../../widgets/offline_badge.dart';
import '../../../widgets/stat_card.dart';
import '../../../widgets/theme_toggle_button.dart';

class BerandaScreen extends StatefulWidget {
  /// Dipanggil saat kartu menu diketuk (1=Pengungsi, 2=Logistik, 3=Riwayat).
  final ValueChanged<int> onOpenMenu;

  const BerandaScreen({super.key, required this.onOpenMenu});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  int? _jumlahPengungsi;
  int? _jumlahLogistik;

  @override
  void initState() {
    super.initState();
    _load();
    DataEvents.instance.addListener(_load);
  }

  @override
  void dispose() {
    DataEvents.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final pengungsi = await PengungsiRepository.instance.count();
    final logistik = await LogistikRepository.instance.count();
    if (!mounted) return;
    setState(() {
      _jumlahPengungsi = pengungsi;
      _jumlahLogistik = logistik;
    });
  }

  String _angka(int? n, String satuan) => n == null ? '...' : '$n $satuan';

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final session = SessionService.instance;

    return AppBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Logo kecil + nama aplikasi + tombol tema ----
          Row(
            children: [
              const AppLogo(size: 38, glow: false),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const ThemeToggleButton(),
            ],
          ),
          const SizedBox(height: 24),

          // ---- Sapaan ----
          Text('Selamat datang,', style: AppTextStyles.body(p)),
          const SizedBox(height: 2),
          Text(
            session.namaRelawan,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text('Relawan', style: AppTextStyles.small(p)),
          Text(session.poskoLabel, style: AppTextStyles.small(p)),
          const SizedBox(height: 12),
          const OfflineBadge(),
          const SizedBox(height: 8),
          Text('Data tersimpan di perangkat', style: AppTextStyles.small(p)),
          const SizedBox(height: 24),

          // ---- Ringkasan data ----
          Text('RINGKASAN DATA POSKO', style: AppTextStyles.label(p)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.groups_rounded,
                  iconColor: AppColors.accentPurple,
                  label: 'Pengungsi',
                  value: _angka(_jumlahPengungsi, 'Orang'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.inventory_2_rounded,
                  iconColor: AppColors.accentAmber,
                  label: 'Data Logistik',
                  value: _angka(_jumlahLogistik, 'Data'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---- Menu ----
          MenuCard(
            icon: Icons.groups_rounded,
            iconColor: AppColors.accentPurple,
            title: 'DATA PENGUNGSI',
            description: 'Catat dan kelola data pengungsi',
            onTap: () => widget.onOpenMenu(1),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.inventory_2_rounded,
            iconColor: AppColors.accentAmber,
            title: 'DATA LOGISTIK',
            description: 'Catat dan kelola data logistik',
            onTap: () => widget.onOpenMenu(2),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.history_rounded,
            iconColor: AppColors.accentBlue,
            title: 'RIWAYAT TRANSAKSI',
            description: 'Lihat riwayat import dan export data',
            onTap: () => widget.onOpenMenu(3),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
