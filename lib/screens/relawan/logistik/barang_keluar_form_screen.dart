// ============================================================
// barang_keluar_form_screen.dart
// FORM CATAT BARANG KELUAR (mengurangi stok posko). Aturan sama dengan
// website: hanya barang yang masih ada stoknya, jumlah <= sisa stok,
// tujuan dipilih dari daftar tetap, tanggal <= hari ini.
// Koreksi catatan yang salah juga lewat form ini (tujuan "Lainnya").
//
// HP Anggota: semua barang bisa dipilih dan jumlah boleh melebihi stok
// di HP ini (dengan konfirmasi), karena barang masuknya mungkin dicatat
// di HP lain dan belum disinkron. Stok minus ditandai untuk dicek.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data_options.dart';
import '../../../data/repositories/logistik_repository.dart';
import '../../../models/catatan_logistik.dart';
import '../../../models/posko.dart';
import '../../../services/perangkat_service.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/validators.dart';
import '../../../utils/waktu_wib.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/tanggal_field.dart';
import 'barang_masuk_form_screen.dart' show labelBarang;

class BarangKeluarFormScreen extends StatefulWidget {
  final Posko posko;

  const BarangKeluarFormScreen({super.key, required this.posko});

  @override
  State<BarangKeluarFormScreen> createState() => _BarangKeluarFormScreenState();
}

class _BarangKeluarFormScreenState extends State<BarangKeluarFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _jumlah = TextEditingController();
  final _penerima = TextEditingController();
  final _keterangan = TextEditingController();

  List<StokBarang> _stok = [];
  bool _loading = true;
  StokBarang? _pilihan;
  String? _tujuan;
  DateTime? _tanggal = WaktuWib.hariIni();
  bool _saving = false;

  bool get _anggota => PerangkatService.isAnggota;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final stok = await LogistikRepository.instance
        .getStok(widget.posko.id, semuaBarang: _anggota);
    if (!mounted) return;
    setState(() {
      _stok = _anggota ? stok : stok.where((s) => s.jumlah > 0).toList();
      _loading = false;
    });
  }

  @override
  void dispose() {
    _jumlah.dispose();
    _penerima.dispose();
    _keterangan.dispose();
    super.dispose();
  }

  String? _cekJumlah(String? value) {
    final umum = Validators.jumlah(value);
    if (umum != null || _anggota) return umum; // HP Anggota: konfirmasi saat simpan
    final sisa = _pilihan?.jumlah ?? 0;
    if (int.parse(value!.trim()) > sisa) {
      return 'Stok tidak cukup. Sisa stok hanya $sisa '
          '${_pilihan?.barang.satuan ?? ''}.';
    }
    return null;
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final jumlah = int.parse(_jumlah.text.trim());
    final sisa = _pilihan!.jumlah;
    final melebihi = jumlah > sisa;
    if (melebihi) {
      final lanjut = await ConfirmDialog.show(
        context,
        title: 'Melebihi stok di HP ini',
        message: 'Stok ${_pilihan!.barang.namaItem} yang tercatat di HP ini '
            '$sisa ${_pilihan!.barang.satuan}. Mungkin barang masuknya dicatat '
            'di HP lain dan belum disinkron. Tetap catat? Stok akan ditandai '
            'minus sampai disinkron & dicek supervisor.',
        confirmText: 'TETAP CATAT',
      );
      if (!lanjut || !mounted) return;
    }
    setState(() => _saving = true);

    final barang = _pilihan!.barang;
    final data = BarangKeluar.baru(
      poskoId: widget.posko.id!,
      barang: barang,
      jumlah: jumlah,
      tujuan: _tujuan!,
      penerima: _penerima.text.trim(),
      tanggal: _tanggal!,
      keterangan: _keterangan.text.trim(),
      dicatatOleh: SessionService.instance.namaPencatat,
    );

    try {
      await LogistikRepository.instance.catatKeluar(data,
          barang: barang, izinkanMelebihiStok: _anggota && melebihi);
      if (!mounted) return;
      AppSnackbar.show(context, 'Barang keluar dicatat, stok berkurang.');
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final pesan = e is LogistikException ? e.message : 'Gagal menyimpan: $e';
      AppSnackbar.show(context, pesan, isError: true);
    }
  }

  String _labelStok(StokBarang s) =>
      '${labelBarang(s.barang)} · ${_anggota ? 'di HP ini' : 'sisa'} ${s.jumlah}';

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tujuanLabel = DataOptions.tujuanKeluar;

    return Scaffold(
      body: AppBackground(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PageHeader(
                title: 'Barang Keluar',
                subtitle: widget.posko.label,
                onBack: () => Navigator.of(context).pop(),
              ),
              const SizedBox(height: 24),

              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_stok.isEmpty)
                const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  message: 'Belum ada barang dengan stok di posko ini.\n'
                      'Catat barang masuk terlebih dahulu.',
                )
              else ...[
                AppDropdownField(
                  label: 'BARANG *',
                  value: _pilihan == null ? null : _labelStok(_pilihan!),
                  items: _stok.map(_labelStok).toList(),
                  hint: 'Pilih barang',
                  onChanged: (v) => setState(() {
                    for (final s in _stok) {
                      if (_labelStok(s) == v) _pilihan = s;
                    }
                  }),
                  validator: (v) =>
                      v == null ? 'Pilih barang yang dikeluarkan.' : null,
                ),
                const SizedBox(height: 16),

                AppTextField(
                  label: 'JUMLAH'
                      '${_pilihan == null ? '' : ' (${_pilihan!.barang.satuan})'}',
                  isRequired: true,
                  hint: _pilihan == null
                      ? 'Contoh: 5'
                      : _anggota
                          ? 'Stok di HP ini: ${_pilihan!.jumlah}'
                          : 'Maksimal ${_pilihan!.jumlah}',
                  controller: _jumlah,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _cekJumlah,
                ),
                const SizedBox(height: 16),

                AppDropdownField(
                  label: 'UNTUK APA *',
                  value: _tujuan == null ? null : tujuanLabel[_tujuan],
                  items: tujuanLabel.values.toList(),
                  hint: 'Pilih tujuan',
                  onChanged: (v) => setState(() {
                    for (final e in tujuanLabel.entries) {
                      if (e.value == v) _tujuan = e.key;
                    }
                  }),
                  validator: (v) =>
                      v == null ? 'Pilih untuk apa barang dikeluarkan.' : null,
                ),
                const SizedBox(height: 16),

                AppTextField(
                  label: _tujuan == 'dikirim' ? 'POSKO TUJUAN' : 'PENERIMA',
                  hint: _tujuan == 'dikirim'
                      ? 'Nama posko tujuan'
                      : 'Opsional, contoh: Dapur umum RT 02',
                  controller: _penerima,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 16),

                TanggalField(
                  label: 'Tanggal keluar',
                  value: _tanggal,
                  onChanged: (v) => setState(() => _tanggal = v),
                  validator: (v) =>
                      v == null ? 'Tanggal keluar wajib diisi.' : null,
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
                  'Salah mencatat barang masuk? Koreksi dengan barang keluar '
                  'tujuan "Lainnya" dan tulis "koreksi" di keterangan.',
                  style: AppTextStyles.small(p).copyWith(color: AppColors.sun),
                ),
                const SizedBox(height: 24),

                PrimaryButton(
                  text: 'SIMPAN BARANG KELUAR',
                  isLoading: _saving,
                  onPressed: _simpan,
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
