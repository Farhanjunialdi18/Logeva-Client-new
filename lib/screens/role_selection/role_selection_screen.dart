// ============================================================
// role_selection_screen.dart
// HALAMAN AWAL: pilih masuk sebagai ADMIN atau RELAWAN, atau siapkan
// HP ini sebagai HP Anggota dari File Penyiapan HP Induk.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../routes/app_routes.dart';
import '../../services/perangkat_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_background.dart';
import '../../widgets/logo_header.dart';
import '../../widgets/role_card.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      body: AppBackground(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(height: 48),

            // ---- Logo & judul ----
            Column(
              children: [
                const LogoHeader(
                  size: 72,
                  subtitles: [
                    AppConstants.appTagline,
                    AppConstants.organization,
                  ],
                ),
                const SizedBox(height: 44),

                // ---- Kartu pilihan peran ----
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.border),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      Text('Masuk sebagai', style: AppTextStyles.sectionTitle(p)),
                      const SizedBox(height: 18),
                      RoleCard(
                        icon: Icons.admin_panel_settings_outlined,
                        title: 'ADMIN',
                        description: 'Kelola data dan pengguna',
                        onTap: () =>
                            Navigator.pushNamed(context, AppRoutes.adminLogin),
                      ),
                      const SizedBox(height: 12),
                      RoleCard(
                        icon: Icons.volunteer_activism_outlined,
                        title: 'RELAWAN',
                        description: 'Akses pelaporan lapangan',
                        onTap: () => Navigator.pushNamed(
                            context, AppRoutes.relawanLogin),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ---- Catatan bawah + penyiapan HP Anggota ----
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: ValueListenableBuilder<bool>(
                valueListenable: PerangkatService.anggota,
                builder: (context, anggota, _) => Column(
                  children: [
                    Text(
                      anggota
                          ? 'HP Anggota · login dengan akun dari HP Induk'
                          : 'Gunakan akun sesuai dengan peran Anda',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.small(p),
                    ),
                    if (!anggota)
                      TextButton.icon(
                        onPressed: () => Navigator.pushNamed(
                            context, AppRoutes.terimaPenyiapan),
                        icon: const Icon(Icons.install_mobile_rounded,
                            size: 18, color: AppColors.primary),
                        label: const Text(
                          'Siapkan HP ini dari HP Induk',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
