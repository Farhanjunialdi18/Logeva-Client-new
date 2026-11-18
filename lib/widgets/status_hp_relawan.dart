// ============================================================
// status_hp_relawan.dart
// PENGINGAT ADMIN (HP Induk) tentang HP setiap relawan:
//  - kapan relawan terakhir mengirim data (belum kirim hari ini?);
//  - apakah HP relawan PERLU DIBAGIKAN ULANG: akun berubah (PIN baru,
//    nonaktif, dihapus, relawan baru) atau ada data gabungan baru yang
//    belum ada di HP itu. Perubahan akun baru berlaku di HP relawan
//    setelah dibagikan ulang, jadi ini penting untuk keamanan.
// Sumber datanya: laporan yang ikut di file kiriman relawan + catatan
// admin saat membagikan dari Detail Relawan (sinkron_service.dart).
// ============================================================

import 'package:flutter/material.dart';

import '../data/data_events.dart';
import '../data/repositories/relawan_repository.dart';
import '../models/relawan.dart';
import '../services/perangkat_service.dart';
import '../services/sinkron_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_formatter.dart';

class StatusHpRelawanTeks {
  StatusHpRelawanTeks._();

  /// "baru saja", "15 menit lalu", "3 jam lalu", "kemarin", ...
  static String sejak(DateTime w, [DateTime? sekarang]) {
    final d = (sekarang ?? DateTime.now()).difference(w);
    if (d.inMinutes < 1) return 'baru saja';
    if (d.inMinutes < 60) return '${d.inMinutes} menit lalu';
    if (d.inHours < 24) return '${d.inHours} jam lalu';
    return DateFormatter.lamaSejak(w, sekarang);
  }

  /// Satu baris singkat untuk daftar relawan.
  static String ringkas(StatusHpRelawan s) {
    if (s.belumPernahDibagikan) return '⚠ HP belum disiapkan / belum dibagikan';
    if (s.akunBelumBerlaku) return '⚠ Akun berubah: perlu dibagikan ulang';
    final kirim = s.terakhirKirim == null
        ? 'Belum pernah kirim data'
        : 'Kirim terakhir ${sejak(s.terakhirKirim!)}';
    if (s.adaDataBaru) return '$kirim · data baru perlu dibagikan';
    return kirim;
  }

  /// Penting ditandai (warna peringatan di daftar).
  static bool penting(StatusHpRelawan s) =>
      s.belumPernahDibagikan || s.akunBelumBerlaku;
}

/// Kartu status HP satu relawan (Detail Relawan, HP Induk).
class StatusHpRelawanCard extends StatefulWidget {
  final Relawan relawan;

  const StatusHpRelawanCard({super.key, required this.relawan});

  @override
  State<StatusHpRelawanCard> createState() => _StatusHpRelawanCardState();
}

class _StatusHpRelawanCardState extends State<StatusHpRelawanCard> {
  StatusHpRelawan? _status;

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
    final semua = await SinkronService.statusHpRelawan();
    if (!mounted) return;
    setState(() => _status = SinkronService.statusUntuk(semua, widget.relawan.kode));
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (s == null || PerangkatService.isAnggota) return const SizedBox.shrink();
    final p = AppPalette.of(context);
    final nama = widget.relawan.nama;

    final warna = StatusHpRelawanTeks.penting(s)
        ? AppColors.error
        : (s.perluDibagikan || s.belumKirimHariIni())
            ? AppColors.sun
            : AppColors.success;

    Widget baris(IconData ikon, Color c, String teks) => Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ikon, size: 18, color: c),
              const SizedBox(width: 8),
              Expanded(child: Text(teks, style: AppTextStyles.small(p))),
            ],
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: warna.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: warna.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.phone_android_rounded, color: warna),
              const SizedBox(width: 8),
              Expanded(child: Text('HP RELAWAN', style: AppTextStyles.cardTitle(p))),
            ],
          ),
          // ---- Kiriman relawan ----
          if (s.terakhirKirim == null)
            baris(Icons.upload_rounded, AppColors.sun,
                '$nama belum pernah mengirim data ke HP ini.')
          else
            baris(
              Icons.upload_rounded,
              s.belumKirimHariIni() ? AppColors.sun : AppColors.success,
              'Terakhir mengirim data: ${DateFormatter.full(s.terakhirKirim!)} '
              '(${StatusHpRelawanTeks.sejak(s.terakhirKirim!)})'
              '${s.belumKirimHariIni() ? '. Belum mengirim hari ini: ingatkan $nama.' : '.'}',
            ),
          // ---- Data admin di HP relawan ----
          if (s.belumPernahDibagikan)
            baris(Icons.error_outline_rounded, AppColors.error,
                'HP $nama belum disiapkan. Tekan BAGIKAN KE HP RELAWAN di bawah.')
          else ...[
            baris(
              Icons.download_rounded,
              p.textSecondary,
              'Data admin di HP-nya: versi ${DateFormatter.full(s.dataAdminDiHp!)}'
              '${s.dataIndukDilaporkan != null && !s.dataIndukDilaporkan!.isBefore(s.dataAdminDiHp!) ? ' (dikonfirmasi dari kirimannya)' : ' (dibagikan, belum dikonfirmasi)'}.',
            ),
            if (s.akunBelumBerlaku)
              baris(
                Icons.lock_reset_rounded,
                AppColors.error,
                'AKUN BERUBAH setelah itu (PIN baru, nonaktif, relawan baru/dihapus). '
                'Perubahan BELUM berlaku di HP $nama: akun lama masih bisa login '
                'di sana. Bagikan ulang sekarang.',
              ),
            if (s.adaDataBaru && !s.akunBelumBerlaku)
              baris(Icons.sync_problem_rounded, AppColors.sun,
                  'Ada data gabungan baru yang belum ada di HP $nama. Bagikan '
                  'ulang supaya datanya sama.'),
            if (!s.perluDibagikan)
              baris(Icons.verified_rounded, AppColors.success,
                  'HP $nama sudah memakai akun & data terbaru.'),
          ],
        ],
      ),
    );
  }
}

/// Banner pengingat di beranda admin / Kelola Relawan (HP Induk).
class PengingatHpRelawanBanner extends StatefulWidget {
  final VoidCallback? onTap;

  const PengingatHpRelawanBanner({super.key, this.onTap});

  @override
  State<PengingatHpRelawanBanner> createState() => _PengingatHpRelawanBannerState();
}

class _PengingatHpRelawanBannerState extends State<PengingatHpRelawanBanner> {
  int _perluDibagikan = 0;
  int _akunBelumBerlaku = 0;
  int _belumKirim = 0;
  List<String> _namaBelumKirim = const [];

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
    if (PerangkatService.isAnggota) return;
    final semua = await SinkronService.statusHpRelawan();
    var perlu = 0, akun = 0, belum = 0;
    final namaBelum = <String>[];
    for (final r in await RelawanRepository.instance.getAll()) {
      if (!r.sudahDitempatkan) continue;
      final s = SinkronService.statusUntuk(semua, r.kode);
      // Relawan nonaktif: tetap wajib dibagikan ulang kalau akunnya berubah
      // (supaya akun nonaktif benar-benar tidak bisa login di HP-nya).
      if (s.akunBelumBerlaku) akun++;
      if (!r.isAktif) continue;
      if (s.perluDibagikan) perlu++;
      if (!s.belumPernahDibagikan && s.belumKirimHariIni()) {
        belum++;
        namaBelum.add(r.nama);
      }
    }
    if (!mounted) return;
    setState(() {
      _perluDibagikan = perlu;
      _akunBelumBerlaku = akun;
      _belumKirim = belum;
      _namaBelumKirim = namaBelum..sort();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (PerangkatService.isAnggota ||
        (_perluDibagikan == 0 && _akunBelumBerlaku == 0 && _belumKirim == 0)) {
      return const SizedBox.shrink();
    }
    final p = AppPalette.of(context);
    final warna = _akunBelumBerlaku > 0 ? AppColors.error : AppColors.sun;
    final baris = [
      if (_akunBelumBerlaku > 0)
        '$_akunBelumBerlaku HP relawan memakai AKUN LAMA (PIN/status belum berlaku): bagikan ulang.',
      if (_perluDibagikan > 0) '$_perluDibagikan HP relawan perlu dibagikan (ulang).',
      if (_belumKirim > 0)
        '$_belumKirim relawan belum setor data hari ini: '
            '${_namaBelumKirim.take(3).join(', ')}'
            '${_namaBelumKirim.length > 3 ? ' (+${_namaBelumKirim.length - 3} lagi)' : ''}. '
            'Ingatkan untuk KIRIM DATA KE ADMIN.',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: warna.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: widget.onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: warna.withValues(alpha: 0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.notifications_active_rounded, color: warna),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PENGINGAT HP RELAWAN', style: AppTextStyles.cardTitle(p)),
                      const SizedBox(height: 4),
                      for (final b in baris)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('• $b', style: AppTextStyles.small(p)),
                        ),
                      if (widget.onTap != null) ...[
                        const SizedBox(height: 6),
                        Text('Ketuk untuk melihat relawan →',
                            style: AppTextStyles.small(p).copyWith(color: warna)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
