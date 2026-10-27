// ============================================================
// tentang_link.dart
// Tautan kecil "Tentang LOGEVA" di bagian bawah Beranda.
// ============================================================

import 'package:flutter/material.dart';

import '../screens/tentang/tentang_screen.dart';
import '../theme/app_colors.dart';

class TentangLink extends StatelessWidget {
  const TentangLink({super.key});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Center(
      child: TextButton.icon(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TentangScreen()),
        ),
        icon: Icon(Icons.info_outline_rounded,
            size: 18, color: p.textSecondary),
        label: Text(
          'Tentang LOGEVA',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: p.textSecondary,
          ),
        ),
      ),
    );
  }
}