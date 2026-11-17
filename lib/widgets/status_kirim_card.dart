// ============================================================
// status_kirim_card.dart
// STATUS KIRIM DATA KE ADMIN (beranda & Sinkron, HP Anggota saja):
//  - berapa catatan di HP ini yang BELUM dikirim ke admin (+ pengingat,
//    karena data yang belum dikirim hilang kalau HP rusak/hilang);
//  - kapan terakhir dikirim, dan apakah ADMIN SUDAH MENGGABUNGKANNYA
//    (tanda terima ikut di file balasan dari HP Induk);
//  - kapan data dari admin terakhir diterima.
// ============================================================

import 'package:flutter/material.dart';

import '../data/data_events.dart';
import '../services/perangkat_service.dart';
import '../services/sinkron_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/date_formatter.dart';
import 'kirim_ke_admin_button.dart';

class StatusKirimCard extends StatefulWidget {
  /// false = tanpa tombol KIRIM (halaman Sinkron punya tombolnya sendiri).
  final bool tampilkanTombol;

  const StatusKirimCard({super.key, this.tampilkanTombol = true});

  /// Belum dikirim selama ini = pengingat ditampilkan lebih tegas.
  static const Duration batasPengingat = Duration(hours: 4);

  @override
  State<StatusKirimCard> createState() => _StatusKirimCardState();
}

class _StatusKirimCardState extends State<StatusKirimCard> {
  StatusKirim? _status;

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
    final s = await SinkronService.statusKirim();
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    if (!PerangkatService.isAnggota || s == null) return const SizedBox.shrink();
    final p = AppPalette.of(context);

    final belum = s.belumTerkirim;
    final terlambat = s.terakhirKirim == null ||
        DateTime.now().difference(s.terakhirKirim!) > StatusKirimCard.batasPengingat;
    final warna = belum == 0
        ? AppColors.success
        : terlambat
            ? AppColors.error
            : AppColors.sun;

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
              Icon(
                belum == 0 ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
                color: warna,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  belum == 0
                      ? 'Semua catatan sudah dikirim ke admin'
                      : '$belum perubahan BELUM dikirim ke admin',
                  style: AppTextStyles.cardTitle(p),
                ),
              ),
            ],
          ),
          if (belum > 0 && terlambat)
            baris(
              Icons.warning_amber_rounded,
              AppColors.error,
              'Kirim sekarang. Data yang belum dikirim akan HILANG kalau HP ini '
              'rusak, hilang, atau baterai habis total.',
            ),
          baris(
            Icons.upload_rounded,
            p.textSecondary,
            s.terakhirKirim == null
                ? 'Belum pernah mengirim data ke admin.'
                : 'Terakhir dikirim: ${DateFormatter.full(s.terakhirKirim!)} '
                    '(${DateFormatter.lamaSejak(s.terakhirKirim!)}).',
          ),
          if (s.terakhirKirim != null)
            s.sudahDikonfirmasi
                ? baris(Icons.verified_rounded, AppColors.success,
                    'Admin sudah menggabungkan kiriman terakhir Anda.')
                : baris(
                    Icons.hourglass_top_rounded,
                    AppColors.sun,
                    s.diterimaInduk == null
                        ? 'Belum ada konfirmasi dari admin. Konfirmasi muncul '
                            'setelah admin menggabungkan data Anda lalu mengirim '
                            'data gabungan ke HP ini.'
                        : 'Kiriman terakhir belum dikonfirmasi admin (yang sudah '
                            'digabung: kiriman ${DateFormatter.full(s.diterimaInduk!)}).',
                  ),
          baris(
            Icons.download_rounded,
            p.textSecondary,
            s.terakhirDariInduk == null
                ? 'Belum pernah menerima data gabungan dari admin.'
                : 'Data dari admin terakhir: ${DateFormatter.full(s.terakhirDariInduk!)}.',
          ),
          if (widget.tampilkanTombol) ...[
            const SizedBox(height: 12),
            const KirimKeAdminButton(),
          ],
        ],
      ),
    );
  }
}
