// ============================================================
// admin_detail_screen.dart
// HALAMAN DETAIL ADMINISTRATOR:
// inisial, info akun, tombol Edit, Nonaktifkan/Aktifkan, dan Hapus.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/data_options.dart';
import '../../../data/data_events.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../models/admin.dart';
import '../../../services/admin_rules.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/date_formatter.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/detail_info_card.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/initials_avatar.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/secondary_button.dart';
import '../../../widgets/status_dot.dart';
import 'admin_form_screen.dart';

class AdminDetailScreen extends StatefulWidget {
  final int adminId;

  const AdminDetailScreen({super.key, required this.adminId});

  @override
  State<AdminDetailScreen> createState() => _AdminDetailScreenState();
}

class _AdminDetailScreenState extends State<AdminDetailScreen> {
  Admin? _admin;
  bool _loading = true;
  bool _busy = false;

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
    final data = await AdminRepository.instance.findById(widget.adminId);
    if (!mounted) return;
    setState(() {
      _admin = data;
      _loading = false;
    });
  }

  void _edit(Admin admin) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AdminFormScreen(existing: admin)),
    );
  }

  Future<void> _ubahStatus(Admin admin) async {
    final statusBaru =
        admin.isAktif ? DataOptions.statusNonaktif : DataOptions.statusAktif;

    final larangan = await AdminRules.cekUbah(
      admin,
      roleBaru: admin.role,
      statusBaru: statusBaru,
    );
    if (!mounted) return;
    if (larangan != null) {
      AppSnackbar.show(context, larangan, isError: true);
      return;
    }

    final yakin = await ConfirmDialog.show(
      context,
      title: admin.isAktif ? 'Nonaktifkan admin?' : 'Aktifkan admin?',
      message: admin.isAktif
          ? '${admin.nama} tidak akan bisa login sampai diaktifkan lagi.'
          : '${admin.nama} akan bisa login kembali.',
      confirmText: admin.isAktif ? 'NONAKTIFKAN' : 'AKTIFKAN',
    );
    if (!yakin || !mounted) return;

    setState(() => _busy = true);
    await AdminRepository.instance.update(admin.copyWith(status: statusBaru));
    if (!mounted) return;
    setState(() => _busy = false);
    AppSnackbar.show(
      context,
      statusBaru == DataOptions.statusAktif
          ? 'Admin diaktifkan.'
          : 'Admin dinonaktifkan.',
    );
  }

  Future<void> _hapus(Admin admin) async {
    final larangan = await AdminRules.cekHapus(admin);
    if (!mounted) return;
    if (larangan != null) {
      AppSnackbar.show(context, larangan, isError: true);
      return;
    }

    final yakin = await ConfirmDialog.show(
      context,
      title: 'Hapus admin?',
      message: 'Akun ${admin.nama} akan dihapus permanen.',
      confirmText: 'HAPUS',
    );
    if (!yakin || !mounted || admin.id == null) return;

    await AdminRepository.instance.delete(admin.id!);
    if (!mounted) return;
    AppSnackbar.show(context, 'Admin dihapus.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final admin = _admin;

    // Bukan Scaffold: halaman ini dibuka di dalam tab admin (Scaffold
    // utama sudah ada di AdminShellScreen), supaya keyboard tidak
    // menggeser halaman dua kali.
    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Detail Administrator',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (admin == null)
              const EmptyState(
                icon: Icons.person_off_rounded,
                message: 'Akun admin tidak ditemukan.',
              )
            else ...[
              Center(child: InitialsAvatar(nama: admin.nama)),
              const SizedBox(height: 16),

              DetailInfoCard(
                nama: admin.nama,
                rows: [
                  DetailRow(label: 'Username', value: admin.username),
                  DetailRow(label: 'Email', value: admin.email),
                  DetailRow(label: 'Role', value: admin.role),
                  DetailRow(
                    label: 'Status',
                    child: StatusDot(aktif: admin.isAktif, fontSize: 13),
                  ),
                  DetailRow(
                    label: 'Dibuat',
                    value: DateFormatter.date(admin.dibuatPada),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (admin.id == SessionService.instance.admin?.id) ...[
                Text(
                  'Ini akun Anda yang sedang login.',
                  style: AppTextStyles.small(p).copyWith(color: AppColors.success),
                ),
                const SizedBox(height: 12),
              ],

              if (AdminRules.bolehKelola) ...[
                PrimaryButton(text: 'EDIT ADMIN', onPressed: () => _edit(admin)),
                const SizedBox(height: 12),
                SecondaryButton(
                  text: admin.isAktif ? 'NONAKTIFKAN ADMIN' : 'AKTIFKAN ADMIN',
                  height: 54,
                  isLoading: _busy,
                  onPressed: () => _ubahStatus(admin),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  text: 'HAPUS ADMIN',
                  icon: Icons.delete_outline_rounded,
                  height: 54,
                  onPressed: () => _hapus(admin),
                ),
              ] else
                Text(AdminRules.pesanBukanSuperAdmin,
                    style: AppTextStyles.small(p)),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
