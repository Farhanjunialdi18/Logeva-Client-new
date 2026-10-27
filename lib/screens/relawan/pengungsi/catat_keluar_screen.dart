// ============================================================
// catat_keluar_screen.dart
// CATAT PENGUNGSI KELUAR POSKO: pulang ke rumah, pindah ke posko lain,
// atau dirujuk ke RS/Puskesmas. Data TIDAK dihapus (riwayat tetap ada
// dan ikut terkirim ke pusat), tapi tidak lagi dihitung untuk kapasitas
// & kebutuhan posko.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/data_options.dart';
import '../../../data/repositories/pengungsi_repository.dart';
import '../../../models/pengungsi.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/waktu_wib.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/tanggal_field.dart';

class CatatKeluarScreen extends StatefulWidget {
  final Pengungsi pengungsi;

  const CatatKeluarScreen({super.key, required this.pengungsi});

  @override
  State<CatatKeluarScreen> createState() => _CatatKeluarScreenState();
}

class _CatatKeluarScreenState extends State<CatatKeluarScreen> {
  final _formKey = GlobalKey<FormState>();
  final _keterangan = TextEditingController();
  String _status = DataOptions.pulang;
  DateTime? _tanggal = WaktuWib.hariIni();
  bool _menyimpan = false;

  /// Pilihan selain "di posko": label -> nilai.
  static final Map<String, String> _pilihan = {
    for (final e in DataOptions.statusKeberadaan.entries)
      if (e.key != DataOptions.diPosko) e.value: e.key,
  };

  String get _petunjuk => switch (_status) {
        DataOptions.pindah => 'Contoh: Posko SDN 2 Panggarangan',
        DataOptions.dirujuk => 'Contoh: RSUD Pandeglang',
        _ => 'Contoh: rumah sudah aman ditempati',
      };

  @override
  void dispose() {
    _keterangan.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _menyimpan = true);
    await PengungsiRepository.instance.update(
        widget.pengungsi.catatKeluar(_status, _tanggal!, _keterangan.text));
    if (!mounted) return;
    AppSnackbar.show(context,
        '${widget.pengungsi.nama}: ${DataOptions.statusKeberadaan[_status]}.');
    Navigator.of(context).pop();
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
              PageHeader(
                title: 'Keluar dari Posko',
                subtitle: widget.pengungsi.nama,
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 16),
              Text(
                'Data tidak dihapus dan tetap terkirim ke pusat, tetapi tidak lagi '
                'dihitung untuk kapasitas dan kebutuhan posko.',
                style: AppTextStyles.small(p),
              ),
              const SizedBox(height: 20),
              AppDropdownField(
                label: 'KELUAR KARENA *',
                value: DataOptions.statusKeberadaan[_status],
                items: _pilihan.keys.toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _status = _pilihan[v]!);
                },
              ),
              const SizedBox(height: 18),
              TanggalField(
                label: 'Tanggal keluar',
                value: _tanggal,
                firstDate: widget.pengungsi.dibuatPada.subtract(const Duration(days: 1)),
                onChanged: (v) => setState(() => _tanggal = v),
                validator: (v) => v == null
                    ? 'Tanggal keluar wajib diisi.'
                    : v.isAfter(WaktuWib.hariIni())
                        ? 'Tanggal tidak boleh setelah hari ini.'
                        : null,
              ),
              const SizedBox(height: 18),
              AppTextField(
                label: _status == DataOptions.pindah
                    ? 'POSKO TUJUAN'
                    : _status == DataOptions.dirujuk
                        ? 'RUMAH SAKIT / PUSKESMAS'
                        : 'KETERANGAN',
                hint: _petunjuk,
                controller: _keterangan,
                textCapitalization: TextCapitalization.sentences,
                isRequired: _status != DataOptions.pulang,
                validator: (v) => _status != DataOptions.pulang &&
                        (v ?? '').trim().isEmpty
                    ? 'Wajib diisi supaya pusat tahu ke mana pengungsi pergi.'
                    : null,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                text: 'SIMPAN',
                isLoading: _menyimpan,
                onPressed: _menyimpan ? null : _simpan,
              ),
              const SizedBox(height: 10),
              Text(
                'Kalau batal keluar, buka lagi data ini lalu pilih KEMBALI KE POSKO.',
                style: AppTextStyles.small(p).copyWith(color: AppColors.accentBlue),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
