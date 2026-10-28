// ============================================================
// barang_form_screen.dart
// FORM TAMBAH / EDIT MASTER BARANG (admin). Kolom sama dengan Master
// Logistik website: nama item, kategori, satuan, kebutuhan harian
// (per orang per hari), deskripsi. Mode edit: ada tombol HAPUS.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data_options.dart';
import '../../../data/repositories/barang_repository.dart';
import '../../../models/barang.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/angka.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/validators.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/secondary_button.dart';

class BarangFormScreen extends StatefulWidget {
  final Barang? existing;

  const BarangFormScreen({super.key, this.existing});

  @override
  State<BarangFormScreen> createState() => _BarangFormScreenState();
}

class _BarangFormScreenState extends State<BarangFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _kebutuhan;
  late final TextEditingController _deskripsi;

  List<KategoriLogistik> _kategori = [];
  int? _kategoriId;
  String? _satuan;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  /// Semua barang di HP ini, untuk peringatan nama mirip (barang ganda).
  List<Barang> _semuaBarang = [];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nama = TextEditingController(text: e?.namaItem ?? '');
    _kebutuhan = TextEditingController(
      text: e?.kebutuhanHarian == null ? '' : Angka.tampil(e!.kebutuhanHarian!),
    );
    _deskripsi = TextEditingController(text: e?.deskripsi ?? '');
    _kategoriId = e?.kategoriId;
    _satuan = e?.satuan;
    _nama.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    final kategori = await BarangRepository.instance.getKategori();
    final barang = await BarangRepository.instance.getAll();
    if (!mounted) return;
    setState(() {
      _kategori = kategori;
      _semuaBarang = barang;
    });
  }

  static String _rapi(String s) =>
      s.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  /// Peringatan supaya tidak membuat barang ganda dengan nama berbeda
  /// (master pusat & HP lain memakai nama yang sama persis).
  String? get _peringatanNama {
    final nama = _rapi(_nama.text);
    if (_isEdit || nama.length < 3) return null;
    final baku = DataOptions.namaBakuBarang(_nama.text);
    if (baku != _nama.text) {
      return '"${_nama.text.trim()}" sudah digabung ke "$baku" di pusat. Pakai barang "$baku".';
    }
    if (_semuaBarang.any((b) => _rapi(b.namaItem) == nama)) return null; // dicek saat simpan
    final kata = nama.split(' ').where((k) => k.length >= 3).toSet();
    final mirip = _semuaBarang
        .where((b) {
          final n = _rapi(b.namaItem);
          return n.contains(nama) || nama.contains(n) || n.split(' ').any(kata.contains);
        })
        .map((b) => b.namaItem)
        .take(4)
        .toList();
    final dariPusat = DataOptions.barangAwal.any((e) => _rapi(e.$1) == nama);
    if (mirip.isNotEmpty) {
      return 'Mirip barang yang sudah ada: ${mirip.join(', ')}. Kalau barangnya sama, '
          'pakai barang itu supaya tidak tercatat ganda di pusat.';
    }
    return dariPusat
        ? null
        : 'Barang ini belum ada di Master Logistik pusat. Pastikan nama & satuannya '
            'sesuai, karena di pusat akan dicatat sebagai barang baru.';
  }

  @override
  void dispose() {
    _nama.dispose();
    _kebutuhan.dispose();
    _deskripsi.dispose();
    super.dispose();
  }

  static String? _cekKebutuhan(String? value) {
    if ((value ?? '').trim().isEmpty) return null;
    final n = Angka.baca(value);
    if (n == null) return 'Harus berupa angka, contoh: 0,3';
    if (n < 0) return 'Tidak boleh negatif.';
    return null;
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);

    final n = Angka.baca(_kebutuhan.text);
    final kebutuhan = n == null ? null : (n * 100).roundToDouble() / 100;
    try {
      if (_isEdit) {
        await BarangRepository.instance.update(widget.existing!.ubahData(
          kategoriId: _kategoriId!,
          namaItem: _nama.text.trim(),
          satuan: _satuan!,
          kebutuhanHarian: kebutuhan,
          deskripsi: _deskripsi.text.trim(),
        ));
      } else {
        await BarangRepository.instance.add(Barang.baru(
          kategoriId: _kategoriId!,
          namaItem: _nama.text.trim(),
          satuan: _satuan!,
          kebutuhanHarian: kebutuhan,
          deskripsi: _deskripsi.text.trim(),
        ));
      }
      if (!mounted) return;
      AppSnackbar.show(
          context, _isEdit ? 'Barang diperbarui.' : 'Barang ditambahkan.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final pesan = e is BarangException ? e.message : 'Gagal menyimpan: $e';
      AppSnackbar.show(context, pesan, isError: true);
    }
  }

  Future<void> _hapus() async {
    final barang = widget.existing!;
    final alasan = await BarangRepository.instance.cekHapus(barang);
    if (!mounted) return;
    if (alasan != null) {
      AppSnackbar.show(context, 'Barang tidak bisa dihapus. $alasan',
          isError: true);
      return;
    }
    final yakin = await ConfirmDialog.show(
      context,
      title: 'Hapus barang?',
      message: '${barang.namaItem} akan dihapus dari master barang.',
      confirmText: 'HAPUS',
    );
    if (!yakin || !mounted) return;
    try {
      await BarangRepository.instance.delete(barang.id!);
    } on BarangException catch (e) {
      if (mounted) AppSnackbar.show(context, 'Barang tidak bisa dihapus. $e', isError: true);
      return;
    }
    if (!mounted) return;
    AppSnackbar.show(context, 'Barang dihapus.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    String? namaKategori;
    for (final k in _kategori) {
      if (k.id == _kategoriId) namaKategori = k.nama;
    }

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: _isEdit ? 'Edit Barang' : 'Tambah Barang',
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 24),

              AppTextField(
                label: 'NAMA ITEM',
                isRequired: true,
                hint: 'Samakan dengan Master Logistik website',
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                validator: Validators.wajib('Nama item'),
              ),
              if (_peringatanNama != null) ...[
                const SizedBox(height: 8),
                Text(
                  '⚠ $_peringatanNama',
                  style: AppTextStyles.small(p).copyWith(color: AppColors.sun),
                ),
              ],
              const SizedBox(height: 16),

              AppDropdownField(
                label: 'KATEGORI *',
                value: namaKategori,
                items: _kategori.map((k) => k.nama).toList(),
                hint: 'Pilih kategori',
                onChanged: (v) => setState(() {
                  for (final k in _kategori) {
                    if (k.nama == v) _kategoriId = k.id;
                  }
                }),
                validator: (v) => v == null ? 'Kategori wajib dipilih.' : null,
              ),
              const SizedBox(height: 16),

              AppDropdownField(
                label: 'SATUAN *',
                value: _satuan,
                items: DataOptions.satuanLogistik,
                hint: 'Pilih satuan',
                onChanged: (v) => setState(() => _satuan = v),
                validator: (v) => v == null ? 'Satuan wajib dipilih.' : null,
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'KEBUTUHAN PER ORANG PER HARI'
                    '${_satuan == null ? '' : ' ($_satuan)'}',
                hint: 'Contoh: 0,3. Kosongkan kalau tidak dihitung',
                controller: _kebutuhan,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: _cekKebutuhan,
              ),
              const SizedBox(height: 8),
              Text(
                'Barang yang punya kebutuhan harian (barang pokok) ikut '
                'dihitung di kebutuhan bantuan posko.',
                style: AppTextStyles.small(p),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'DESKRIPSI',
                hint: 'Opsional',
                controller: _deskripsi,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 28),

              PrimaryButton(
                text: _isEdit ? 'SIMPAN PERUBAHAN' : 'SIMPAN BARANG',
                isLoading: _saving,
                onPressed: _simpan,
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                SecondaryButton(
                  text: 'HAPUS BARANG',
                  icon: Icons.delete_outline_rounded,
                  height: 54,
                  onPressed: _hapus,
                ),
                const SizedBox(height: 8),
                Text(
                  'Barang yang sudah punya catatan masuk/keluar, atau termasuk '
                  'Master Logistik pusat, tidak bisa dihapus (catatan & stok '
                  'tidak boleh hilang).',
                  style: AppTextStyles.small(p).copyWith(color: AppColors.sun),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
