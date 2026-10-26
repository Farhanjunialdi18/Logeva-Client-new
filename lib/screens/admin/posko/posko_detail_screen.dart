// ============================================================
// posko_detail_screen.dart
// HALAMAN DETAIL POSKO (oleh admin): data posko, status operasional,
// relawan penanggung jawab, tombol MULAI/TUTUP/SIAGA, EDIT, HAPUS.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../data/repositories/relawan_repository.dart';
import '../../../models/posko.dart';
import '../../../models/relawan.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/angka.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/date_formatter.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/detail_info_card.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/secondary_button.dart';
import '../../ringkasan/ringkasan_posko_screen.dart';
import '../../../services/perangkat_service.dart';
import '../../../widgets/dikelola_induk_banner.dart';
import 'posko_form_screen.dart';
import 'siapkan_anggota_screen.dart';

class PoskoDetailScreen extends StatefulWidget {
  final int poskoId;

  const PoskoDetailScreen({super.key, required this.poskoId});

  @override
  State<PoskoDetailScreen> createState() => _PoskoDetailScreenState();
}

class _PoskoDetailScreenState extends State<PoskoDetailScreen> {
  Posko? _posko;
  List<Relawan> _relawan = [];
  bool _loading = true;
  bool _busy = false;

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

  Future<void> _load() async {
    final posko = await PoskoRepository.instance.findById(widget.poskoId);
    final relawan = await RelawanRepository.instance.getByPosko(widget.poskoId);
    if (!mounted) return;
    setState(() {
      _posko = posko;
      _relawan = relawan;
      _loading = false;
    });
  }

  static String _labelAksi(AksiOperasional aksi) => switch (aksi) {
        AksiOperasional.mulai => 'MULAI OPERASI',
        AksiOperasional.tutup => 'TUTUP OPERASI',
        AksiOperasional.siaga => 'KEMBALIKAN KE SIAGA',
      };

  Future<void> _ubahStatus(Posko posko, AksiOperasional aksi) async {
    final (judul, pesan) = switch (aksi) {
      AksiOperasional.mulai => (
          'Mulai operasi posko?',
          'Posko ${posko.nama} akan berstatus Beroperasi mulai hari ini '
              '(hari ke-1).',
        ),
      AksiOperasional.tutup => (
          'Tutup operasi posko?',
          'Posko ${posko.nama} akan berstatus Selesai.',
        ),
      AksiOperasional.siaga => (
          'Kembalikan ke siaga?',
          'Tanggal mulai & selesai operasi posko ${posko.nama} akan dikosongkan.',
        ),
    };
    final yakin = await ConfirmDialog.show(
      context,
      title: judul,
      message: pesan,
      confirmText: _labelAksi(aksi),
    );
    if (!yakin || !mounted) return;

    setState(() => _busy = true);
    try {
      final baru = await PoskoRepository.instance.ubahStatus(posko, aksi);
      if (!mounted) return;
      AppSnackbar.show(context, 'Status posko: ${baru.statusLabel}.');
    } on PoskoException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _edit(Posko posko) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PoskoFormScreen(existing: posko)),
    );
  }

  Future<void> _hapus(Posko posko) async {
    final alasan = await PoskoRepository.instance.cekHapus(posko);
    if (!mounted) return;
    if (alasan != null) {
      AppSnackbar.show(context, 'Posko tidak bisa dihapus. $alasan',
          isError: true);
      return;
    }

    final yakin = await ConfirmDialog.show(
      context,
      title: 'Hapus posko?',
      message: 'Posko ${posko.nama} akan dihapus permanen.',
      confirmText: 'HAPUS',
    );
    if (!yakin || !mounted || posko.id == null) return;

    await PoskoRepository.instance.delete(posko.id!);
    if (!mounted) return;
    AppSnackbar.show(context, 'Posko dihapus.');
    Navigator.of(context).pop();
  }

  String _isi(String teks) => teks.trim().isEmpty ? '-' : teks;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final posko = _posko;

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Detail Posko',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (posko == null)
              const EmptyState(
                icon: Icons.location_off_rounded,
                message: 'Posko tidak ditemukan.',
              )
            else ...[
              if (!posko.lengkap) ...[
                _PeringatanBelumLengkap(kolom: posko.dataBelumLengkap),
                const SizedBox(height: 16),
              ],

              DetailInfoCard(
                nama: posko.nama,
                rows: [
                  DetailRow(label: 'Desa', value: _isi(posko.namaDesa)),
                  DetailRow(label: 'Alamat', value: _isi(posko.alamat)),
                  DetailRow(
                    label: 'Luas',
                    value: posko.luasLokasi == null
                        ? '-'
                        : '${Angka.tampil(posko.luasLokasi!)} m²',
                  ),
                  DetailRow(
                    label: 'Kapasitas',
                    value: posko.kapasitas > 0
                        ? '${posko.kapasitas} orang'
                        : '-',
                  ),
                  DetailRow(
                    label: 'Koordinat',
                    value: posko.latitude.isEmpty || posko.longitude.isEmpty
                        ? '-'
                        : '${posko.latitude}, ${posko.longitude}',
                  ),
                  DetailRow(
                    label: 'Status',
                    child: Text(
                      posko.hariKe() == null
                          ? posko.statusLabel
                          : '${posko.statusLabel} · Hari ke-${posko.hariKe()}',
                      style: AppTextStyles.body(p).copyWith(
                        color: posko.isBeroperasi
                            ? AppColors.success
                            : p.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (posko.mulaiBeroperasiAt != null)
                    DetailRow(
                      label: 'Mulai beroperasi',
                      value: DateFormatter.full(posko.mulaiBeroperasiAt!),
                    ),
                  if (posko.selesaiBeroperasiAt != null)
                    DetailRow(
                      label: 'Selesai',
                      value: DateFormatter.full(posko.selesaiBeroperasiAt!),
                    ),
                  DetailRow(
                    label: 'Relawan',
                    value: _relawan.isEmpty
                        ? 'Belum ada'
                        : _relawan.map((r) => r.nama).join(', '),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Status operasional diubah supervisor di HP Induk.
              if (!PerangkatService.isAnggota) ...[
                for (final (i, aksi) in posko.aksiTersedia.indexed) ...[
                  if (i == 0)
                    PrimaryButton(
                      text: _labelAksi(aksi),
                      isLoading: _busy,
                      onPressed: () => _ubahStatus(posko, aksi),
                    )
                  else
                    SecondaryButton(
                      text: _labelAksi(aksi),
                      height: 54,
                      onPressed: _busy ? null : () => _ubahStatus(posko, aksi),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
              SecondaryButton(
                text: 'KEBUTUHAN & KOMPOSISI',
                icon: Icons.health_and_safety_outlined,
                height: 54,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RingkasanPoskoScreen(posko: posko),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              if (PerangkatService.isAnggota)
                const DikelolaIndukBanner()
              else ...[
                SecondaryButton(
                  text: 'SIAPKAN HP ANGGOTA',
                  icon: Icons.install_mobile_rounded,
                  height: 54,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SiapkanAnggotaScreen(posko: posko),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  text: 'EDIT POSKO',
                  height: 54,
                  onPressed: () => _edit(posko),
                ),
                const SizedBox(height: 12),
                SecondaryButton(
                  text: 'HAPUS POSKO',
                  icon: Icons.delete_outline_rounded,
                  height: 54,
                  onPressed: () => _hapus(posko),
                ),
              ],
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Kotak kuning: kolom yang wajib dilengkapi sebelum ekspor paket.
class _PeringatanBelumLengkap extends StatelessWidget {
  final List<String> kolom;

  const _PeringatanBelumLengkap({required this.kolom});

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sun.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.sun.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.sun),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Lengkapi sebelum ekspor Paket Data Posko: ${kolom.join(', ')}.',
              style: AppTextStyles.small(p).copyWith(color: p.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
