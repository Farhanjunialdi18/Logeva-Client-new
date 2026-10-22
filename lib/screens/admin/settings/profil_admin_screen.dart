// ============================================================
// profil_admin_screen.dart
// PROFIL ADMIN: admin yang sedang login mengubah nama, username,
// dan email-nya sendiri. (Role & status diatur lewat Kelola Admin.)
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/repositories/admin_repository.dart';
import '../../../models/admin.dart';
import '../../../services/session_service.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/date_formatter.dart';
import '../../../utils/validators.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/initials_avatar.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';

class ProfilAdminScreen extends StatefulWidget {
  const ProfilAdminScreen({super.key});

  @override
  State<ProfilAdminScreen> createState() => _ProfilAdminScreenState();
}

class _ProfilAdminScreenState extends State<ProfilAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nama = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();

  Admin? _admin;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nama.dispose();
    _username.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final id = SessionService.instance.admin?.id;
    final admin = id == null ? null : await AdminRepository.instance.findById(id);
    if (!mounted) return;
    setState(() {
      _admin = admin;
      _loading = false;
      if (admin != null) {
        _nama.text = admin.nama;
        _username.text = admin.username;
        _email.text = admin.email;
      }
    });
  }

  void _gagal(String pesan) {
    if (!mounted) return;
    setState(() => _saving = false);
    AppSnackbar.show(context, pesan, isError: true);
  }

  Future<void> _simpan() async {
    final admin = _admin;
    if (admin == null) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final repo = AdminRepository.instance;
    if (await repo.isUsernameTaken(_username.text, exceptId: admin.id)) {
      return _gagal('Username sudah dipakai admin lain.');
    }
    if (await repo.isEmailTaken(_email.text, exceptId: admin.id)) {
      return _gagal('Email sudah dipakai admin lain.');
    }

    final hasil = await repo.update(
      admin.copyWith(
        nama: _nama.text,
        username: _username.text,
        email: _email.text,
      ),
    );
    SessionService.instance.startAdmin(hasil);

    if (!mounted) return;
    AppSnackbar.show(context, 'Profil diperbarui.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final admin = _admin;

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Profil Admin',
                subtitle: 'Kelola informasi akun Anda',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 20),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (admin == null)
                const EmptyState(
                  icon: Icons.person_off_rounded,
                  message: 'Data akun tidak ditemukan. Silakan login ulang.',
                )
              else ...[
                Center(child: InitialsAvatar(nama: admin.nama)),
                const SizedBox(height: 20),

                AppTextField(
                  label: 'Nama Lengkap',
                  isRequired: true,
                  hint: 'Nama lengkap',
                  controller: _nama,
                  textCapitalization: TextCapitalization.words,
                  validator: Validators.wajib('Nama'),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Username',
                  isRequired: true,
                  hint: 'Username',
                  controller: _username,
                  validator: Validators.username,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  label: 'Email',
                  isRequired: true,
                  hint: 'Email',
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  validator: Validators.email,
                ),
                const SizedBox(height: 16),

                InfoCard(
                  rows: {
                    'Role': admin.role,
                    'Status': admin.status,
                    'Dibuat': DateFormatter.date(admin.dibuatPada),
                  },
                  note: 'Role dan status hanya bisa diubah Super Admin '
                      'melalui menu Kelola Admin.',
                ),
                const SizedBox(height: 24),

                PrimaryButton(
                  text: 'SIMPAN PROFIL',
                  isLoading: _saving,
                  onPressed: _simpan,
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
