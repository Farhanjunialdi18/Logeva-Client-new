// ============================================================
// role_selection_screen.dart
// HALAMAN AWAL: pilih masuk sebagai ADMIN atau RELAWAN. Tautan "HP baru /
// pindah posko?" berisi: buka file dari HP admin (HP relawan) dan pulihkan
// HP pengganti dari cadangan (HP admin yang rusak/hilang).
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
                    // Dua jalan untuk HP baru dirapikan jadi satu tautan.
                    TextButton.icon(
                      onPressed: () => _bantuanHp(context, anggota),
                      icon: const Icon(Icons.install_mobile_rounded,
                          size: 18, color: AppColors.primary),
                      label: const Text(
                        'HP baru / pindah posko?',
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

  void _bantuanHp(BuildContext context, bool anggota) {
    final p = AppPalette.of(context);
    Widget pilihan(IconData ikon, String judul, String ket, String rute) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(ikon, color: AppColors.primary),
          title: Text(judul, style: AppTextStyles.cardTitle(p)),
          subtitle: Text(ket, style: AppTextStyles.small(p)),
          trailing: Icon(Icons.chevron_right_rounded, color: p.textSecondary),
          onTap: () {
            Navigator.of(context).pop();
            Navigator.pushNamed(context, rute);
          },
        );
    showModalBottomSheet<void>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HP baru / pindah posko', style: AppTextStyles.sectionTitle(p)),
              const SizedBox(height: 4),
              Text(
                'Cara utama: ketuk file yang diterima → Buka dengan LOGEVA. '
                'Pakai pilihan ini kalau cara itu tidak bisa.',
                style: AppTextStyles.small(p),
              ),
              const SizedBox(height: 8),
              pilihan(Icons.folder_zip_rounded, 'Buka file dari HP admin',
                  'HP relawan: pasang akun & data posko dari file kiriman admin',
                  AppRoutes.terimaPenyiapan),
              if (!anggota)
                pilihan(Icons.restore_rounded, 'Pulihkan HP pengganti',
                    'HP admin rusak/hilang: pulihkan semua data dari file cadangan',
                    AppRoutes.pulihkanCadangan),
            ],
          ),
        ),
      ),
    );
  }
}
