// ============================================================
// summary_card.dart
// Kartu besar "Total Pengungsi / 126 Orang".
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SummaryCard extends StatelessWidget {
  final String label;
  final String value;

  const SummaryCard({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.body(p)),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
