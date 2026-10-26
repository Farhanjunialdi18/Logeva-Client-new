// ============================================================
// paket_data_screen.dart
// EKSPOR PAKET DATA POSKO (admin lokal): pilih posko, periksa
// kelengkapan, baca peringatan data pribadi, lalu simpan file ZIP
// (misal ke flashdisk) untuk dibawa ke pusat.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../models/posko.dart';
import '../../../services/paket_data_service.dart';
import '../../../services/transfer_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/transfer_result_dialog.dart';

class PaketDataScreen extends StatefulWidget {
  const PaketDataScreen({super.key});

  @override
  State<PaketDataScreen> createState() => _PaketDataScreenState();
}

class _PaketDataScreenState extends State<PaketDataScreen> {
  static const String _semuaPosko = 'Semua posko di HP ini';

  List<Posko> _daftarPosko = [];
  String _pilihan = _semuaPosko;
  PaketData? _paket;
  bool _loading = true;
  bool _menyimpan = false;

  @override
  void initState() {
    super.initState();
    _load();
    DataEvents.instance.addListener(_load);
  }

  @override
  void dispose() {
    DataEvents.instance.removeListener(_load);
    super.dispose();
  }

  List<Posko> get _poskoTerpilih => _pilihan == _semuaPosko
      ? _daftarPosko
      : _daftarPosko.where((p) => p.nama == _pilihan).toList();

  Future<void> _load() async {
    final posko = await PoskoRepository.instance.getAll()
      ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _daftarPosko = posko;
      if (_pilihan != _semuaPosko && !posko.any((p) => p.nama == _pilihan)) {
        _pilihan = _semuaPosko;
      }
    });
    await _hitung();
  }

  Future<void> _hitung() async {
    final paket = await PaketDataService.kumpulkan(_poskoTerpilih);
    if (!mounted) return;
    setState(() {
      _paket = paket;
      _loading = false;
    });
  }

  Future<void> _ekspor() async {
    final paket = await PaketDataService.kumpulkan(_poskoTerpilih);
    final periksa = PaketDataService.periksa(paket);
    if (!mounted || !periksa.bisaEkspor) return;

    if (periksa.peringatan.isNotEmpty) {
      final lanjut = await ConfirmDialog.show(
        context,
        title: 'Tetap ekspor?',
        message: periksa.peringatan.join('\n\n'),
        confirmText: 'TETAP EKSPOR',
      );
      if (!lanjut || !mounted) return;
    }

    final paham = await ConfirmDialog.show(
      context,
      title: 'Berisi data pribadi',
      message: 'Paket berisi nomor KK, tanggal lahir, dan kondisi kesehatan '
          'pengungsi, serta nama & kontak petugas. Simpan flashdisk dengan '
          'aman, jangan dibagikan, dan '
          'HAPUS file setelah diimpor di pusat.',
      confirmText: 'SAYA MENGERTI',
    );
    if (!paham || !mounted) return;

    setState(() => _menyimpan = true);
    final hasil = await PaketDataService.simpan(paket);
    if (!mounted) return;
    setState(() => _menyimpan = false);
    if (hasil.status == TransferStatus.cancelled) return;
    await TransferResultDialog.show(
      context,
      result: hasil,
      aksi: 'Ekspor',
      jenisData: 'Paket Data Posko',
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final paket = _paket;
    final periksa = paket == null ? null : PaketDataService.periksa(paket);

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Paket Data Posko',
              subtitle: 'Ekspor data untuk dibawa ke pusat lewat USB',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),

            Text(
              'Paket berisi SELURUH data posko (bukan hanya yang baru). '
              'Pusat menggabungkannya tanpa dobel, jadi paket boleh diekspor '
              'kapan saja dan berkali-kali.',
              style: AppTextStyles.small(p),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_daftarPosko.isEmpty)
              const EmptyState(
                icon: Icons.home_work_outlined,
                message: 'Belum ada posko. Tambahkan posko di menu Data Posko.',
              )
            else ...[
              AppDropdownField(
                label: 'POSKO',
                value: _pilihan,
                items: [_semuaPosko, ..._daftarPosko.map((p) => p.nama)],
                onChanged: (v) {
                  setState(() => _pilihan = v ?? _semuaPosko);
                  _hitung();
                },
              ),
              const SizedBox(height: 16),

              if (paket != null)
                InfoCard(
                  title: 'ISI PAKET',
                  rows: {
                    'Posko': '${paket.posko.length}',
                    'Pengungsi': '${paket.jumlahPengungsiAktif}',
                    if (paket.jumlahPengungsiDihapus > 0)
                      'Penghapusan': '${paket.jumlahPengungsiDihapus} pengungsi',
                    'Barang masuk': '${paket.masuk.length} catatan',
                    'Barang keluar': '${paket.keluar.length} catatan',
                    'Petugas': '${paket.admin.length} admin, '
                        '${paket.petugas.length - paket.admin.length} relawan',
                    'Nama file': paket.namaFile,
                  },
                ),
              const SizedBox(height: 14),

              if (periksa != null && periksa.penghalang.isNotEmpty) ...[
                _Kotak(
                  warna: AppColors.error,
                  ikon: Icons.block_rounded,
                  judul: 'Lengkapi dulu sebelum ekspor',
                  isi: periksa.penghalang,
                ),
                const SizedBox(height: 14),
              ],
              if (periksa != null && periksa.peringatan.isNotEmpty) ...[
                _Kotak(
                  warna: AppColors.sun,
                  ikon: Icons.warning_amber_rounded,
                  judul: 'Perhatian',
                  isi: periksa.peringatan,
                ),
                const SizedBox(height: 14),
              ],

              if (paket != null && paket.petugas.isNotEmpty) ...[
                InfoCard(
                  title: 'PETUGAS YANG DICANTUMKAN',
                  rows: {
                    for (final t in paket.petugas)
                      '${t.nama} (${t.peran == PetugasPaket.admin ? 'Admin' : 'Relawan'})':
                          t.kontak.isEmpty ? '-' : t.kontak,
                  },
                  note: 'Admin = penanggung jawab semua posko di paket. Relawan '
                      'dicantumkan di posko tugasnya. PIN & password tidak ikut.',
                ),
                const SizedBox(height: 14),
              ],
              const _Kotak(
                warna: AppColors.accentBlue,
                ikon: Icons.privacy_tip_outlined,
                judul: 'Data pribadi',
                isi: [
                  'Paket berisi nomor KK, tanggal lahir, dan kondisi kesehatan '
                      'pengungsi, serta nama & kontak petugas.',
                  'Simpan flashdisk dengan aman dan hapus file setelah '
                      'diimpor di pusat.',
                ],
              ),
              const SizedBox(height: 20),

              PrimaryButton(
                text: 'EKSPOR PAKET (ZIP)',
                isLoading: _menyimpan,
                onPressed:
                    periksa == null || !periksa.bisaEkspor ? null : _ekspor,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Kotak extends StatelessWidget {
  final Color warna;
  final IconData ikon;
  final String judul;
  final List<String> isi;

  const _Kotak({
    required this.warna,
    required this.ikon,
    required this.judul,
    required this.isi,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warna.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: warna),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul, style: AppTextStyles.cardTitle(p)),
                for (final t in isi) ...[
                  const SizedBox(height: 4),
                  Text('• $t',
                      style: AppTextStyles.small(p)
                          .copyWith(color: p.textPrimary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
