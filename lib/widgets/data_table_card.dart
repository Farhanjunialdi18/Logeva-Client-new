// ============================================================
// data_table_card.dart
// Tabel data (pengungsi / logistik) di dalam kartu.
// Baris bisa diketuk untuk melihat detail.
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class TableColumnSpec {
  final String label;
  final int flex; // lebar relatif kolom

  const TableColumnSpec(this.label, {this.flex = 1});
}

class DataTableCard extends StatelessWidget {
  final List<TableColumnSpec> columns;
  final List<List<String>> rows;
  final void Function(int index)? onRowTap;
  final String emptyMessage;
  final bool isLoading;

  const DataTableCard({
    super.key,
    required this.columns,
    required this.rows,
    this.onRowTap,
    this.emptyMessage = 'Belum ada data.',
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          // ---- Kepala tabel ----
          _buildRow(
            context,
            columns.map((c) => c.label.toUpperCase()).toList(),
            isHeader: true,
          ),
          Divider(height: 1, color: p.border),

          // ---- Isi tabel ----
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Text(emptyMessage, style: AppTextStyles.body(p)),
            )
          else
            for (var i = 0; i < rows.length; i++) ...[
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onRowTap == null ? null : () => onRowTap!(i),
                child: _buildRow(context, rows[i]),
              ),
              if (i < rows.length - 1) Divider(height: 1, color: p.border),
            ],
        ],
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<String> cells,
      {bool isHeader = false}) {
    final p = AppPalette.of(context);

    final style = isHeader
        ? TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: p.textSecondary,
          )
        : TextStyle(fontSize: 12.5, color: p.textPrimary, height: 1.3);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isHeader ? 12 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < columns.length; i++)
            Expanded(
              flex: columns[i].flex,
              child: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  i < cells.length ? cells[i] : '',
                  style: i == 0 && !isHeader
                      ? style.copyWith(fontWeight: FontWeight.w600)
                      : style,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
