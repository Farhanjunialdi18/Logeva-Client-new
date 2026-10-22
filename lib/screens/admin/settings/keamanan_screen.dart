// ============================================================
// keamanan_screen.dart
// KEAMANAN: ganti password admin yang sedang login.
// Wajib memasukkan password lama dulu.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/repositories/admin_repository.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/password_hasher.dart';
import '../../../utils/validators.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/square_icon_button.dart';

class KeamananScreen extends StatefulWidget {
  const KeamananScreen({super.key});

  @override
  State<KeamananScreen> createState() => _KeamananScreenState();
}

class _KeamananScreenState extends State<KeamananScreen> {
  final _formKey = GlobalKey<FormState>();
  final _lama = TextEditingController();
  final _baru = TextEditingController();
  final _konfirmasi = TextEditingController();

  bool _sembunyikan = true;
  bool _saving = false;

  @override
  void dispose() {
    _lama.dispose();
    _baru.dispose();
    _konfirmasi.dispose();
    super.dispose();
  }

  void _gagal(String pesan) {
    if (!mounted) return;
    setState(() => _saving = false);
    AppSnackbar.show(context, pesan, isError: true);
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    // Ambil data terbaru dari database (bukan dari sesi) supaya hash akurat.
    final id = SessionService.instance.admin?.id;
    final admin = id == null ? null : await AdminRepository.instance.findById(id);
    if (admin == null) return _gagal('Data akun tidak ditemukan. Login ulang.');

    final cocok = PasswordHasher.verify(
      _lama.text,
      hash: admin.passwordHash,
      salt: admin.passwordSalt,
    );
    if (!cocok) return _gagal('Password lama salah.');
    if (_baru.text == _lama.text) {
      return _gagal('Password baru harus berbeda dari password lama.');
    }

    final hasil = await AdminRepository.instance.update(
      admin,
      newPassword: _baru.text,
    );
    SessionService.instance.startAdmin(hasil);

    if (!mounted) return;
    AppSnackbar.show(context, 'Password berhasil diganti.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Keamanan',
                subtitle: 'Ganti password akun Anda',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 24),

              AppTextField(
                label: 'Password Lama',
                isRequired: true,
                hint: 'Masukkan password saat ini',
                controller: _lama,
                obscureText: _sembunyikan,
                validator: Validators.wajib('Password lama'),
                sideAction: SquareIconButton(
                  size: 54,
                  icon: _sembunyikan
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  tooltip:
                      _sembunyikan ? 'Tampilkan password' : 'Sembunyikan password',
                  onPressed: () => setState(() => _sembunyikan = !_sembunyikan),
                ),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Password Baru',
                isRequired: true,
                hint: 'Minimal 6 karakter',
                controller: _baru,
                obscureText: _sembunyikan,
                validator: Validators.password,
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
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.shield_outlined,
                      size: 16, color: AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Password disimpan dalam bentuk acak (hash), '
                      'sehingga tidak bisa dibaca dari file database.',
                      style: AppTextStyles.small(p),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              PrimaryButton(
                text: 'GANTI PASSWORD',
                isLoading: _saving,
                onPressed: _simpan,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
