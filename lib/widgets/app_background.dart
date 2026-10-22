// ============================================================
// app_background.dart
// Latar belakang gradasi + cahaya merah di atas,
// sekaligus membuat halaman bisa di-scroll & rapi di layar lebar.
// ============================================================

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const AppBackground({
    super.key,
    required this.child,
    this.maxWidth = 420,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [p.backgroundTop, p.backgroundBottom],
        ),
      ),
      child: Stack(
        children: [
          // Cahaya merah samar di bagian atas
          Positioned(
            top: -140,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 360,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    colors: [AppColors.primaryGlow, Colors.transparent],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: math.max(
                          0.0,
                          math.min(maxWidth, constraints.maxWidth - 40),
                        ),
                        maxWidth: maxWidth,
                        minHeight: math.max(0.0, constraints.maxHeight - 32),
                      ),
                      child: child,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
