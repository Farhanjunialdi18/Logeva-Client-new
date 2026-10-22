// ============================================================
// tentang_screen.dart
// TENTANG LOGEVA: versi aplikasi dan informasi sistem.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../data/database_tables.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/page_header.dart';

class TentangScreen extends StatelessWidget {
  const TentangScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Tentang LOGEVA',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 24),

            const Center(child: AppLogo(size: 84)),
            const SizedBox(height: 16),
            Center(
              child: Text(AppConstants.appName, style: AppTextStyles.appTitle(p)),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Versi ${AppConstants.appVersion}',
                style: AppTextStyles.small(p),
              ),
            ),
            const SizedBox(height: 20),

            Text(
              '${AppConstants.appName} adalah aplikasi Android untuk membantu '
              'relawan mencatat data pengungsi dan logistik di posko '
              'pengungsian, meskipun tanpa koneksi internet. Data disimpan di '
              'perangkat dan dapat dipindahkan ke Logeva Web melalui file CSV.',
              style: AppTextStyles.body(p),
            ),
            const SizedBox(height: 16),

            InfoCard(
              title: 'INFORMASI SISTEM',
              rows: {
                'Aplikasi': AppConstants.appName,
                'Versi': AppConstants.appVersion,
                'Sistem': AppConstants.appTagline,
                'Organisasi': AppConstants.organization,
                'Penyimpanan': 'SQLite (offline)',
                'Versi database': '${DatabaseTables.version}',
                'Pertukaran data': 'CSV (Logeva Web)',
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
