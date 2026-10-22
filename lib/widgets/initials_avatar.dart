// ============================================================
// initials_avatar.dart
// Lingkaran merah berisi inisial nama (contoh: "Admin GMLS" -> AG).
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class InitialsAvatar extends StatelessWidget {
  final String nama;
  final double size;

  const InitialsAvatar({super.key, required this.nama, this.size = 78});

  /// Ambil huruf pertama dari 2 kata pertama.
  static String initialsOf(String nama) {
    final kata = nama.trim().split(RegExp(r'\s+')).where((k) => k.isNotEmpty);
    final huruf = kata.take(2).map((k) => k[0].toUpperCase()).join();
    return huruf.isEmpty ? '?' : huruf;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
      ),
      child: Text(
        initialsOf(nama),
        style: TextStyle(
          fontSize: size * 0.36,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
