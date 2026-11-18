// ============================================================
// log_setor_screen.dart
// LOG SETOR DATA: catatan waktu setiap kali data berpindah antar-HP.
//  - HP relawan (Anggota): kapan setor ke admin & isinya, kapan data
//    gabungan dari admin diterima.
//  - HP admin (Induk): SETORAN PER RELAWAN (terakhir setor, belum setor
//    hari ini), lalu daftar setiap setoran yang diterima (dari siapa,
//    kapan dikirim, kapan diterima) & setiap kiriman ke HP relawan.
// Sumber: riwayat transaksi "Sinkron Antar-HP".
// ============================================================

import 'package:flutter/material.dart';

import '../../data/data_events.dart';
import '../../data/repositories/relawan_repository.dart';
import '../../data/repositories/riwayat_repository.dart';
import '../../models/relawan.dart';
import '../../models/riwayat_transaksi.dart';
import '../../services/perangkat_service.dart';
import '../../services/sinkron_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/date_formatter.dart';
import '../../widgets/app_background.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/page_header.dart';

class LogSetorScreen extends StatefulWidget {
  const LogSetorScreen({super.key});

  /// Jenis data riwayat untuk semua kiriman antar-HP.
  static const String jenisData = 'Sinkron Antar-HP';

  @override
  State<LogSetorScreen> createState() => _LogSetorScreenState();
}

class _LogSetorScreenState extends State<LogSetorScreen> {
  List<RiwayatTransaksi> _log = [];
  List<(Relawan, StatusHpRelawan)> _relawan = [];
  bool _loading = true;

  bool get _anggota => PerangkatService.isAnggota;

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
    final log = (await RiwayatRepository.instance.getAll())
        .where((r) => r.jenisData == LogSetorScreen.jenisData)
        .toList()
      ..sort((a, b) => b.waktu.compareTo(a.waktu));

    final relawan = <(Relawan, StatusHpRelawan)>[];
    if (!_anggota) {
      final status = await SinkronService.statusHpRelawan();
      for (final r in await RelawanRepository.instance.getAll()) {
        if (!r.isAktif || !r.sudahDitempatkan) continue;
        relawan.add((r, SinkronService.statusUntuk(status, r.kode)));
      }
      // Yang belum setor hari ini di atas.
      relawan.sort((a, b) {
        final x = a.$2.belumKirimHariIni() ? 0 : 1;
        final y = b.$2.belumKirimHariIni() ? 0 : 1;
        return x != y ? x - y : a.$1.nama.compareTo(b.$1.nama);
      });
    }
    if (!mounted) return;
    setState(() {
      _log = log;
      _relawan = relawan;
      _loading = false;
    });
  }

  String _judul(RiwayatTransaksi r) {
    if (!r.berhasil) return r.isImport ? 'Gagal menerima' : 'Gagal mengirim';
    if (_anggota) return r.isImport ? 'Data diterima dari admin' : 'Setor data ke admin';
    return r.isImport ? 'Setoran diterima' : 'Dikirim ke HP relawan';
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final belumHariIni = _relawan.where((e) => e.$2.belumKirimHariIni()).length;

    return Scaffold(
      body: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Log Setor Data',
              subtitle: _anggota
                  ? 'Kapan HP ini setor ke admin'
                  : 'Kapan setiap relawan setor data',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (!_anggota && _relawan.isNotEmpty) ...[
                Text('SETORAN PER RELAWAN', style: AppTextStyles.label(p)),
                const SizedBox(height: 6),
                Text(
                  belumHariIni == 0
                      ? 'Semua relawan sudah setor data hari ini.'
                      : '$belumHariIni relawan BELUM setor data hari ini.',
                  style: AppTextStyles.small(p).copyWith(
                      color: belumHariIni == 0 ? AppColors.success : AppColors.sun),
                ),
                const SizedBox(height: 10),
                for (final (r, s) in _relawan)
                  _Baris(
                    ikon: s.belumKirimHariIni()
                        ? Icons.schedule_rounded
                        : Icons.check_circle_rounded,
                    warna: s.belumKirimHariIni() ? AppColors.sun : AppColors.success,
                    judul: r.nama,
                    isi: s.terakhirKirim == null
                        ? 'Belum pernah setor data'
                        : 'Terakhir setor: ${DateFormatter.full(s.terakhirKirim!)} '
                            '(${DateFormatter.lamaSejak(s.terakhirKirim!)})',
                  ),
                const SizedBox(height: 20),
              ],
              Text('SEMUA KIRIMAN', style: AppTextStyles.label(p)),
              const SizedBox(height: 10),
              if (_log.isEmpty)
                const EmptyState(
                  icon: Icons.history_rounded,
                  message: 'Belum ada data yang disetor atau diterima.',
                )
              else
                for (final r in _log)
                  _Baris(
                    ikon: r.isImport ? Icons.download_rounded : Icons.upload_rounded,
                    warna: r.berhasil ? AppColors.primary : AppColors.error,
                    judul: _judul(r),
                    waktu: DateFormatter.full(r.waktu),
                    isi: r.keterangan,
                  ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Baris extends StatelessWidget {
  final IconData ikon;
  final Color warna;
  final String judul;
  final String? waktu;
  final String isi;

  const _Baris({
    required this.ikon,
    required this.warna,
    required this.judul,
    this.waktu,
    required this.isi,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, color: warna, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(judul, style: AppTextStyles.cardTitle(p)),
                if (waktu != null) ...[
                  const SizedBox(height: 2),
                  Text(waktu!, style: AppTextStyles.small(p).copyWith(
                      color: p.textPrimary, fontWeight: FontWeight.w600)),
                ],
                if (isi.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(isi, style: AppTextStyles.small(p)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
