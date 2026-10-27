// ============================================================
// tentang_screen.dart
// HALAMAN TENTANG LOGEVA (About Us) — dipakai Admin & Relawan.
// ============================================================

import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../core/tim_pengembang.dart';
import '../../data/database_tables.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_logo.dart';
import '../../widgets/info_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/team_member_card.dart';

class TentangScreen extends StatelessWidget {
  const TentangScreen({super.key});

  static const String _deskripsi =
      '${AppConstants.appName} adalah aplikasi Android pendamping Logeva Web '
      'untuk membantu relawan mencatat data pengungsi dan logistik di posko '
      'pengungsian, meskipun tanpa koneksi internet. Data disimpan di '
      'perangkat dan dapat dipindahkan ke Logeva Web.';

  Widget _judulBagian(String teks, AppPalette p) => Center(
        child: Text(
          teks,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: p.textPrimary,
          ),
        ),
      );

  /// Kartu tim 2 kolom; kartu ke-5 otomatis di tengah.
  Widget _gridTim() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const jarak = 12.0;
        final lebarKartu = (constraints.maxWidth - jarak) / 2;
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: jarak,
          runSpacing: jarak,
          children: [
            for (final a in TimPengembang.anggota)
              TeamMemberCard(anggota: a, width: lebarKartu),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Tentang LOGEVA',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 24),

            // Logo + nama + versi
            const Center(child: AppLogo(size: 84)),
            const SizedBox(height: 14),
            Center(
              child: Text(AppConstants.appName,
                  style: AppTextStyles.appTitle(p)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text('Versi ${AppConstants.appVersion}',
                  style: AppTextStyles.small(p)),
            ),
            const SizedBox(height: 28),

            // Tentang Sistem
            _judulBagian('Tentang Sistem', p),
            const SizedBox(height: 10),
            Text(
              _deskripsi,
              textAlign: TextAlign.center,
              style: AppTextStyles.body(p).copyWith(height: 1.5),
            ),
            const SizedBox(height: 28),

            // Tim Pengembang
            _judulBagian(TimPengembang.judul, p),
            const SizedBox(height: 14),
            _gridTim(),
            const SizedBox(height: 28),

            // Informasi Sistem
            InfoCard(
              title: 'INFORMASI SISTEM',
              rows: {
                'Aplikasi': AppConstants.appName,
                'Versi': AppConstants.appVersion,
                'Organisasi': AppConstants.organization,
                'Penyimpanan': 'SQLite (offline)',
                'Versi database': '${DatabaseTables.version}',
              },
            ),
            const SizedBox(height: 20),

            // Hak cipta
            Divider(color: p.border),
            const SizedBox(height: 10),
            Center(
              child: Text(
                '© ${DateTime.now().year} GMLS. All Rights Reserved.',
                style: AppTextStyles.small(p),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}