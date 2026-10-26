// ============================================================
// status_bantuan_widgets.dart
// Tampilan status kebutuhan bantuan, warna sama artinya dengan website:
//   merah = Kritis / Butuh bantuan segera
//   kuning = Menipis / Perlu dipantau
//   hijau = Aman / Tercukupi
//   abu-abu = Belum dihitung
// ============================================================

import 'package:flutter/material.dart';

import '../services/kebutuhan_service.dart';
import '../services/ringkasan_posko_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

Color warnaStatusStok(String status, AppPalette p) => switch (status) {
      StatusStok.merah => AppColors.error,
      StatusStok.kuning => AppColors.sun,
      StatusStok.hijau => AppColors.success,
      _ => p.textSecondary,
    };

Color warnaTingkat(String? tingkat, AppPalette p) => switch (tingkat) {
      TingkatBantuan.segera => AppColors.error,
      TingkatBantuan.pantau => AppColors.sun,
      TingkatBantuan.cukup => AppColors.success,
      _ => p.textSecondary,
    };

/// Label kecil berwarna, misal "Kritis".
class StatusChip extends StatelessWidget {
  final String text;
  final Color color;

  const StatusChip({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Kartu status bantuan satu posko: tingkat, alasan, dan barang yang
/// perlu dikirim. [onTap] = buka ringkasan lengkap.
class KartuStatusBantuan extends StatelessWidget {
  final RingkasanPosko ringkasan;
  final VoidCallback? onTap;

  /// true = tampilkan nama posko di judul (daftar admin).
  final bool tampilNamaPosko;

  const KartuStatusBantuan({
    super.key,
    required this.ringkasan,
    this.onTap,
    this.tampilNamaPosko = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final b = ringkasan.bantuan;
    final warna = warnaTingkat(b.tingkat, p);
    final hari = ringkasan.posko.hariKe();

    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: warna.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_ikon(b.tingkat), color: warna, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tampilNamaPosko
                          ? ringkasan.posko.nama
                          : TingkatBantuan.kalimat(b.tingkat),
                      style: AppTextStyles.cardTitle(p),
                    ),
                  ),
                  if (tampilNamaPosko)
                    StatusChip(
                      text: TingkatBantuan.label(b.tingkat),
                      color: warna,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                [
                  '${b.jumlahPengungsi} pengungsi',
                  if (ringkasan.komposisi.kapasitas > 0)
                    'terisi ${b.persenIsi}%',
                  if (hari != null) 'hari ke-$hari',
                ].join(' · '),
                style: AppTextStyles.small(p),
              ),
              for (final a in b.alasan.take(4)) ...[
                const SizedBox(height: 4),
                Text('• $a', style: AppTextStyles.small(p)),
              ],
              if (b.kebutuhan.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Perlu dikirim (${KebutuhanService.targetHari} hari): '
                  '${b.kebutuhan.take(3).map((k) => '±${k.kekurangan} '
                      '${k.barang.satuan} ${k.barang.namaItem}').join(', ')}',
                  style: AppTextStyles.small(p).copyWith(color: p.textPrimary),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(height: 8),
                const Text(
                  'Lihat kebutuhan & komposisi ›',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static IconData _ikon(String? tingkat) => switch (tingkat) {
        TingkatBantuan.segera => Icons.warning_amber_rounded,
        TingkatBantuan.pantau => Icons.visibility_outlined,
        TingkatBantuan.cukup => Icons.check_circle_outline,
        _ => Icons.help_outline,
      };
}

Color warnaPrioritas(String prioritas, AppPalette p) => switch (prioritas) {
      PrioritasTugas.tinggi => AppColors.error,
      PrioritasTugas.sedang => AppColors.sun,
      _ => p.textSecondary,
    };

/// Daftar "Tugas Hari Ini" (sama dengan website). [batas] diisi = hanya
/// sekian tugas teratas yang ditampilkan.
class DaftarTugas extends StatelessWidget {
  final List<TugasHarian> tugas;
  final int? batas;

  const DaftarTugas({super.key, required this.tugas, this.batas});

  static IconData _ikon(String jenis) => switch (jenis) {
        'pengungsi' => Icons.person_add_alt_1_rounded,
        'logistik' => Icons.inventory_2_outlined,
        'medis' => Icons.medical_services_outlined,
        'kapasitas' => Icons.groups_rounded,
        'rentan' => Icons.elderly_rounded,
        'keluar' => Icons.local_shipping_outlined,
        _ => Icons.tune_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final tampil = batas == null ? tugas : tugas.take(batas!).toList();

    if (tugas.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tidak ada tugas mendesak. Kondisi posko terpantau aman.',
                style: AppTextStyles.small(p).copyWith(color: p.textPrimary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final t in tampil) ...[
          Container(
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.border),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: warnaPrioritas(t.prioritas, p)),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(_ikon(t.jenis),
                              size: 18, color: p.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t.teks,
                                  style: AppTextStyles.cardTitle(p)
                                      .copyWith(fontSize: 13.5),
                                ),
                                const SizedBox(height: 3),
                                Text(t.keterangan,
                                    style: AppTextStyles.small(p)),
                                const SizedBox(height: 6),
                                StatusChip(
                                  text: PrioritasTugas.label(t.prioritas),
                                  color: warnaPrioritas(t.prioritas, p),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
