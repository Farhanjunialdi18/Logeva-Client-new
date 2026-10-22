// ============================================================
// back_link.dart
// Tautan "← Kembali".
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class BackLink extends StatelessWidget {
  final VoidCallback? onTap;
  const BackLink({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap ?? () => Navigator.of(context).maybePop(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.arrow_back, size: 16, color: p.textSecondary),
            const SizedBox(width: 6),
            Text('Kembali', style: AppTextStyles.body(p)),
          ],
        ),
      ),
    );
  }
}
