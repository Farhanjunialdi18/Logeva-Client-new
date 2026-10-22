// ============================================================
// pin_card.dart
// Kartu "Generate PIN Otomatis" di form Tambah Relawan:
// PIN 6 digit + tombol GENERATE PIN BARU.
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'secondary_button.dart';

class PinCard extends StatelessWidget {
  final String? pin; // null = sedang dibuat
  final VoidCallback onGenerate;
  final bool isGenerating;

  const PinCard({
    super.key,
    required this.pin,
    required this.onGenerate,
    this.isGenerating = false,
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
          Text('Generate PIN Otomatis', style: AppTextStyles.small(p)),
          const SizedBox(height: 6),
          Text(
            pin ?? '······',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          SecondaryButton(
            text: 'GENERATE PIN BARU',
            icon: Icons.autorenew_rounded,
            height: 54,
            isLoading: isGenerating,
            onPressed: onGenerate,
          ),
          const SizedBox(height: 10),
          Text(
            'PIN dibuat otomatis oleh sistem dan digunakan relawan untuk login.',
            style: AppTextStyles.small(p),
          ),
        ],
      ),
    );
  }
}
