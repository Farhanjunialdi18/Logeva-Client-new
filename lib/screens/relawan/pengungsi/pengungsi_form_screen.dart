// ============================================================
// pengungsi_form_screen.dart
// FORM TAMBAH / EDIT PENGUNGSI.
// Kalau [existing] diisi -> mode edit.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data_options.dart';
import '../../../data/repositories/pengungsi_repository.dart';
import '../../../models/pengungsi.dart';
import '../../../services/session_service.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/validators.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/segmented_choice.dart';

class PengungsiFormScreen extends StatefulWidget {
  final Pengungsi? existing;

  const PengungsiFormScreen({super.key, this.existing});

  @override
  State<PengungsiFormScreen> createState() => _PengungsiFormScreenState();
}

class _PengungsiFormScreenState extends State<PengungsiFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _nik;
  late final TextEditingController _usia;
  late final TextEditingController _domisili;
  late final TextEditingController _posko;

  String _jenisKelamin = 'L';
  String? _kondisi;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nama = TextEditingController(text: e?.nama ?? '');
    _nik = TextEditingController(text: e?.nik ?? '');
    _usia = TextEditingController(text: e == null ? '' : '${e.usia}');
    _domisili = TextEditingController(text: e?.domisili ?? '');
    _posko = TextEditingController(
      text: e?.posko ?? SessionService.instance.relawan?.posko ?? '',
    );
    _jenisKelamin = e?.jenisKelamin ?? 'L';
    _kondisi = e?.kondisi ?? DataOptions.kondisiPengungsi.first;
  }

  @override
  void dispose() {
    _nama.dispose();
    _nik.dispose();
    _usia.dispose();
    _domisili.dispose();
    _posko.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final data = Pengungsi(
      id: widget.existing?.id,
      nama: _nama.text.trim(),
      nik: _nik.text.trim(),
      jenisKelamin: _jenisKelamin,
      usia: int.parse(_usia.text.trim()),
      kondisi: _kondisi ?? DataOptions.kondisiPengungsi.first,
      domisili: _domisili.text.trim(),
      posko: _posko.text.trim(),
      dibuatPada: widget.existing?.dibuatPada ?? DateTime.now(),
    );

    try {
      if (_isEdit) {
        await PengungsiRepository.instance.update(data);
      } else {
        await PengungsiRepository.instance.add(data);
      }
      if (!mounted) return;
      AppSnackbar.show(
        context,
        _isEdit ? 'Data pengungsi diperbarui.' : 'Pengungsi berhasil ditambahkan.',
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.show(context, 'Gagal menyimpan: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final angkaSaja = [FilteringTextInputFormatter.digitsOnly];

    return Scaffold(
      body: AppBackground(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: _isEdit ? 'Edit Pengungsi' : 'Tambah Pengungsi',
                subtitle: 'Data disimpan di perangkat (offline).',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 24),

              AppTextField(
                label: 'NAMA LENGKAP',
                hint: 'Contoh: Ahmad Saputra',
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                validator: Validators.wajib('Nama'),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'NIK (OPSIONAL)',
                hint: '16 digit NIK',
                controller: _nik,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  ...angkaSaja,
                  LengthLimitingTextInputFormatter(16),
                ],
                validator: Validators.nikOptional,
              ),
              const SizedBox(height: 16),

              SegmentedChoice(
                label: 'JENIS KELAMIN',
                options: const {'L': 'Laki-laki', 'P': 'Perempuan'},
                selected: _jenisKelamin,
                onChanged: (v) => setState(() => _jenisKelamin = v),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'USIA (TAHUN)',
                hint: 'Contoh: 35',
                controller: _usia,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  ...angkaSaja,
                  LengthLimitingTextInputFormatter(3),
                ],
                validator: Validators.usia,
              ),
              const SizedBox(height: 16),

              AppDropdownField(
                label: 'KONDISI',
                value: _kondisi,
                items: DataOptions.kondisiPengungsi,
                onChanged: (v) => setState(() => _kondisi = v),
                validator: Validators.wajib('Kondisi'),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'DOMISILI',
                hint: 'Contoh: Desa Panggarangan',
                controller: _domisili,
                textCapitalization: TextCapitalization.words,
                validator: Validators.wajib('Domisili'),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'POSKO',
                hint: 'Nama posko',
                controller: _posko,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                validator: Validators.wajib('Posko'),
              ),
              const SizedBox(height: 28),

              PrimaryButton(
                text: _isEdit ? 'SIMPAN PERUBAHAN' : 'SIMPAN',
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
