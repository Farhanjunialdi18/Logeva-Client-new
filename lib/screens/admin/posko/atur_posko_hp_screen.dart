// ============================================================
// atur_posko_hp_screen.dart
// ATUR POSKO ANDA (HP Induk, wajib): satu HP admin/supervisor = satu
// posko. Tampil setelah login kalau HP ini belum punya posko, atau berisi
// beberapa posko (misal data uji coba) yang belum dipilih.
//   - belum ada posko : BUAT POSKO, atau AMBIL DARI WEBSITE (paket 1 posko);
//   - beberapa posko  : pilih posko tempat Anda bertugas (posko lain
//                       disembunyikan, datanya tidak dihapus).
// Relawan yang akunnya dibagikan dari HP ini otomatis ikut posko ini.
// Tidak bisa dilewati: pilihannya atur posko atau keluar.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/repositories/pengungsi_repository.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../models/posko.dart';
import '../../../routes/app_routes.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/app_snackbar.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/secondary_button.dart';
import '../paket/paket_data_screen.dart';
import 'posko_form_screen.dart';

class AturPoskoHpScreen extends StatefulWidget {
  const AturPoskoHpScreen({super.key});

  /// Buka halaman ini kalau HP Induk belum punya posko. Hasil: posko HP.
  static Future<void> pastikan(BuildContext context) async {
    if (!await PoskoRepository.instance.perluAturPoskoHp()) return;
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const AturPoskoHpScreen()),
    );
  }

  @override
  State<AturPoskoHpScreen> createState() => _AturPoskoHpScreenState();
}

class _AturPoskoHpScreenState extends State<AturPoskoHpScreen> {
  List<Posko> _semua = [];
  Map<int, int> _jumlahPengungsi = {};
  int? _dipilih;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!await PoskoRepository.instance.perluAturPoskoHp()) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final semua = await PoskoRepository.instance.getAll()
      ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    final jumlah = <int, int>{
      for (final p in semua)
        p.id!: await PengungsiRepository.instance.count(poskoId: p.id),
    };
    if (!mounted) return;
    setState(() {
      _semua = semua;
      _jumlahPengungsi = jumlah;
      _loading = false;
    });
  }

  Future<void> _buka(Widget halaman) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => halaman));
    await _load();
  }

  Future<void> _pakai() async {
    Posko? posko;
    for (final p in _semua) {
      if (p.id == _dipilih) posko = p;
    }
    if (posko == null) return;
    await PoskoRepository.instance.pilihPoskoHp(posko);
    if (!mounted) return;
    AppSnackbar.show(context, 'Posko HP ini: ${posko.nama}.');
    Navigator.of(context).pop();
  }

  void _keluar() {
    SessionService.instance.clear();
    Navigator.of(context, rootNavigator: true)
        .pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final kosong = _semua.isEmpty;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: AppBackground(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.home_work_rounded, size: 48, color: AppColors.primary),
              const SizedBox(height: 16),
              Text('ATUR POSKO ANDA', style: AppTextStyles.pageTitle(p)),
              const SizedBox(height: 8),
              Text(
                kosong
                    ? 'Satu HP admin/supervisor untuk SATU posko. Buat posko tempat '
                        'Anda bertugas, atau ambil dari website (Paket Data Posko, '
                        'ekspor 1 posko). Relawan yang akunnya Anda bagikan '
                        'otomatis bertugas di posko ini.'
                    : 'HP ini berisi ${_semua.length} posko. Satu HP admin/'
                        'supervisor hanya untuk SATU posko: pilih posko tempat Anda '
                        'bertugas. Posko lain disembunyikan (datanya tidak dihapus).',
                style: AppTextStyles.body(p),
              ),
              const SizedBox(height: 24),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (kosong) ...[
                PrimaryButton(
                  text: 'BUAT POSKO',
                  onPressed: () => _buka(const PoskoFormScreen()),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  text: 'AMBIL DARI WEBSITE',
                  icon: Icons.download_rounded,
                  height: 50,
                  onPressed: () => _buka(const PaketDataScreen()),
                ),
              ] else ...[
                RadioGroup<int>(
                  groupValue: _dipilih,
                  onChanged: (v) => setState(() => _dipilih = v),
                  child: Column(
                    children: [
                      for (final posko in _semua)
                        RadioListTile<int>(
                          value: posko.id!,
                          contentPadding: EdgeInsets.zero,
                          title: Text(posko.nama, style: AppTextStyles.cardTitle(p)),
                          subtitle: Text(
                            '${posko.namaDesa.isEmpty ? '-' : 'Desa ${posko.namaDesa}'} · '
                            '${_jumlahPengungsi[posko.id] ?? 0} pengungsi',
                            style: AppTextStyles.small(p),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  text: 'PAKAI POSKO INI',
                  onPressed: _dipilih == null ? null : _pakai,
                ),
              ],
              const SizedBox(height: 12),
              SecondaryButton(
                text: 'KELUAR',
                icon: Icons.logout_rounded,
                height: 50,
                onPressed: _keluar,
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
