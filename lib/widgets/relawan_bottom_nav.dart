// ============================================================
// relawan_bottom_nav.dart
// Menu bawah relawan: Beranda, Pengungsi, Logistik, Riwayat, Logout.
// Di HP Anggota, Riwayat diganti Sinkron (kegiatan rutin relawan).
// ============================================================

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class NavItem {
  final IconData icon;
  final String label;
  const NavItem(this.icon, this.label);
}

class RelawanBottomNav extends StatelessWidget {
  static const List<NavItem> items = [
    NavItem(Icons.home_rounded, 'Beranda'),
    NavItem(Icons.groups_rounded, 'Pengungsi'),
    NavItem(Icons.inventory_2_rounded, 'Logistik'),
    NavItem(Icons.history_rounded, 'Riwayat'),
    NavItem(Icons.logout_rounded, 'Logout'),
  ];

  static const List<NavItem> itemsAnggota = [
    NavItem(Icons.home_rounded, 'Beranda'),
    NavItem(Icons.groups_rounded, 'Pengungsi'),
    NavItem(Icons.inventory_2_rounded, 'Logistik'),
    NavItem(Icons.sync_alt_rounded, 'Sinkron'),
    NavItem(Icons.logout_rounded, 'Logout'),
  ];

  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool hpAnggota;

  const RelawanBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.hpAnggota = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final daftar = hpAnggota ? itemsAnggota : items;

    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (var i = 0; i < daftar.length; i++)
                Expanded(
                  child: _NavButton(
                    item: daftar[i],
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

  const _NavButton({required this.item, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final color = active ? AppColors.primary : p.textPrimary;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(item.icon, size: 20, color: active ? AppColors.primary : p.textSecondary),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
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
