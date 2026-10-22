// ============================================================
// info_card.dart
// Kartu berisi judul kecil + baris "label ........ isi".
// Dipakai di halaman Settings (Penyimpanan, Tentang, Pengaturan Data).
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class InfoCard extends StatelessWidget {
  final String? title;
  final Map<String, String> rows;

  /// Teks tambahan di bawah baris-baris (boleh kosong).
  final String? note;

  const InfoCard({super.key, this.title, required this.rows, this.note});

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
          if (title != null) ...[
            Text(title!, style: AppTextStyles.cardTitle(p)),
            const SizedBox(height: 10),
          ],
          for (final entry in rows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: Text(entry.key, style: AppTextStyles.body(p)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 6,
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: p.textPrimary,
                      ),
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
