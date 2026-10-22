// ============================================================
// search_field.dart
// Kolom pencarian (Cari nama pengungsi..., Cari barang...).
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'app_text_field.dart';

class SearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;

  const SearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return TextField(
      onChanged: onChanged,
      style: AppTextStyles.input(p),
      cursorColor: AppColors.primary,
      textInputAction: TextInputAction.search,
      decoration: AppInputDecoration.build(
        p,
        hint: hint,
        prefixIcon: Icon(Icons.search, color: p.textSecondary, size: 20),
      ),
    );
  }
}
