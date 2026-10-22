// ============================================================
// segmented_choice.dart
// Pilihan berdampingan, contoh: [Laki-laki] [Perempuan].
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class SegmentedChoice extends StatelessWidget {
  final String label;
  final Map<String, String> options; // nilai -> teks tampil
  final String selected;
  final ValueChanged<String> onChanged;

  const SegmentedChoice({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final entries = options.entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.label(p)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < entries.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: _Option(
                  text: entries[i].value,
                  active: entries[i].key == selected,
                  onTap: () => onChanged(entries[i].key),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _Option({required this.text, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = BorderRadius.circular(12);

    return Material(
      color: active ? AppColors.primarySoft : p.inputFill,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: active ? AppColors.primary : p.border,
              width: active ? 1.5 : 1,
            ),
          ),
          child: Text(
            text,
            style: AppTextStyles.input(p).copyWith(
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
