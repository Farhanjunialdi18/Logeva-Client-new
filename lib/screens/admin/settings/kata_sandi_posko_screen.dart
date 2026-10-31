// ============================================================
// kata_sandi_posko_screen.dart
// KATA SANDI POSKO: mengunci Paket Data Posko & Cadangan (data pribadi
// pengungsi yang dibawa keluar posko).
//  - HP Induk  : supervisor membuat / mengganti kata sandi.
//  - HP Anggota: hanya melihat status; kata sandi datang dari HP Induk
//    lewat penyiapan / sinkron.
// Pusat (website) mengetik kata sandi ini saat impor paket pertama dari
// posko ini; cadangan di HP pengganti juga meminta kata sandi ini.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/repositories/pengaturan_repository.dart';
import '../../../services/perangkat_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/berkas_terkunci.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';

class KataSandiPoskoScreen extends StatefulWidget {
  const KataSandiPoskoScreen({super.key});

  @override
  State<KataSandiPoskoScreen> createState() => _KataSandiPoskoScreenState();
}

class _KataSandiPoskoScreenState extends State<KataSandiPoskoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _baru = TextEditingController();
  final _ulang = TextEditingController();
  String? _sekarang;
  bool _lihat = false;
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _baru.dispose();
    _ulang.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final k = await PengaturanRepository.instance.kataSandiBerkas();
    if (mounted) setState(() => _sekarang = k);
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    final ganti = (_sekarang ?? '').isNotEmpty;
    final lanjut = await ConfirmDialog.show(
      context,
      title: ganti ? 'Ganti kata sandi posko?' : 'Simpan kata sandi posko?',
      message: 'CATAT kata sandi ini di tempat aman dan berikan ke admin pusat. '
          'Tanpa kata sandi ini, cadangan tidak bisa dipulihkan dan paket tidak '
          'bisa diimpor di website.'
          '${ganti ? ' Paket & cadangan lama tetap memakai kata sandi lama.' : ''}',
      confirmText: 'SIMPAN',
    );
    if (!lanjut || !mounted) return;
    setState(() => _menyimpan = true);
    await PengaturanRepository.instance.setKataSandiBerkas(_baru.text);
    if (!mounted) return;
    _baru.clear();
    _ulang.clear();
    setState(() => _menyimpan = false);
    AppSnackbar.show(context,
        'Kata sandi posko disimpan. HP Anggota menerimanya saat sinkron berikutnya.');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final sekarang = _sekarang;
    final ada = (sekarang ?? '').isNotEmpty;
    final anggota = PerangkatService.isAnggota;

    return Scaffold(
      body: AppBackground(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Kata Sandi Posko',
                subtitle: 'Mengunci paket & cadangan',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 16),
              Text(
                'Paket Data Posko dan cadangan dibawa keluar posko (flashdisk, laptop) '
                'dan berisi data pribadi pengungsi, jadi keduanya dikunci dengan kata '
                'sandi ini. Admin pusat mengetiknya saat impor paket pertama.',
                style: AppTextStyles.small(p),
              ),
              const SizedBox(height: 16),
              if (sekarang == null)
                const Center(child: CircularProgressIndicator())
              else ...[
                InfoCard(
                  title: 'STATUS',
                  rows: {
                    'Kata sandi': ada
                        ? (_lihat ? sekarang : '•' * sekarang.length)
                        : 'Belum diatur',
                    'HP ini': anggota ? 'HP Anggota' : 'HP Induk',
                  },
                  note: ada
                      ? null
                      : anggota
                          ? 'Kata sandi dibuat supervisor di HP Induk dan masuk ke HP '
                              'ini saat sinkron berikutnya.'
                          : 'Paket & cadangan belum bisa dibuat sebelum kata sandi diatur.',
                ),
                if (ada)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _lihat = !_lihat),
                      icon: Icon(_lihat ? Icons.visibility_off : Icons.visibility,
                          size: 18, color: AppColors.primary),
                      label: Text(_lihat ? 'Sembunyikan' : 'Tampilkan',
                          style: const TextStyle(color: AppColors.primary)),
                    ),
                  ),
                if (!anggota) ...[
                  const SizedBox(height: 12),
                  Text(ada ? 'GANTI KATA SANDI' : 'BUAT KATA SANDI',
                      style: AppTextStyles.label(p)),
                  const SizedBox(height: 10),
                  AppTextField(
                    label: 'KATA SANDI BARU',
                    hint: 'Minimal 8 karakter, huruf & angka',
                    controller: _baru,
                    obscureText: true,
                    isRequired: true,
                    validator: BerkasTerkunci.cekKataSandi,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    label: 'ULANGI KATA SANDI',
                    hint: 'Ketik ulang kata sandi',
                    controller: _ulang,
                    obscureText: true,
                    isRequired: true,
                    validator: (v) => v != _baru.text ? 'Kata sandi tidak sama.' : null,
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    text: ada ? 'GANTI KATA SANDI' : 'SIMPAN KATA SANDI',
                    isLoading: _menyimpan,
                    onPressed: _menyimpan ? null : _simpan,
                  ),
                ],
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
