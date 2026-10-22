// ============================================================
// pin_keypad.dart
// Tombol angka 0-9 + hapus untuk memasukkan PIN relawan.
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PinKeypad extends StatelessWidget {
  final void Function(String digit) onDigit;
  final VoidCallback onBackspace;

  const PinKeypad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    // Susunan tombol: '' = kosong, '<' = hapus
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', '<'],
    ];

    return Column(
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 10),
                  Expanded(child: _buildKey(context, row[i])),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildKey(BuildContext context, String key) {
    if (key.isEmpty) return const SizedBox(height: 56);

    if (key == '<') {
      return _KeyButton(
        onTap: onBackspace,
        child: Builder(
          builder: (context) => Icon(
            Icons.backspace_outlined,
            size: 22,
            color: AppPalette.of(context).textPrimary,
          ),
        ),
      );
    }

    return _KeyButton(
      onTap: () => onDigit(key),
      child: Builder(
        builder: (context) =>
            Text(key, style: AppTextStyles.pinKey(AppPalette.of(context))),
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const _KeyButton({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = BorderRadius.circular(12);

    return Material(
      color: p.surfaceAlt,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: p.border),
          ),
          child: child,
        ),
      ),
    );
  }
}
