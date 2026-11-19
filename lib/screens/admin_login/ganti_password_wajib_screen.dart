// ============================================================
// ganti_password_wajib_screen.dart
// LENGKAPI AKUN ADMIN POSKO: tampil setelah admin login kalau
//  - password masih bawaan (admin123): semua HP memasang akun bawaan yang
//    sama, jadi tanpa langkah ini siapa pun bisa menjadi admin;
//  - nama masih bawaan ("Admin GMLS"): nama ini dikirim ke website sebagai
//    ADMIN POSKO (penanggung jawab) di laporan, jadi wajib nama asli.
// Halaman ini tidak bisa dilewati: pilihannya lengkapi akun atau keluar.
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
  final _nama = TextEditingController();
  final _baru = TextEditingController();
  final _konfirmasi = TextEditingController();
  bool _sembunyikan = true;
  bool _saving = false;

  /// Password masih bawaan = kolom password ditampilkan.
  bool _gantiPassword = true;

  @override
  void initState() {
    super.initState();
    final admin = SessionService.instance.admin;
    if (admin != null) {
      final repo = AdminRepository.instance;
      _gantiPassword = repo.masihPasswordBawaan(admin);
      if (!repo.masihNamaBawaan(admin)) _nama.text = admin.nama;
    }
  }

  @override
  void dispose() {
    _nama.dispose();
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

    final repo = AdminRepository.instance;
    var data = admin.copyWith(nama: _nama.text.trim());
    if (_gantiPassword) {
      // Cek password lama = baru dulu, sebelum apa pun disimpan.
      final error = await repo.gantiPassword(data, _baru.text);
      if (!mounted) return;
      if (error != null) {
        setState(() => _saving = false);
        AppSnackbar.show(context, error, isError: true);
        return;
      }
    } else {
      await repo.update(data);
    }

    final terbaru = await repo.findById(admin.id!);
    if (terbaru != null) SessionService.instance.startAdmin(terbaru);
    if (!mounted) return;
    AppSnackbar.show(context, 'Akun admin posko sudah lengkap.');
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
    final username = SessionService.instance.admin?.username ?? 'admin';

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
                Text('LENGKAPI AKUN ADMIN POSKO', style: AppTextStyles.pageTitle(p)),
                const SizedBox(height: 8),
                Text(
                  'Isi nama asli Anda: nama ini tercatat sebagai ADMIN POSKO '
                  '(penanggung jawab) di laporan website.'
                  '${_gantiPassword ? ' Akun "$username" juga masih memakai password '
                      'bawaan yang sama di semua HP, jadi buat password baru.' : ''}',
                  style: AppTextStyles.body(p),
                ),
                const SizedBox(height: 24),

                AppTextField(
                  label: 'Nama Lengkap Admin Posko',
                  isRequired: true,
                  hint: 'Contoh: Budi Santoso',
                  controller: _nama,
                  textCapitalization: TextCapitalization.words,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Nama wajib diisi.';
                    if (t.toLowerCase() == AdminRepository.defaultNama.toLowerCase()) {
                      return 'Ganti dengan nama asli Anda.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (_gantiPassword) ...[

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
                  'Catat password ini di tempat aman. HP ini hanya punya satu '
                  'admin (supervisor posko), jadi password yang lupa tidak bisa '
                  'direset dari HP lain.',
                  style: AppTextStyles.small(p),
                ),
                ],
                const SizedBox(height: 24),

                PrimaryButton(
                  text: 'SIMPAN',
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
