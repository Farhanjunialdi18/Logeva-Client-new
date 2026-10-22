// ============================================================
// riwayat_tile.dart
// Satu kartu riwayat: "IMPORT · Data Logistik", tanggal, status.
// ============================================================

import 'package:flutter/material.dart';

import '../models/riwayat_transaksi.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_formatter.dart';

class RiwayatTile extends StatelessWidget {
  final RiwayatTransaksi item;

  const RiwayatTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final statusColor = item.berhasil ? AppColors.success : AppColors.error;

    final detail = <String>[
      if (item.jumlahBaris > 0) '${item.jumlahBaris} baris',
      if (item.keterangan.isNotEmpty) item.keterangan,
    ].join(' • ');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              item.isImport ? Icons.download_rounded : Icons.upload_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.jenis} · ${item.jenisData}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(DateFormatter.full(item.waktu), style: AppTextStyles.small(p)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      item.berhasil ? Icons.check : Icons.close,
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.berhasil ? 'Berhasil' : 'Gagal',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(detail, style: AppTextStyles.small(p)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
