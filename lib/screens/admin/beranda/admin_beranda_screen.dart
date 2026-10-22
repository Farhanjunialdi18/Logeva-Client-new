// ============================================================
// admin_beranda_screen.dart
// HALAMAN BERANDA ADMIN (sesuai desain Canva):
// sapaan, ringkasan data, aksi cepat, aktivitas terbaru,
// menu Data & Settings, dan tombol Logout.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../data/data_events.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/logistik_repository.dart';
import '../../../data/repositories/pengungsi_repository.dart';
import '../../../data/repositories/relawan_repository.dart';
import '../../../services/aktivitas_service.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/activity_timeline.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/logout_button.dart';
import '../../../widgets/menu_card.dart';
import '../../../widgets/offline_badge.dart';
import '../../../widgets/square_icon_button.dart';
import '../../../widgets/stat_card.dart';
import '../../../widgets/theme_toggle_button.dart';
import '../data/admin_data_menu_screen.dart';

class AdminBerandaScreen extends StatefulWidget {
  /// Pindah tab (1=Admin, 2=Relawan, 3=Data, 4=Settings).
  final ValueChanged<int> onOpenTab;

  /// Buka halaman di dalam tab Data (Pengungsi / Logistik / Riwayat).
  final ValueChanged<AdminDataPage> onOpenDataPage;

  /// Tombol Logout ditekan.
  final VoidCallback onLogout;

  const AdminBerandaScreen({
    super.key,
    required this.onOpenTab,
    required this.onOpenDataPage,
    required this.onLogout,
  });

  @override
  State<AdminBerandaScreen> createState() => _AdminBerandaScreenState();
}

class _AdminBerandaScreenState extends State<AdminBerandaScreen> {
  // Nomor tab (harus sama dengan AdminShellScreen)
  static const int _tabAdmin = 1;
  static const int _tabRelawan = 2;
  static const int _tabData = 3;
  static const int _tabSettings = 4;

  int? _jumlahPengungsi;
  int? _jumlahLogistik;
  int? _jumlahRelawan;
  int? _jumlahAdmin;
  List<Aktivitas> _aktivitas = [];

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
    final relawan = await RelawanRepository.instance.count();
    final admin = await AdminRepository.instance.count();
    final aktivitas = await AktivitasService.terbaru(limit: 5);
    if (!mounted) return;
    setState(() {
      _jumlahPengungsi = pengungsi;
      _jumlahLogistik = logistik;
      _jumlahRelawan = relawan;
      _jumlahAdmin = admin;
      _aktivitas = aktivitas;
    });
  }

  String _angka(int? n, String satuan) => n == null ? '...' : '$n $satuan';

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return AppBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Logo + nama aplikasi + tombol tema & profil ----
          Row(
            children: [
              const AppLogo(size: 44, glow: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppConstants.appName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('Dashboard Admin', style: AppTextStyles.small(p)),
                  ],
                ),
              ),
              const ThemeToggleButton(),
              const SizedBox(width: 10),
              SquareIconButton(
                icon: Icons.person_rounded,
                iconColor: AppColors.accentPurple,
                tooltip: 'Profil & pengaturan',
                onPressed: () => widget.onOpenTab(_tabSettings),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ---- Sapaan ----
          Text('Selamat datang,', style: AppTextStyles.body(p)),
          const SizedBox(height: 4),
          Text(
            SessionService.instance.namaAdmin,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Kelola data dan pengguna ${AppConstants.appName}.',
            style: AppTextStyles.body(p),
          ),
          const SizedBox(height: 12),
          const OfflineBadge(),
          const SizedBox(height: 8),
          Text('Data tersimpan di perangkat', style: AppTextStyles.small(p)),
          const SizedBox(height: 24),

          // ---- Ringkasan data (2 x 2) ----
          Text('RINGKASAN DATA', style: AppTextStyles.label(p)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.groups_rounded,
                  iconColor: AppColors.accentPurple,
                  label: 'TOTAL PENGUNGSI',
                  value: _angka(_jumlahPengungsi, 'Orang'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.inventory_2_rounded,
                  iconColor: AppColors.accentAmber,
                  label: 'DATA LOGISTIK',
                  value: _angka(_jumlahLogistik, 'Item'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.volunteer_activism_rounded,
                  iconColor: AppColors.primary,
                  label: 'TOTAL RELAWAN',
                  value: _angka(_jumlahRelawan, 'Relawan'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.manage_accounts_rounded,
                  iconColor: AppColors.accentPurple,
                  label: 'TOTAL ADMIN',
                  value: _angka(_jumlahAdmin, 'Admin'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ---- Aksi cepat ----
          Text('AKSI CEPAT', style: AppTextStyles.label(p)),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.manage_accounts_rounded,
            iconColor: AppColors.accentPurple,
            title: 'KELOLA ADMIN',
            description: 'Kelola akun administrator',
            onTap: () => widget.onOpenTab(_tabAdmin),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.volunteer_activism_rounded,
            iconColor: AppColors.primary,
            title: 'KELOLA RELAWAN',
            description: 'Kelola akun dan akses relawan',
            onTap: () => widget.onOpenTab(_tabRelawan),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.groups_rounded,
            iconColor: AppColors.accentPurple,
            title: 'DATA PENGUNGSI',
            description: 'Melihat data pengungsi',
            onTap: () => widget.onOpenDataPage(AdminDataPage.pengungsi),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.inventory_2_rounded,
            iconColor: AppColors.accentAmber,
            title: 'DATA LOGISTIK',
            description: 'Melihat data logistik',
            onTap: () => widget.onOpenDataPage(AdminDataPage.logistik),
          ),
          const SizedBox(height: 24),

          // ---- Aktivitas terbaru ----
          Text('AKTIVITAS TERBARU', style: AppTextStyles.label(p)),
          const SizedBox(height: 16),
          ActivityTimeline(items: _aktivitas),
          const SizedBox(height: 24),

          // ---- Menu lain ----
          MenuCard(
            icon: Icons.bar_chart_rounded,
            iconColor: AppColors.accentBlue,
            title: 'DATA',
            description: 'Pengungsi, logistik, import & export',
            onTap: () => widget.onOpenTab(_tabData),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.settings_rounded,
            iconColor: p.textSecondary,
            title: 'SETTINGS',
            description: 'Pengaturan aplikasi',
            onTap: () => widget.onOpenTab(_tabSettings),
          ),
          const SizedBox(height: 20),

          LogoutButton(onPressed: widget.onLogout),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
