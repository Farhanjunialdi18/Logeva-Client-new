// ============================================================
// account_tile.dart
// Satu kartu akun di daftar Kelola Admin / Kelola Relawan:
// kotak ikon, nama, beberapa baris info, status, dan tombol ›.
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'square_icon_button.dart';
import 'status_dot.dart';

class AccountTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;

  /// Baris info di bawah nama. Status ditempel di akhir baris terakhir.
  final List<String> lines;

  /// null = tidak menampilkan status (misal kartu pengungsi/logistik).
  final bool? aktif;
  final VoidCallback onTap;

  const AccountTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.lines,
    this.aktif,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final radius = BorderRadius.circular(18);

    return Material(
      color: p.surface,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: p.border),
          ),
          child: Row(
            children: [
              // ---- Kotak ikon ----
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),

              // ---- Nama + info ----
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: p.textPrimary,
                      ),
                    ),
                    for (var i = 0; i < lines.length; i++) ...[
                      const SizedBox(height: 4),
                      if (i < lines.length - 1 || aktif == null)
                        Text(
                          lines[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.small(p),
                        )
                      else
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                '${lines[i]} · ',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTextStyles.small(p),
                              ),
                            ),
                            StatusDot(aktif: aktif!),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              SquareIconButton(
                icon: Icons.chevron_right_rounded,
                size: 48,
                onPressed: onTap,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
