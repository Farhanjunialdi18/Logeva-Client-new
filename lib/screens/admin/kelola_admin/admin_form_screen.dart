// ============================================================
// admin_form_screen.dart
// FORM TAMBAH / EDIT ADMINISTRATOR.
// Kalau [existing] diisi -> mode edit (password boleh dikosongkan).
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/data_options.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../models/admin.dart';
import '../../../services/admin_rules.dart';
import '../../../services/session_service.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/validators.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/square_icon_button.dart';

class AdminFormScreen extends StatefulWidget {
  final Admin? existing;

  const AdminFormScreen({super.key, this.existing});

  @override
  State<AdminFormScreen> createState() => _AdminFormScreenState();
}

class _AdminFormScreenState extends State<AdminFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _username;
  late final TextEditingController _email;
  final _password = TextEditingController();
  final _konfirmasi = TextEditingController();

  late String _role;
  late String _status;
  bool _sembunyikan = true;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nama = TextEditingController(text: e?.nama ?? '');
    _username = TextEditingController(text: e?.username ?? '');
    _email = TextEditingController(text: e?.email ?? '');
    _role = e?.role ?? DataOptions.roleAdmin;
    _status = e?.status ?? DataOptions.statusAktif;
  }

  @override
  void dispose() {
    _nama.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
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

    final repo = AdminRepository.instance;
    final exceptId = widget.existing?.id;

    // ---- Cek username & email belum dipakai ----
    if (await repo.isUsernameTaken(_username.text, exceptId: exceptId)) {
      return _gagal('Username sudah dipakai admin lain.');
    }
    if (await repo.isEmailTaken(_email.text, exceptId: exceptId)) {
      return _gagal('Email sudah dipakai admin lain.');
    }

    try {
      if (_isEdit) {
        // ---- Cek aturan (Super Admin terakhir, akun sendiri, dll) ----
        final larangan = await AdminRules.cekUbah(
          widget.existing!,
          roleBaru: _role,
          statusBaru: _status,
        );
        if (larangan != null) return _gagal(larangan);

        final hasil = await repo.update(
          widget.existing!.copyWith(
            nama: _nama.text,
            username: _username.text,
            email: _email.text,
            role: _role,
            status: _status,
          ),
          newPassword: _password.text,
        );

        // Kalau yang diedit akun sendiri, perbarui data sesi juga.
        if (hasil.id == SessionService.instance.admin?.id) {
          SessionService.instance.startAdmin(hasil);
        }
      } else {
        if (!AdminRules.bolehKelola) {
          return _gagal(AdminRules.pesanBukanSuperAdmin);
        }
        await repo.add(
          nama: _nama.text,
          username: _username.text,
          email: _email.text,
          password: _password.text,
          role: _role,
          status: _status,
        );
      }

      if (!mounted) return;
      AppSnackbar.show(
        context,
        _isEdit ? 'Data admin diperbarui.' : 'Admin berhasil ditambahkan.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      _gagal('Gagal menyimpan: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tombolLihat = SquareIconButton(
      size: 54,
      icon: _sembunyikan
          ? Icons.visibility_outlined
          : Icons.visibility_off_outlined,
      tooltip: _sembunyikan ? 'Tampilkan password' : 'Sembunyikan password',
      onPressed: () => setState(() => _sembunyikan = !_sembunyikan),
    );

    // Bukan Scaffold: halaman ini dibuka di dalam tab admin (Scaffold
    // utama sudah ada di AdminShellScreen), supaya keyboard tidak
    // menggeser halaman dua kali.
    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: _isEdit ? 'Edit Administrator' : 'Tambah Administrator',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 24),

              AppTextField(
                label: 'Nama Lengkap',
                isRequired: true,
                hint: 'Contoh: Budi Santoso',
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                validator: Validators.wajib('Nama'),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Username',
                isRequired: true,
                hint: 'Contoh: budisantoso',
                controller: _username,
                validator: Validators.username,
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Email',
                isRequired: true,
                hint: 'Contoh: budi@gmls.id',
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: _isEdit ? 'Password Baru' : 'Password',
                isRequired: !_isEdit,
                hint: _isEdit
                    ? 'Kosongkan jika tidak diganti'
                    : 'Minimal 8 karakter, huruf dan angka',
                controller: _password,
                obscureText: _sembunyikan,
                validator:
                    _isEdit ? Validators.passwordBaruOptional : Validators.passwordBaru,
                sideAction: tombolLihat,
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Konfirmasi Password',
                isRequired: !_isEdit,
                hint: 'Ulangi password',
                controller: _konfirmasi,
                obscureText: _sembunyikan,
                textInputAction: TextInputAction.done,
                validator: Validators.konfirmasiPassword(() => _password.text),
              ),
              const SizedBox(height: 16),

              AppDropdownField(
                label: 'Role',
                value: _role,
                items: DataOptions.roleAdmins,
                onChanged: (v) => setState(() => _role = v ?? _role),
              ),
              const SizedBox(height: 16),

              AppDropdownField(
                label: 'Status',
                value: _status,
                items: DataOptions.statusAkun,
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
              const SizedBox(height: 28),

              PrimaryButton(
                text: _isEdit ? 'SIMPAN PERUBAHAN' : 'SIMPAN ADMIN',
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
