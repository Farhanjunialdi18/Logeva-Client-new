// ============================================================
// page_header.dart
// Kepala halaman: tombol kembali + judul + subjudul (+ badge offline).
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'offline_badge.dart';
import 'square_icon_button.dart';

class PageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onBack;
  final bool showOfflineBadge;

  const PageHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.subtitle,
    this.showOfflineBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SquareIconButton(
              icon: Icons.arrow_back,
              tooltip: 'Kembali',
              onPressed: onBack,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.pageTitle(p),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(subtitle!, style: AppTextStyles.body(p)),
        ],
        if (showOfflineBadge) ...[
          const SizedBox(height: 10),
          const OfflineBadge(),
        ],
      ],
    );
  }
}
