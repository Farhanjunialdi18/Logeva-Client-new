// ============================================================
// posko_form_screen.dart
// FORM TAMBAH / EDIT POSKO (oleh admin).
// Kapasitas dihitung otomatis dari luas (luas ÷ 3,5 m² per orang),
// sama seperti form Tambah Lokasi di website.
// Hasil pop: posko yang tersimpan (dipakai form relawan untuk
// langsung memilih posko baru), atau null kalau batal.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../data/repositories/posko_repository.dart';
import '../../../models/posko.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/angka.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/validators.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';

class PoskoFormScreen extends StatefulWidget {
  final Posko? existing;

  const PoskoFormScreen({super.key, this.existing});

  @override
  State<PoskoFormScreen> createState() => _PoskoFormScreenState();
}

class _PoskoFormScreenState extends State<PoskoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _desa;
  late final TextEditingController _alamat;
  late final TextEditingController _luas;
  late final TextEditingController _lat;
  late final TextEditingController _lng;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  // Hanya karakter angka, titik, koma, dan minus.
  static final _formatAngka =
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,\-]'));

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nama = TextEditingController(text: e?.nama ?? '');
    _desa = TextEditingController(text: e?.namaDesa ?? '');
    _alamat = TextEditingController(text: e?.alamat ?? '');
    _luas = TextEditingController(
      text: e?.luasLokasi == null ? '' : Angka.tampil(e!.luasLokasi!),
    );
    _lat = TextEditingController(text: e?.latitude ?? '');
    _lng = TextEditingController(text: e?.longitude ?? '');
    _luas.addListener(() => setState(() {})); // perbarui kapasitas
  }

  @override
  void dispose() {
    for (final c in [_nama, _desa, _alamat, _luas, _lat, _lng]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Koordinat disimpan sebagai teks desimal bertitik, contoh -6.9195.
  String _koordinat(TextEditingController c) {
    final n = Angka.bacaKoordinat(c.text);
    return n == null ? '' : n.toString();
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final nama = _nama.text.trim();
    final desa = _desa.text.trim();
    final alamat = _alamat.text.trim();
    final luas = Angka.baca(_luas.text);

    try {
      final Posko hasil;
      if (_isEdit) {
        hasil = widget.existing!.ubahData(
          nama: nama,
          namaDesa: desa,
          alamat: alamat,
          luasLokasi: luas,
          latitude: _koordinat(_lat),
          longitude: _koordinat(_lng),
        );
        await PoskoRepository.instance.update(hasil);
      } else {
        hasil = await PoskoRepository.instance.add(
          Posko.baru(
            nama: nama,
            namaDesa: desa,
            alamat: alamat,
            luasLokasi: luas,
            latitude: _koordinat(_lat),
            longitude: _koordinat(_lng),
          ),
        );
      }
      if (!mounted) return;
      AppSnackbar.show(
        context,
        _isEdit ? 'Data posko diperbarui.' : 'Posko "$nama" ditambahkan.',
      );
      Navigator.of(context).pop(hasil);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final pesan = e is PoskoException ? e.message : 'Gagal menyimpan: $e';
      AppSnackbar.show(context, pesan, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final luas = Angka.baca(_luas.text);
    final kapasitas = Posko.hitungKapasitas(luas);

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: _isEdit ? 'Edit Posko' : 'Tambah Posko',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 24),

              AppTextField(
                label: 'Nama Posko',
                isRequired: true,
                hint: 'Contoh: Posko Balai Desa Panggarangan',
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                validator: Validators.wajib('Nama posko'),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Nama Desa',
                isRequired: true,
                hint: 'Samakan dengan nama desa di website',
                controller: _desa,
                textCapitalization: TextCapitalization.words,
                validator: Validators.wajib('Nama desa'),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Alamat Lokasi',
                isRequired: true,
                hint: 'Contoh: Jl. Raya Panggarangan No. 1',
                controller: _alamat,
                textCapitalization: TextCapitalization.sentences,
                validator: Validators.wajib('Alamat'),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Luas Lokasi (m²)',
                isRequired: true,
                hint: 'Perkiraan luas area terpakai, contoh: 1050',
                controller: _luas,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_formatAngka],
                validator: Validators.luasLokasi,
              ),
              const SizedBox(height: 8),
              Text(
                kapasitas > 0
                    ? 'Kapasitas otomatis: $kapasitas orang '
                        '(luas ÷ 3,5 m² per orang)'
                    : 'Kapasitas dihitung otomatis dari luas '
                        '(luas ÷ 3,5 m² per orang)',
                style: AppTextStyles.small(p),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Latitude',
                hint: 'Contoh: -6.9195',
                controller: _lat,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                inputFormatters: [_formatAngka],
                validator: Validators.latitude,
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Longitude',
                hint: 'Contoh: 106.1297',
                controller: _lng,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                textInputAction: TextInputAction.done,
                inputFormatters: [_formatAngka],
                validator: Validators.longitude,
              ),
              const SizedBox(height: 8),
              Text(
                'Koordinat boleh dikosongkan dulu, tetapi wajib diisi '
                'sebelum mengekspor Paket Data Posko.',
                style: AppTextStyles.small(p).copyWith(color: AppColors.sun),
              ),
              const SizedBox(height: 28),

              PrimaryButton(
                text: _isEdit ? 'SIMPAN PERUBAHAN' : 'SIMPAN POSKO',
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
