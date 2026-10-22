// ============================================================
// relawan_login_screen.dart
// HALAMAN LOGIN RELAWAN: cukup memasukkan PIN 6 digit.
// ============================================================

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '../../core/app_constants.dart';
import '../../routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/validators.dart';
import '../../widgets/app_background.dart';
import '../../widgets/back_link.dart';
import '../../widgets/logo_header.dart';
import '../../widgets/pin_dots.dart';
import '../../widgets/pin_keypad.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/theme_toggle_button.dart';

class RelawanLoginScreen extends StatefulWidget {
  const RelawanLoginScreen({super.key});

  @override
  State<RelawanLoginScreen> createState() => _RelawanLoginScreenState();
}

class _RelawanLoginScreenState extends State<RelawanLoginScreen> {
  String _pin = '';
  bool _isLoading = false;
  String? _errorMessage;

  void _addDigit(String digit) {
    if (_isLoading || _pin.length >= AppConstants.pinLength) return;
    setState(() {
      _pin += digit;
      _errorMessage = null;
    });
  }

  void _removeDigit() {
    if (_isLoading || _pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    final invalid = Validators.pin(_pin);
    if (invalid != null) {
      setState(() => _errorMessage = invalid);
      return;
    }

    setState(() => _isLoading = true);
    final result = await AuthService.instance.loginRelawan(_pin);
    if (!mounted) return;

    if (result.success) {
      setState(() => _isLoading = false);
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.relawanHome,
        (route) => false,
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Scaffold(
      body: AppBackground(
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
            const SizedBox(height: 24),

            // ---- Judul ----
            Text('Login Relawan', style: AppTextStyles.pageTitle(p)),
            const SizedBox(height: 6),
            Text(
              'Masukkan PIN yang diberikan oleh koordinator.',
              style: AppTextStyles.body(p),
            ),
            const SizedBox(height: 16),

            // ---- Kartu PIN ----
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: p.border),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  PinDots(
                    length: AppConstants.pinLength,
                    filled: _pin.length,
                    hasError: _errorMessage != null,
                  ),
                  SizedBox(
                    height: 32,
                    child: Center(
                      child: _errorMessage == null
                          ? null
                          : Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12,
                              ),
                            ),
                    ),
                  ),
                  PinKeypad(onDigit: _addDigit, onBackspace: _removeDigit),
                  const SizedBox(height: 8),
                  PrimaryButton(
                    text: 'MASUK',
                    isLoading: _isLoading,
                    onPressed:
                        _pin.length == AppConstants.pinLength ? _submit : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const BackLink(),

            // ---- PIN demo (hanya muncul saat mode debug) ----
            if (kDebugMode) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Demo PIN: ${AuthService.demoRelawanPin}',
                  style: AppTextStyles.small(p),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
