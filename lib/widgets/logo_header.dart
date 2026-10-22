// ============================================================
// logo_header.dart
// Logo GMLS + judul "LOGEVA Client" + subjudul.
// Dipakai di halaman pilih peran, login admin, dan login relawan.
// ============================================================

import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_logo.dart';

class LogoHeader extends StatelessWidget {
  final double size;
  final bool showRibbon; // pita merah "GUGUS MITIGASI LEBAK SELATAN"
  final List<String> subtitles;

  const LogoHeader({
    super.key,
    this.size = 72,
    this.showRibbon = false,
    this.subtitles = const [AppConstants.appTagline],
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            AppLogo(size: size),
            if (showRibbon)
              Positioned(
                bottom: -8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'GUGUS MITIGASI LEBAK SELATAN',
                    style: TextStyle(
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: showRibbon ? 22 : 16),
        Text(AppConstants.appName, style: AppTextStyles.appTitle(p)),
        const SizedBox(height: 6),
        for (final s in subtitles)
          Text(
            s,
            textAlign: TextAlign.center,
            style: AppTextStyles.subtitle(p),
          ),
      ],
    );
  }
}
