// ============================================================
// team_member_card.dart
// Kartu satu anggota tim: foto bulat + nama + peran.
// ============================================================

import 'package:flutter/material.dart';

import '../core/tim_pengembang.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'initials_avatar.dart';

class TeamMemberCard extends StatelessWidget {
  final AnggotaTim anggota;
  final double width;

  const TeamMemberCard({
    super.key,
    required this.anggota,
    required this.width,
  });

  static const double _fotoSize = 76;

  Widget _foto() {
    final inisial = InitialsAvatar(nama: anggota.nama, size: _fotoSize);
    final path = anggota.foto;
    if (path == null) return inisial;

    return ClipOval(
      child: Image.asset(
        path,
        width: _fotoSize,
        height: _fotoSize,
        fit: BoxFit.cover,
        // Foto belum ada / salah nama -> tampilkan inisial
        errorBuilder: (context, error, stackTrace) => inisial,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Container(
      width: width,
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 16),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: p.border, width: 3),
            ),
            child: _foto(),
          ),
          const SizedBox(height: 12),
          Text(
            anggota.nama,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.3,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            anggota.peran,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.small(p),
          ),
        ],
      ),
    );
  }
}