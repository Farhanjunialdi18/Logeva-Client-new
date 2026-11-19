// ============================================================
// pengungsi_form_screen.dart
// FORM TAMBAH / EDIT PENGUNGSI. Kolom, pilihan, dan aturan sama
// dengan form Pengungsi di website:
//  - Isi TANGGAL LAHIR (usia dihitung otomatis) ATAU langsung USIA
//    kalau tanggal lahir tidak diketahui.
//  - Nomor KK boleh kosong (dokumen bisa hilang saat bencana),
//    kalau diisi harus 16 digit.
//  - Nama + tanggal lahir (atau nama + usia) yang sama di posko yang
//    sama = orang yang sama (ditolak supaya tidak dobel).
// Relawan: posko otomatis = posko tugasnya. Admin: pilih posko.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data_options.dart';
import '../../../data/repositories/pengungsi_repository.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../models/pengungsi.dart';
import '../../../models/posko.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/kondisi_kesehatan.dart';
import '../../../utils/pengingat_setor.dart';
import '../../../utils/tanggal.dart';
import '../../../utils/validators.dart';
import '../../../utils/waktu_wib.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/app_text_field.dart';
import '../../../widgets/kotak_peringatan.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/segmented_choice.dart';
import '../../../widgets/tanggal_field.dart';

class PengungsiFormScreen extends StatefulWidget {
  final Pengungsi? existing;

  const PengungsiFormScreen({super.key, this.existing});

  @override
  State<PengungsiFormScreen> createState() => _PengungsiFormScreenState();
}

class _PengungsiFormScreenState extends State<PengungsiFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _asal;
  late final TextEditingController _kk;
  late final TextEditingController _kondisi;
  late final TextEditingController _riwayat;
  late final TextEditingController _poskoTeks;
  late final TextEditingController _usia;

  static const String _modeLahir = 'lahir';
  static const String _modeUsia = 'usia';

  /// Isian umur: tanggal lahir atau usia saja.
  String _modeUmur = _modeLahir;
  DateTime? _tanggalLahir;
  String _jenisKelamin = DataOptions.lakiLaki;
  String _rentan = DataOptions.bukanRentan;

  /// Kondisi kesehatan: pilihan + keterangan ([_kondisi]). null = teks lama
  /// yang bukan pilihan (wajib dipilih ulang saat disimpan).
  String? _kondisiPilihan = KondisiKesehatan.sehat;

  /// Admin memilih posko; relawan memakai posko tugasnya.
  bool get _pilihPosko => SessionService.instance.relawan == null;
  List<Posko> _daftarPosko = [];
  int? _poskoId;

  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nama = TextEditingController(text: e?.nama ?? '');
    _asal = TextEditingController(text: e?.asal ?? '');
    _tanggalLahir = e?.tanggalLahir;
    _modeUmur = e != null && e.hanyaUsia ? _modeUsia : _modeLahir;
    _usia = TextEditingController(text: e != null && e.hanyaUsia ? '${e.usia}' : '');
    _kk = TextEditingController(text: e?.nomorKk ?? '');
    final kondisi = KondisiKesehatan.pisah(e?.kondisiKesehatan ?? '');
    _kondisiPilihan = kondisi.pilihan;
    _kondisi = TextEditingController(text: kondisi.keterangan);
    _riwayat = TextEditingController(text: e?.riwayatPenyakit ?? '');
    _poskoTeks =
        TextEditingController(text: SessionService.instance.poskoLabel);
    _jenisKelamin = e?.jenisKelamin ?? DataOptions.lakiLaki;
    _rentan = e?.kelompokRentan ?? DataOptions.bukanRentan;
    _poskoId = e?.poskoId ?? SessionService.instance.poskoId;

    if (_pilihPosko) _loadPosko();
  }

  Future<void> _loadPosko() async {
    final posko = await PoskoRepository.instance.getDipakai();
    posko.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    if (!mounted) return;
    setState(() => _daftarPosko = posko);
  }

  @override
  void dispose() {
    for (final c in [
      _nama, _asal, _kk, _kondisi, _riwayat, _poskoTeks, _usia,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _simpan() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_poskoId == null) {
      AppSnackbar.show(
        context,
        _pilihPosko
            ? 'Pilih posko terlebih dahulu.'
            : 'Akun belum ditempatkan di posko. Hubungi admin.',
        isError: true,
      );
      return;
    }

    setState(() => _saving = true);

    final kk = Validators.bersihkanKk(_kk.text);
    final pakaiLahir = _modeUmur == _modeLahir;
    final lahir = pakaiLahir ? _tanggalLahir : null;
    final usia = pakaiLahir ? null : int.parse(_usia.text.trim());
    final e = widget.existing;
    final data = e == null
        ? Pengungsi.baru(
            poskoId: _poskoId,
            nama: _nama.text.trim(),
            asal: _asal.text.trim(),
            tanggalLahir: lahir,
            usia: usia,
            jenisKelamin: _jenisKelamin,
            nomorKk: kk,
            kondisiKesehatan: _teksKondisi,
            kelompokRentan: _rentan,
            riwayatPenyakit: _riwayat.text.trim(),
            dicatatOleh: SessionService.instance.namaPencatat,
          )
        : e.ubahData(
            poskoId: _poskoId,
            nama: _nama.text.trim(),
            asal: _asal.text.trim(),
            tanggalLahir: lahir,
            usia: usia,
            jenisKelamin: _jenisKelamin,
            nomorKk: kk,
            kondisiKesehatan: _teksKondisi,
            kelompokRentan: _rentan,
            riwayatPenyakit: _riwayat.text.trim(),
          );

    try {
      final sama = await PengungsiRepository.instance.cariSama(data);
      if (sama != null) {
        if (!mounted) return;
        setState(() => _saving = false);
        AppSnackbar.show(
          context,
          '${sama.nama} dengan ${pakaiLahir ? 'tanggal lahir' : 'usia'} yang '
          'sama sudah tercatat di posko ini.',
          isError: true,
        );
        return;
      }

      if (_isEdit) {
        await PengungsiRepository.instance.update(data);
      } else {
        await PengungsiRepository.instance.add(data);
      }
      if (!mounted) return;
      await PengingatSetor.setelahSimpan(
        context,
        _isEdit ? 'Data pengungsi diperbarui.' : 'Pengungsi berhasil ditambahkan.',
      );
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppSnackbar.show(context, 'Gagal menyimpan: $e', isError: true);
    }
  }

  /// Sehat tidak memakai keterangan (kolomnya disembunyikan).
  String get _teksKondisi {
    final pilihan = _kondisiPilihan ?? KondisiKesehatan.sehat;
    return pilihan == KondisiKesehatan.sehat
        ? pilihan
        : KondisiKesehatan.gabung(pilihan, _kondisi.text);
  }

  Widget _poskoField() {
    if (!_pilihPosko) {
      return AppTextField(
        label: 'POSKO',
        hint: '',
        controller: _poskoTeks,
        readOnly: true,
      );
    }
    String? nama;
    for (final p in _daftarPosko) {
      if (p.id == _poskoId) nama = p.nama;
    }
    return AppDropdownField(
      label: 'POSKO *',
      value: nama,
      items: _daftarPosko.map((p) => p.nama).toList(),
      hint: 'Pilih posko',
      onChanged: (v) => setState(() {
        for (final p in _daftarPosko) {
          if (p.nama == v) _poskoId = p.id;
        }
      }),
      validator: (v) => v == null ? 'Posko wajib dipilih.' : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final lahir = _tanggalLahir;

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

              // Posko hampir/sudah penuh: tetap boleh dicatat, tapi diberi tahu.
              if (!_isEdit && _poskoId != null)
                KotakPeringatan(
                  key: ValueKey(_poskoId),
                  poskoId: _poskoId,
                  tampilStok: false,
                ),

              AppTextField(
                label: 'NAMA LENGKAP',
                isRequired: true,
                hint: 'Contoh: Ahmad Saputra',
                controller: _nama,
                textCapitalization: TextCapitalization.words,
                validator: Validators.wajib('Nama'),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'ASAL',
                isRequired: true,
                hint: 'Asal desa / alamat sebelum mengungsi',
                controller: _asal,
                textCapitalization: TextCapitalization.words,
                validator: Validators.wajib('Asal'),
              ),
              const SizedBox(height: 16),

              SegmentedChoice(
                label: 'UMUR',
                options: const {
                  _modeLahir: 'Tanggal lahir',
                  _modeUsia: 'Usia saja',
                },
                selected: _modeUmur,
                onChanged: (v) => setState(() => _modeUmur = v),
              ),
              const SizedBox(height: 12),
              if (_modeUmur == _modeLahir) ...[
                TanggalField(
                  key: const ValueKey('tanggal_lahir'),
                  label: 'Tanggal lahir',
                  value: _tanggalLahir,
                  initialDate: DateTime(WaktuWib.hariIni().year - 30),
                  onChanged: (v) => setState(() => _tanggalLahir = v),
                  validator: Validators.tanggalLahir,
                ),
                const SizedBox(height: 8),
                Text(
                  lahir == null
                      ? 'Usia dihitung otomatis dari tanggal lahir.'
                      : 'Usia: ${Tanggal.usia(lahir)} tahun',
                  style: AppTextStyles.small(p),
                ),
              ] else ...[
                AppTextField(
                  key: const ValueKey('usia'),
                  label: 'USIA (TAHUN)',
                  isRequired: true,
                  hint: 'Contoh: 45 (bayi di bawah 1 tahun: 0)',
                  controller: _usia,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  validator: Validators.usia,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pakai kalau tanggal lahir tidak diketahui. Isi tanggal lahir '
                  'kalau ada, supaya usia selalu tepat.',
                  style: AppTextStyles.small(p),
                ),
              ],
              const SizedBox(height: 16),

              SegmentedChoice(
                label: 'JENIS KELAMIN',
                options: {for (final jk in DataOptions.jenisKelamin) jk: jk},
                selected: _jenisKelamin,
                onChanged: (v) => setState(() => _jenisKelamin = v),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'NOMOR KK (OPSIONAL)',
                hint: '16 digit, kosongkan kalau tidak tahu',
                controller: _kk,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                ],
                validator: Validators.nomorKkOptional,
              ),
              const SizedBox(height: 16),

              AppDropdownField(
                label: 'KONDISI KESEHATAN *',
                value: _kondisiPilihan,
                items: KondisiKesehatan.pilihan,
                hint: 'Pilih kondisi',
                onChanged: (v) => setState(() => _kondisiPilihan = v),
                validator: (v) => v == null ? 'Pilih kondisi kesehatan.' : null,
              ),
              if (_kondisiPilihan != KondisiKesehatan.sehat) ...[
                const SizedBox(height: 12),
                AppTextField(
                  label: 'KETERANGAN KONDISI (OPSIONAL)',
                  hint: 'Contoh: demam, diare, luka di kaki',
                  controller: _kondisi,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
              const SizedBox(height: 16),

              AppDropdownField(
                label: 'KELOMPOK RENTAN',
                value: _rentan,
                items: DataOptions.kelompokRentan,
                onChanged: (v) =>
                    setState(() => _rentan = v ?? DataOptions.bukanRentan),
              ),
              const SizedBox(height: 16),

              AppTextField(
                label: 'RIWAYAT PENYAKIT',
                hint: 'Contoh: Hipertensi, Diabetes',
                controller: _riwayat,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              _poskoField(),
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
