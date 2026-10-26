// ============================================================
// langkah_card.dart
// Kartu berisi langkah-langkah bernomor (1, 2, 3, ...), rata kiri.
// Gaya kartunya sama dengan InfoCard.
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class LangkahCard extends StatelessWidget {
  final String title;
  final List<String> langkah;
  final String? note;

  const LangkahCard({
    super.key,
    required this.title,
    required this.langkah,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.cardTitle(p)),
          const SizedBox(height: 10),
          for (final (i, teks) in langkah.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      teks,
                      style: TextStyle(fontSize: 13, color: p.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note!, style: AppTextStyles.small(p)),
          ],
        ],
      ),
    );
  }
}
