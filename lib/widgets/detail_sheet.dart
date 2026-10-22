// ============================================================
// detail_sheet.dart
// Panel dari bawah layar: daftar "label : isi" + tombol EDIT & HAPUS.
// Dipakai detail pengungsi dan detail logistik.
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'secondary_button.dart';

enum DetailAction { edit, hapus }

class DetailSheet {
  DetailSheet._();

  static Future<DetailAction?> show(
    BuildContext context, {
    required String title,
    required Map<String, String> rows,
  }) {
    final p = AppPalette.of(context);

    return showModalBottomSheet<DetailAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Garis kecil penanda bisa digeser
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: p.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(title, style: AppTextStyles.pageTitle(p).copyWith(fontSize: 20)),
              const SizedBox(height: 14),
              for (final entry in rows.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(entry.key, style: AppTextStyles.body(p)),
                      ),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: AppTextStyles.input(p).copyWith(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      text: 'EDIT',
                      icon: Icons.edit_outlined,
                      height: 50,
                      onPressed: () => Navigator.of(ctx).pop(DetailAction.edit),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(DetailAction.hapus),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('HAPUS', style: AppTextStyles.button),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
