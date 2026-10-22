// ============================================================
// admin_bottom_nav.dart
// Menu bawah admin: Beranda, Admin, Relawan, Data, Settings.
// Bentuknya kartu dengan sudut atas membulat (sesuai desain Canva).
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'relawan_bottom_nav.dart' show NavItem;

class AdminBottomNav extends StatelessWidget {
  static const List<NavItem> items = [
    NavItem(Icons.home_rounded, 'Beranda'),
    NavItem(Icons.manage_accounts_rounded, 'Admin'),
    NavItem(Icons.volunteer_activism_rounded, 'Relawan'),
    NavItem(Icons.bar_chart_rounded, 'Data'),
    NavItem(Icons.settings_rounded, 'Settings'),
  ];

  final int currentIndex;
  final ValueChanged<int> onTap;

  const AdminBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    active: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final NavItem item;
  final bool active;
  final VoidCallback onTap;

  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.icon,
            size: 20,
            color: active ? AppColors.primary : p.textSecondary,
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.primary : p.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Garis merah di bawah menu yang aktif
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: active ? 22 : 0,
            height: 3,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
