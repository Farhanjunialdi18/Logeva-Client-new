// ============================================================
// relawan_akun_form_screen.dart
// FORM TAMBAH / EDIT AKUN RELAWAN (oleh admin).
// - Mode tambah: PIN dibuat otomatis + tombol GENERATE PIN BARU.
// - Mode edit  : PIN tidak diubah di sini (pakai tombol di Detail Relawan).
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/data_options.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../data/repositories/relawan_repository.dart';
import '../../../models/relawan.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/validators.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/pin_card.dart';
import '../../../widgets/primary_button.dart';
import 'tambah_posko_dialog.dart';

class RelawanAkunFormScreen extends StatefulWidget {
  final Relawan? existing;

  const RelawanAkunFormScreen({super.key, this.existing});

  @override
  State<RelawanAkunFormScreen> createState() => _RelawanAkunFormScreenState();
}

class _RelawanAkunFormScreenState extends State<RelawanAkunFormScreen> {
  // Pilihan khusus di dropdown posko
  static const String _belumDitempatkan = 'Belum ditempatkan';
  static const String _tambahPoskoBaru = '+ Tambah posko baru';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _kontak;

  List<String> _daftarPosko = [];
  String _posko = _belumDitempatkan;
  late String _status;
  String? _pin;

  // Dinaikkan setiap daftar posko berubah, supaya dropdown dibuat ulang.
  int _poskoVersion = 0;
  bool _generating = false;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nama = TextEditingController(text: e?.nama ?? '');
    _kontak = TextEditingController(text: e?.kontak ?? '');
    _status = e?.status ?? DataOptions.statusAktif;
    if (e != null && e.sudahDitempatkan) _posko = e.posko;

    _loadPosko();
    if (!_isEdit) {
      // Jangan pakai setState di initState: set langsung, lalu buat PIN.
      _generating = true;
      _buatPin();
    }
  }

  @override
  void dispose() {
    _nama.dispose();
    _kontak.dispose();
    super.dispose();
  }

  Future<void> _loadPosko({String? pilih}) async {
    final names = await PoskoRepository.instance.getNames();
    if (!mounted) return;
    setState(() {
      _daftarPosko = names;
      // Saat tambah baru & posko sudah ada, pilih posko pertama otomatis.
      if (pilih != null) {
        _posko = pilih;
      } else if (!_isEdit && _posko == _belumDitempatkan && names.isNotEmpty) {
        _posko = names.first;
      }
      _poskoVersion++;
    });
  }

  /// Tombol GENERATE PIN BARU ditekan.
  Future<void> _generatePin() async {
    setState(() => _generating = true);
    await _buatPin();
  }

  Future<void> _buatPin() async {
    final pin = await RelawanRepository.instance.generateUniquePin(except: _pin);
    if (!mounted) return;
    setState(() {
      _pin = pin;
      _generating = false;
    });
  }

  Future<void> _pilihPosko(String? value) async {
    if (value != _tambahPoskoBaru) {
      setState(() => _posko = value ?? _belumDitempatkan);
      return;
    }
    // Pilih "+ Tambah posko baru" -> buka popup, lalu pilih posko barunya.
    final baru = await TambahPoskoDialog.show(context);
    if (!mounted) return;
    if (baru == null) {
      setState(() => _poskoVersion++); // kembalikan pilihan sebelumnya
      return;
    }
    AppSnackbar.show(context, 'Posko "$baru" ditambahkan.');
    await _loadPosko(pilih: baru);
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_isEdit && _pin == null) return; // PIN belum selesai dibuat

    setState(() => _saving = true);
    final posko = _posko == _belumDitempatkan ? '' : _posko;

    try {
      String pesan;
      if (_isEdit) {
        await RelawanRepository.instance.update(
          widget.existing!.copyWith(
            nama: _nama.text.trim(),
            kontak: _kontak.text.trim(),
            posko: posko,
            status: _status,
          ),
        );
        pesan = 'Data relawan diperbarui.';
      } else {
        final hasil = await RelawanRepository.instance.add(
          Relawan(
            nama: _nama.text.trim(),
            kontak: _kontak.text.trim(),
            pin: _pin!,
            posko: posko,
            status: _status,
            dibuatPada: DateTime.now(),
          ),
        );
        pesan = 'Relawan ditambahkan. PIN login: ${hasil.pin}';
      }

      if (!mounted) return;
      AppSnackbar.show(context, pesan);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.show(context, 'Gagal menyimpan: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bukan Scaffold: halaman ini dibuka di dalam tab admin (Scaffold
    // utama sudah ada di AdminShellScreen), supaya keyboard tidak
    // menggeser halaman dua kali.
    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: _isEdit ? 'Edit Relawan' : 'Tambah Relawan',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 24),

              AppTextField(
                label: 'Nama Lengkap',
                isRequired: true,
                hint: 'Contoh: Andi Saputra',
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                validator: Validators.wajib('Nama'),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'Email / Kontak',
                isRequired: true,
                hint: 'Email atau nomor HP',
                controller: _kontak,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                validator: Validators.wajib('Email / kontak'),
              ),
              const SizedBox(height: 16),

              AppDropdownField(
                key: ValueKey('posko-$_poskoVersion'),
                label: 'Posko',
                value: _posko,
                items: [_belumDitempatkan, ..._daftarPosko, _tambahPoskoBaru],
                onChanged: _pilihPosko,
              ),
              const SizedBox(height: 16),

              AppDropdownField(
                label: 'Status',
                value: _status,
                items: DataOptions.statusAkun,
                onChanged: (v) => setState(() => _status = v ?? _status),
              ),
              const SizedBox(height: 16),

              if (!_isEdit) ...[
                PinCard(
                  pin: _pin,
                  isGenerating: _generating,
                  onGenerate: _generatePin,
                ),
                const SizedBox(height: 28),
              ] else
                const SizedBox(height: 12),

              PrimaryButton(
                text: _isEdit ? 'SIMPAN PERUBAHAN' : 'SIMPAN RELAWAN',
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
