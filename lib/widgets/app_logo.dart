// ============================================================
// app_logo.dart
// Logo GMLS bulat. Kalau file logo belum ada, tampil logo cadangan.
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_constants.dart';
import '../theme/app_colors.dart';

class AppLogo extends StatelessWidget {
  final double size;
  final bool glow;

  const AppLogo({super.key, this.size = 72, this.glow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0E1117),
        border: Border.all(color: Colors.white, width: size > 48 ? 2 : 1.5),
        boxShadow: glow
            ? const [
                BoxShadow(
                  color: AppColors.primaryGlow,
                  blurRadius: 32,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: ClipOval(
        child: Image.asset(
          AppConstants.logoPath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _FallbackLogo(size: size),
        ),
      ),
    );
  }
}

/// Logo cadangan: belah ketupat merah dengan tulisan GMLS.
class _FallbackLogo extends StatelessWidget {
  final double size;
  const _FallbackLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    final box = size * 0.46;
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: box,
              height: box,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.primary, width: size * 0.07),
              ),
            ),
          ),
          Text(
            'GMLS',
            style: TextStyle(
              fontSize: size * 0.13,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}
