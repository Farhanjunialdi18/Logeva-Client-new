// ============================================================
// logistik_form_screen.dart
// FORM TAMBAH / EDIT LOGISTIK.
// Kalau [existing] diisi -> mode edit.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data_options.dart';
import '../../../data/repositories/logistik_repository.dart';
import '../../../models/logistik.dart';
import '../../../services/session_service.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/validators.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';

class LogistikFormScreen extends StatefulWidget {
  final Logistik? existing;

  const LogistikFormScreen({super.key, this.existing});

  @override
  State<LogistikFormScreen> createState() => _LogistikFormScreenState();
}

class _LogistikFormScreenState extends State<LogistikFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _jumlah;
  late final TextEditingController _posko;

  String? _kategori;
  String? _satuan;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nama = TextEditingController(text: e?.namaBarang ?? '');
    _jumlah = TextEditingController(text: e == null ? '' : '${e.jumlah}');
    _posko = TextEditingController(
      text: e?.posko ?? SessionService.instance.relawan?.posko ?? '',
    );
    _kategori = e?.kategori;
    _satuan = e?.satuan;
  }

  @override
  void dispose() {
    _nama.dispose();
    _jumlah.dispose();
    _posko.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);

    final data = Logistik(
      id: widget.existing?.id,
      namaBarang: _nama.text.trim(),
      kategori: _kategori!,
      jumlah: int.parse(_jumlah.text.trim()),
      satuan: _satuan!,
      posko: _posko.text.trim(),
      dibuatPada: widget.existing?.dibuatPada ?? DateTime.now(),
    );

    try {
      if (_isEdit) {
        await LogistikRepository.instance.update(data);
      } else {
        await LogistikRepository.instance.add(data);
      }
      if (!mounted) return;
      AppSnackbar.show(
        context,
        _isEdit ? 'Data logistik diperbarui.' : 'Logistik berhasil ditambahkan.',
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
    return Scaffold(
      body: AppBackground(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: _isEdit ? 'Edit Logistik' : 'Tambah Logistik',
                subtitle: 'Data disimpan di perangkat (offline).',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 24),

              AppTextField(
                label: 'NAMA BARANG',
                hint: 'Contoh: Air Mineral',
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                validator: Validators.wajib('Nama barang'),
              ),
              const SizedBox(height: 16),

              AppDropdownField(
                label: 'KATEGORI',
                hint: 'Pilih kategori',
                value: _kategori,
                items: DataOptions.kategoriLogistik,
                onChanged: (v) => setState(() => _kategori = v),
                validator: Validators.wajib('Kategori'),
              ),
              const SizedBox(height: 16),

              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      label: 'JUMLAH',
                      hint: 'Contoh: 50',
                      controller: _jumlah,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(7),
                      ],
                      validator: Validators.jumlah,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppDropdownField(
                      label: 'SATUAN',
                      hint: 'Pilih',
                      value: _satuan,
                      items: DataOptions.satuanLogistik,
                      onChanged: (v) => setState(() => _satuan = v),
                      validator: Validators.wajib('Satuan'),
                    ),
                  ),
                ],
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
