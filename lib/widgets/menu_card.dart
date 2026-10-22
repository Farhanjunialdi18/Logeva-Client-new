// ============================================================
// menu_card.dart
// Kartu menu di Beranda (DATA PENGUNGSI, DATA LOGISTIK, RIWAYAT)
// dengan garis merah di sisi kiri.
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class MenuCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  const MenuCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = BorderRadius.circular(16);

    return ClipRRect(
      borderRadius: radius,
      child: Material(
        color: p.surfaceAlt,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: p.border),
            ),
            child: Stack(
              children: [
                // Garis merah kiri
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 3, color: AppColors.primary),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(icon, color: iconColor, size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    title,
                                    style: AppTextStyles.cardTitle(p),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(description, style: AppTextStyles.small(p)),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: p.textSecondary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
