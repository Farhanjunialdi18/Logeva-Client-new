// ============================================================
// app_dropdown_field.dart
// Kolom pilihan (dropdown): kondisi, kategori, satuan, filter.
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_text_field.dart';

class AppDropdownField extends StatelessWidget {
  final String? label; // boleh kosong (untuk filter)
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final String hint;
  final String? Function(String?)? validator;

  const AppDropdownField({
    super.key,
    this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.hint = 'Pilih',
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    // Kalau nilai dari data lama/CSV tidak ada di daftar, tambahkan
    // supaya dropdown tidak error.
    final options = [...items];
    if (value != null && value!.isNotEmpty && !options.contains(value)) {
      options.add(value!);
    }

    final dropdown = DropdownButtonFormField<String>(
      // ignore: deprecated_member_use
      value: (value == null || value!.isEmpty) ? null : value,
      items: options
          .map((e) => DropdownMenuItem<String>(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      validator: validator,
      isExpanded: true,
      dropdownColor: p.surfaceAlt,
      borderRadius: BorderRadius.circular(12),
      iconEnabledColor: p.textPrimary,
      style: AppTextStyles.input(p),
      decoration: AppInputDecoration.build(p, hint: hint),
    );

    if (label == null) return dropdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label!, style: AppTextStyles.label(p)),
        const SizedBox(height: 8),
        dropdown,
      ],
    );
  }
}
