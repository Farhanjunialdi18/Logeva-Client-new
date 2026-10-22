// ============================================================
// kelola_admin_screen.dart
// HALAMAN KELOLA ADMIN (tab "Admin"):
// jumlah akun, tombol tambah, pencarian, dan daftar admin.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../models/admin.dart';
import '../../../services/admin_rules.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/account_tile.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/search_field.dart';
import '../../../widgets/summary_card.dart';
import 'admin_detail_screen.dart';
import 'admin_form_screen.dart';

class KelolaAdminScreen extends StatefulWidget {
  final VoidCallback onBack;

  const KelolaAdminScreen({super.key, required this.onBack});

  @override
  State<KelolaAdminScreen> createState() => _KelolaAdminScreenState();
}

class _KelolaAdminScreenState extends State<KelolaAdminScreen> {
  List<Admin> _semua = [];
  bool _loading = true;
  String _kataCari = '';

  @override
  void initState() {
    super.initState();
    _load();
    DataEvents.instance.addListener(_load);
  }

  @override
  void dispose() {
    DataEvents.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final data = await AdminRepository.instance.getAll();
    if (!mounted) return;
    setState(() {
      _semua = data;
      _loading = false;
    });
  }

  List<Admin> get _hasilCari {
    final q = _kataCari.trim().toLowerCase();
    if (q.isEmpty) return _semua;
    return _semua
        .where((a) =>
            a.nama.toLowerCase().contains(q) ||
            a.username.toLowerCase().contains(q) ||
            a.email.toLowerCase().contains(q))
        .toList();
  }

  void _tambah() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminFormScreen()),
    );
  }

  void _bukaDetail(Admin admin) {
    if (admin.id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminDetailScreen(adminId: admin.id!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final list = _hasilCari;

    return AppBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Kelola Admin',
            subtitle: 'Kelola administrator LOGEVA Client',
            onBack: widget.onBack,
          ),
          const SizedBox(height: 16),

          SummaryCard(
            label: 'Jumlah akun',
            value: _loading ? '...' : '${_semua.length} Administrator',
          ),
          const SizedBox(height: 16),

          if (AdminRules.bolehKelola)
            PrimaryButton(text: '+ TAMBAH ADMIN', onPressed: _tambah)
          else
            Text(AdminRules.pesanBukanSuperAdmin, style: AppTextStyles.small(p)),
          const SizedBox(height: 14),

          SearchField(
            hint: 'Cari admin...',
            onChanged: (v) => setState(() => _kataCari = v),
          ),
          const SizedBox(height: 14),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (list.isEmpty)
            EmptyState(
              icon: Icons.manage_accounts_rounded,
              message: _kataCari.isEmpty
                  ? 'Belum ada akun admin.'
                  : 'Tidak ditemukan "$_kataCari".',
            )
          else
            for (final admin in list) ...[
              AccountTile(
                icon: Icons.person_rounded,
                iconColor: AppColors.accentPurple,
                title: admin.nama,
                lines: [
                  'Username: ${admin.username}',
                  'Email: ${admin.email}',
                ],
                aktif: admin.isAktif,
                onTap: () => _bukaDetail(admin),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
