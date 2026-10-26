// ============================================================
// ganti_password_wajib_screen.dart
// WAJIB GANTI PASSWORD: tampil setelah admin login dengan password
// bawaan (admin123). Semua HP memasang akun bawaan yang sama, jadi
// tanpa langkah ini siapa pun yang memegang HP bisa menjadi admin.
// Halaman ini tidak bisa dilewati: pilihannya ganti password atau keluar.
// ============================================================

import 'package:flutter/material.dart';

import '../../data/repositories/admin_repository.dart';
import '../../routes/app_routes.dart';
import '../../services/session_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_snackbar.dart';
import '../../utils/validators.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/square_icon_button.dart';

class GantiPasswordWajibScreen extends StatefulWidget {
  const GantiPasswordWajibScreen({super.key});

  @override
  State<GantiPasswordWajibScreen> createState() =>
      _GantiPasswordWajibScreenState();
}

class _GantiPasswordWajibScreenState extends State<GantiPasswordWajibScreen> {
  final _formKey = GlobalKey<FormState>();
  final _baru = TextEditingController();
  final _konfirmasi = TextEditingController();
  bool _sembunyikan = true;
  bool _saving = false;

  @override
  void dispose() {
    _baru.dispose();
    _konfirmasi.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final id = SessionService.instance.admin?.id;
    final admin =
        id == null ? null : await AdminRepository.instance.findById(id);
    if (admin == null) {
      _keluar();
      return;
    }

    final error = await AdminRepository.instance.gantiPassword(admin, _baru.text);
    if (!mounted) return;
    if (error != null) {
      setState(() => _saving = false);
      AppSnackbar.show(context, error, isError: true);
      return;
    }

    final terbaru = await AdminRepository.instance.findById(admin.id!);
    if (terbaru != null) SessionService.instance.startAdmin(terbaru);
    if (!mounted) return;
    AppSnackbar.show(context, 'Password berhasil diganti.');
    Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.adminDashboard, (route) => false);
  }

  void _keluar() {
    SessionService.instance.clear();
    Navigator.pushNamedAndRemoveUntil(
        context, AppRoutes.roleSelection, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final nama = SessionService.instance.admin?.username ?? 'admin';

    return PopScope(
      canPop: false, // tombol back tidak bisa melewati halaman ini
      child: Scaffold(
        body: AppBackground(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const Icon(Icons.lock_reset_rounded,
                    size: 48, color: AppColors.primary),
                const SizedBox(height: 16),
                Text('GANTI PASSWORD DULU', style: AppTextStyles.pageTitle(p)),
                const SizedBox(height: 8),
                Text(
                  'Akun "$nama" masih memakai password bawaan. Password ini '
                  'sama di semua HP, jadi siapa pun bisa masuk sebagai admin. '
                  'Buat password baru sebelum memakai aplikasi.',
                  style: AppTextStyles.body(p),
                ),
                const SizedBox(height: 24),

                AppTextField(
                  label: 'Password Baru',
                  isRequired: true,
                  hint: 'Minimal 8 karakter, huruf dan angka',
                  controller: _baru,
                  obscureText: _sembunyikan,
                  validator: Validators.passwordBaru,
                  sideAction: SquareIconButton(
                    size: 54,
                    icon: _sembunyikan
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    tooltip: _sembunyikan
                        ? 'Tampilkan password'
                        : 'Sembunyikan password',
                    onPressed: () =>
                        setState(() => _sembunyikan = !_sembunyikan),
                  ),
                ),
                const SizedBox(height: 16),

                AppTextField(
                  label: 'Konfirmasi Password Baru',
                  isRequired: true,
                  hint: 'Ulangi password baru',
                  controller: _konfirmasi,
                  obscureText: _sembunyikan,
                  textInputAction: TextInputAction.done,
                  validator: Validators.konfirmasiPassword(() => _baru.text),
                  onFieldSubmitted: (_) => _simpan(),
                ),
                const SizedBox(height: 12),
                Text(
                  'Simpan password ini baik-baik. Kalau lupa, admin lain di HP '
                  'ini (Super Admin) bisa menggantinya di menu Kelola Admin.',
                  style: AppTextStyles.small(p),
                ),
                const SizedBox(height: 24),

                PrimaryButton(
                  text: 'SIMPAN PASSWORD',
                  isLoading: _saving,
                  onPressed: _simpan,
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  text: 'KELUAR',
                  icon: Icons.logout_rounded,
                  height: 50,
                  onPressed: _saving ? null : _keluar,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
