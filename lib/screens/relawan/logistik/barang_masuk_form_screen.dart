// ============================================================
// barang_masuk_form_screen.dart
// FORM CATAT BARANG MASUK (menambah stok posko). Aturan sama dengan
// website: jumlah >= 1, sumber bantuan wajib, tanggal <= hari ini.
// Catatan tidak bisa diedit setelah disimpan.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/repositories/barang_repository.dart';
import '../../../data/repositories/logistik_repository.dart';
import '../../../models/barang.dart';
import '../../../models/catatan_logistik.dart';
import '../../../models/posko.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_text_styles.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/validators.dart';
import '../../../utils/waktu_wib.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/tanggal_field.dart';

/// Label barang di dropdown, contoh "Beras (kg) · Makanan".
String labelBarang(Barang b) => '${b.namaItem} (${b.satuan}) · ${b.kategori}';

class BarangMasukFormScreen extends StatefulWidget {
  final Posko posko;

  const BarangMasukFormScreen({super.key, required this.posko});

  @override
  State<BarangMasukFormScreen> createState() => _BarangMasukFormScreenState();
}

class _BarangMasukFormScreenState extends State<BarangMasukFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlah = TextEditingController();
  final _sumber = TextEditingController();
  final _keterangan = TextEditingController();

  List<Barang> _daftarBarang = [];
  Barang? _barang;
  DateTime? _tanggal = WaktuWib.hariIni();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await BarangRepository.instance.getAll();
    if (!mounted) return;
    setState(() => _daftarBarang = list);
  }

  @override
  void dispose() {
    _jumlah.dispose();
    _sumber.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final data = BarangMasuk.baru(
      poskoId: widget.posko.id!,
      barang: _barang!,
      jumlah: int.parse(_jumlah.text.trim()),
      sumberBantuan: _sumber.text.trim(),
      tanggal: _tanggal!,
      keterangan: _keterangan.text.trim(),
      dicatatOleh: SessionService.instance.namaPencatat,
    );

    try {
      await LogistikRepository.instance.catatMasuk(data);
      if (!mounted) return;
      AppSnackbar.show(context, 'Barang masuk dicatat, stok bertambah.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final pesan = e is LogistikException ? e.message : 'Gagal menyimpan: $e';
      AppSnackbar.show(context, pesan, isError: true);
    }
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
                title: 'Barang Masuk',
                subtitle: widget.posko.label,
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 24),

              AppDropdownField(
                label: 'BARANG *',
                value: _barang == null ? null : labelBarang(_barang!),
                items: _daftarBarang.map(labelBarang).toList(),
                hint: 'Pilih barang',
                onChanged: (v) => setState(() {
                  for (final b in _daftarBarang) {
                    if (labelBarang(b) == v) _barang = b;
                  }
                }),
                validator: (v) => v == null ? 'Pilih barang yang masuk.' : null,
              ),
              const SizedBox(height: 8),
              Text(
                'Barang tidak ada di daftar? Minta admin menambahkannya di '
                'Master Barang.',
                style: AppTextStyles.small(p),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'JUMLAH${_barang == null ? '' : ' (${_barang!.satuan})'}',
                isRequired: true,
                hint: 'Contoh: 25',
                controller: _jumlah,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: Validators.jumlah,
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'SUMBER BANTUAN',
                isRequired: true,
                hint: 'Contoh: BNPB, BPBD, nama donatur',
                controller: _sumber,
                textCapitalization: TextCapitalization.words,
                validator: Validators.wajib('Sumber bantuan'),
              ),
              const SizedBox(height: 16),

              TanggalField(
                label: 'Tanggal masuk',
                value: _tanggal,
                onChanged: (v) => setState(() => _tanggal = v),
                validator: (v) =>
                    v == null ? 'Tanggal masuk wajib diisi.' : null,
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'KETERANGAN',
                hint: 'Opsional',
                controller: _keterangan,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              Text(
                'Catatan tidak bisa diubah setelah disimpan. Periksa lagi '
                'jumlahnya sebelum menyimpan.',
                style: AppTextStyles.small(p).copyWith(color: AppColors.sun),
              ),
              const SizedBox(height: 24),

              PrimaryButton(
                text: 'SIMPAN BARANG MASUK',
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
