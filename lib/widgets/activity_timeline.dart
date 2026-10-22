// ============================================================
// activity_timeline.dart
// Daftar "AKTIVITAS TERBARU": titik merah + garis vertikal,
// judul aktivitas, dan waktunya.
// ============================================================

import 'package:flutter/material.dart';

import '../services/aktivitas_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_formatter.dart';

class ActivityTimeline extends StatelessWidget {
  final List<Aktivitas> items;

  const ActivityTimeline({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Text('Belum ada aktivitas.', style: AppTextStyles.body(p)),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _TimelineRow(item: items[i], isLast: i == items.length - 1),
      ],
    );
  }
}

class _TimelineRow extends StatelessWidget {
  final Aktivitas item;
  final bool isLast;

  const _TimelineRow({required this.item, required this.isLast});

  IconData get _icon => switch (item.jenis) {
        JenisAktivitas.impor => Icons.arrow_downward_rounded,
        JenisAktivitas.ekspor => Icons.arrow_upward_rounded,
        JenisAktivitas.relawanBaru => Icons.volunteer_activism_rounded,
        JenisAktivitas.adminBaru => Icons.manage_accounts_rounded,
        JenisAktivitas.gagal => Icons.error_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    // IntrinsicHeight membuat garis vertikal setinggi isi barisnya.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Titik merah + garis ----
          SizedBox(
            width: 24,
            child: Column(
              children: [
                const SizedBox(height: 4),
                Container(
                  width: 12,
                  height: 12,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(child: Container(width: 2, color: p.border)),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ---- Isi ----
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Icon(
                          _icon,
                          size: 15,
                          color: item.jenis == JenisAktivitas.gagal
                              ? AppColors.error
                              : p.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.judul,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    DateFormatter.shortFull(item.waktu),
                    style: AppTextStyles.small(p),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
