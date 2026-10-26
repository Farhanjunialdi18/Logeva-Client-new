// ============================================================
// app_text_field.dart
// Kolom isian dengan label di atasnya (USERNAME, NAMA, USIA, dll).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;

  /// Widget di samping kanan kolom (misal tombol lihat password).
  final Widget? sideAction;

  /// true = tampilkan tanda * merah di samping label (wajib diisi).
  final bool isRequired;

  /// true + [onTap] = kolom tidak bisa diketik, ketuk untuk memilih
  /// (misal pemilih tanggal).
  final bool readOnly;
  final VoidCallback? onTap;

  const AppTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.validator,
    this.onFieldSubmitted,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.sideAction,
    this.isRequired = false,
    this.readOnly = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    final field = TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      readOnly: readOnly,
      onTap: onTap,
      style: AppTextStyles.input(p),
      cursorColor: AppColors.primary,
      decoration: AppInputDecoration.build(p, hint: hint),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: [
              if (isRequired)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: AppColors.primary),
                ),
            ],
          ),
          style: AppTextStyles.label(p),
        ),
        const SizedBox(height: 8),
        if (sideAction == null)
          field
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: field),
              const SizedBox(width: 10),
              sideAction!,
            ],
          ),
      ],
    );
  }
}

/// Gaya kotak isian yang sama untuk semua kolom (teks, dropdown, cari).
class AppInputDecoration {
  AppInputDecoration._();

  static InputDecoration build(
    AppPalette p, {
    String? hint,
    Widget? prefixIcon,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.body(p),
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: p.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: border(p.border),
      focusedBorder: border(AppColors.primary, 1.5),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 1.5),
      errorStyle: const TextStyle(color: AppColors.error, fontSize: 12),
    );
  }
}
