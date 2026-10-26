// ============================================================
// tanggal_field.dart
// Kolom TANGGAL: ketuk -> dialog tanggal (ketik hari/bulan/tahun,
// atau pilih di kalender). Tanggal tidak bisa melewati hari ini (WIB).
// ============================================================

import 'package:flutter/material.dart';

import '../utils/tanggal.dart';
import '../utils/waktu_wib.dart';
import 'app_text_field.dart';

class TanggalField extends StatefulWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final DateTime? firstDate;

  /// Tanggal awal di dialog kalau [value] masih kosong.
  final DateTime? initialDate;
  final String? Function(DateTime?)? validator;
  final bool isRequired;

  const TanggalField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.firstDate,
    this.initialDate,
    this.validator,
    this.isRequired = true,
  });

  @override
  State<TanggalField> createState() => _TanggalFieldState();
}

class _TanggalFieldState extends State<TanggalField> {
  late final TextEditingController _teks;

  @override
  void initState() {
    super.initState();
    _teks = TextEditingController(text: _format(widget.value));
  }

  @override
  void didUpdateWidget(TanggalField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _teks.text = _format(widget.value);
  }

  @override
  void dispose() {
    _teks.dispose();
    super.dispose();
  }

  static String _format(DateTime? d) => d == null ? '' : Tanggal.tampil(d);

  Future<void> _pilih() async {
    final hariIni = WaktuWib.hariIni();
    final hasil = await showDatePicker(
      context: context,
      initialDate: widget.value ?? widget.initialDate ?? hariIni,
      firstDate: widget.firstDate ?? DateTime(1900),
      lastDate: hariIni,
      initialEntryMode: DatePickerEntryMode.input,
      helpText: widget.label.toUpperCase(),
      fieldHintText: 'hh/bb/tttt',
      fieldLabelText: widget.label,
      errorFormatText: 'Format salah, contoh: 25/07/1990',
      errorInvalidText: 'Tanggal tidak boleh setelah hari ini',
    );
    if (hasil != null) widget.onChanged(hasil);
  }

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: widget.label.toUpperCase(),
      isRequired: widget.isRequired,
      hint: 'Ketuk untuk memilih tanggal',
      controller: _teks,
      readOnly: true,
      onTap: _pilih,
      validator: (_) => widget.validator?.call(widget.value),
    );
  }
}
