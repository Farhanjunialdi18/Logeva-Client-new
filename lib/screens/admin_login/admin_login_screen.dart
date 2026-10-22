// ============================================================
// admin_login_screen.dart
// HALAMAN LOGIN ADMIN: username/email + password.
// ============================================================

import 'package:flutter/material.dart';

import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/back_link.dart';
import '../../widgets/logo_header.dart';
import '../../widgets/offline_badge.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/square_icon_button.dart';
import '../../widgets/theme_toggle_button.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    setState(() => _errorMessage = null);

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);
    final result = await AuthService.instance.loginAdmin(
      _usernameController.text,
      _passwordController.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.adminDashboard,
        (route) => false,
      );
    } else {
      setState(() => _errorMessage = result.message);
    }
  }

  void _forgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Hubungi admin lain atau koordinator GMLS untuk reset password.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      body: AppBackground(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---- Tombol tema ----
              const Align(
                alignment: Alignment.centerRight,
                child: ThemeToggleButton(),
              ),
              const SizedBox(height: 8),

              // ---- Logo ----
              const Center(child: LogoHeader(size: 64, showRibbon: true)),
              const SizedBox(height: 28),

              // ---- Judul ----
              Text('LOGIN ADMIN', style: AppTextStyles.pageTitle(p)),
              const SizedBox(height: 6),
              Text(
                'Masuk menggunakan akun administrator.',
                style: AppTextStyles.body(p),
              ),
              const SizedBox(height: 12),
              const OfflineBadge(),
              const SizedBox(height: 24),

              // ---- Form ----
              AppTextField(
                label: 'USERNAME / EMAIL',
                hint: 'Masukkan username atau email',
                controller: _usernameController,
                keyboardType: TextInputType.emailAddress,
                validator: Validators.usernameOrEmail,
              ),
              const SizedBox(height: 18),
              AppTextField(
                label: 'PASSWORD',
                hint: 'Masukkan password',
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                validator: Validators.password,
                onFieldSubmitted: (_) => _submit(),
                sideAction: SquareIconButton(
                  size: 54,
                  icon: _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  tooltip: _obscurePassword
                      ? 'Tampilkan password'
                      : 'Sembunyikan password',
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),

              // ---- Pesan error login ----
              if (_errorMessage != null) ...[
                const SizedBox(height: 14),
                _ErrorBox(message: _errorMessage!),
              ],

              const SizedBox(height: 24),
              PrimaryButton(
                text: 'MASUK',
                isLoading: _isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 14),
              const BackLink(),
              const SizedBox(height: 20),

              // ---- Lupa password ----
              Center(
                child: TextButton(
                  onPressed: _forgotPassword,
                  style: TextButton.styleFrom(
                    backgroundColor: p.surfaceAlt,
                    foregroundColor: p.textPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: p.border),
                    ),
                  ),
                  child: const Text(
                    'Lupa password?',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kotak merah berisi pesan error.
class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
