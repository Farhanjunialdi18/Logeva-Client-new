// ============================================================
// detail_info_card.dart
// Kartu detail akun: label "Nama", nama besar, lalu baris info
// (Username: ..., Email: ..., Status: ● Aktif, dll).
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class DetailInfoCard extends StatelessWidget {
  final String nama;
  final List<Widget> rows;

  const DetailInfoCard({super.key, required this.nama, required this.rows});

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
          Text('Nama', style: AppTextStyles.small(p)),
          const SizedBox(height: 6),
          Text(
            nama,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          for (final row in rows) ...[
            const SizedBox(height: 8),
            row,
          ],
        ],
      ),
    );
  }
}

/// Satu baris "Label: nilai". Kalau [child] diisi, dipakai sebagai nilai.
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? child;

  const DetailRow({super.key, required this.label, this.value = '', this.child});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final style = AppTextStyles.body(p);

    if (child == null) return Text('$label: $value', style: style);

    return Row(
      children: [
        Text('$label: ', style: style),
        Flexible(child: child!),
      ],
    );
  }
}
