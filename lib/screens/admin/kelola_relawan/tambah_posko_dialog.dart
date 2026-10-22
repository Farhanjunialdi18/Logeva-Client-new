// ============================================================
// tambah_posko_dialog.dart
// Popup kecil untuk menambah POSKO baru langsung dari form relawan
// (dipakai selama halaman Kelola Posko belum dibuat).
// Hasil: nama posko yang ditambahkan, atau null kalau batal.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/repositories/posko_repository.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/secondary_button.dart';

class TambahPoskoDialog {
  TambahPoskoDialog._();

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierColor: const Color(0xB3000000),
      builder: (_) => const _TambahPoskoView(),
    );
  }
}

class _TambahPoskoView extends StatefulWidget {
  const _TambahPoskoView();

  @override
  State<_TambahPoskoView> createState() => _TambahPoskoViewState();
}

class _TambahPoskoViewState extends State<_TambahPoskoView> {
  final _nama = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nama.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    final nama = _nama.text.trim();
    if (nama.isEmpty) {
      setState(() => _error = 'Nama posko wajib diisi.');
      return;
    }
    setState(() => _saving = true);
    final berhasil = await PoskoRepository.instance.addByName(nama);
    if (!mounted) return;
    if (!berhasil) {
      setState(() {
        _saving = false;
        _error = 'Posko "$nama" sudah ada.';
      });
      return;
    }
    Navigator.of(context).pop(nama);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);

    return Dialog(
      backgroundColor: p.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: p.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tambah Posko', style: AppTextStyles.sectionTitle(p)),
            const SizedBox(height: 16),
            TextField(
              controller: _nama,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              style: AppTextStyles.input(p),
              cursorColor: AppColors.primary,
              onSubmitted: (_) => _simpan(),
              decoration: AppInputDecoration.build(
                p,
                hint: 'Contoh: Desa Panggarangan',
              ).copyWith(errorText: _error),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    text: 'BATAL',
                    height: 50,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _simpan,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('SIMPAN', style: AppTextStyles.button),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
