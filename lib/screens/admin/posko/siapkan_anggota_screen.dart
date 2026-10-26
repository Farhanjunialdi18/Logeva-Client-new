// ============================================================
// siapkan_anggota_screen.dart
// SIAPKAN HP ANGGOTA (di HP Induk): membuat File Penyiapan Posko lalu
// mengirimnya ke HP relawan lewat Bluetooth / Quick Share / flashdisk.
// Tanpa internet sama sekali.
// ============================================================

import 'package:flutter/material.dart';

import '../../../models/posko.dart';
import '../../../services/file_service.dart';
import '../../../services/penyiapan_service.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/app_snackbar.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/langkah_card.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/secondary_button.dart';

class SiapkanAnggotaScreen extends StatefulWidget {
  final Posko posko;

  const SiapkanAnggotaScreen({super.key, required this.posko});

  @override
  State<SiapkanAnggotaScreen> createState() => _SiapkanAnggotaScreenState();
}

class _SiapkanAnggotaScreenState extends State<SiapkanAnggotaScreen> {
  RencanaPenyiapan? _rencana;
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await PenyiapanService.rencana(widget.posko);
    if (!mounted) return;
    setState(() => _rencana = r);
  }

  /// [bagikan] true = menu Bagikan (Bluetooth/Quick Share), false = simpan file.
  Future<void> _kirim({required bool bagikan}) async {
    final yakin = await ConfirmDialog.show(
      context,
      title: 'Berisi akun posko',
      message: 'File ini berisi akun admin & relawan (PIN dan password sudah '
          'diacak). Kirim hanya ke HP relawan posko ini, lalu HAPUS file setelah '
          'dipakai di HP tujuan.',
      confirmText: 'SAYA MENGERTI',
    );
    if (!yakin || !mounted) return;

    setState(() => _sibuk = true);
    try {
      final (nama, bytes) = await PenyiapanService.buat(
        widget.posko,
        dibuatOleh: SessionService.instance.namaPencatat,
      );
      final terkirim = bagikan
          ? await FileService.bagikan(nama, bytes, judul: 'Kirim File Penyiapan')
          : await FileService.saveBytes(nama, bytes,
              dialogTitle: 'Simpan File Penyiapan');
      if (!mounted) return;
      if (terkirim) {
        AppSnackbar.show(
          context,
          bagikan
              ? 'File $nama siap dikirim. Di HP tujuan: buka aplikasi → '
                  '"Siapkan HP ini dari HP Induk".'
              : 'File $nama tersimpan.',
        );
      }
    } on PenyiapanException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message, isError: true);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final r = _rencana;

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Siapkan HP Anggota',
              subtitle: widget.posko.label,
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            Text(
              'HP ini adalah HP Induk (dipegang admin/supervisor). Buat File '
              'Penyiapan lalu kirim ke HP relawan, supaya semua HP mencatat posko '
              'yang sama dan relawan bisa login dengan PIN-nya. Tidak perlu '
              'internet.',
              style: AppTextStyles.small(p),
            ),
            const SizedBox(height: 16),
            if (r == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              InfoCard(
                title: 'ISI FILE PENYIAPAN',
                rows: {
                  'Posko': r.posko.nama,
                  'Relawan': r.relawan.isEmpty
                      ? 'Belum ada'
                      : r.relawan.map((v) => v.nama).join(', '),
                  'Admin': r.admin.isEmpty
                      ? '-'
                      : r.admin.map((a) => a.nama).join(', '),
                  'Lainnya': 'Master barang & kategori',
                },
                note: 'PIN & password tidak ikut dalam bentuk asli. Relawan '
                    'login di HP Anggota dengan PIN yang Anda berikan.',
              ),
              const SizedBox(height: 14),
              if (r.adminBawaan.isNotEmpty) ...[
                _Peringatan(
                  r.bisaDibuat
                      ? 'Akun ${r.adminBawaan.map((a) => a.username).join(', ')} '
                          'masih memakai password bawaan, jadi TIDAK ikut dikirim.'
                      : 'Ganti dulu password bawaan admin (Settings → Keamanan). '
                          'Akun dengan password bawaan tidak boleh dibagikan.',
                ),
                const SizedBox(height: 14),
              ],
              if (r.relawan.isEmpty) ...[
                const _Peringatan(
                    'Belum ada relawan di posko ini. Tambahkan dulu di menu '
                    'Relawan supaya bisa login di HP Anggota.'),
                const SizedBox(height: 14),
              ],
              const LangkahCard(
                title: 'CARA PAKAI',
                langkah: [
                  'Tekan BAGIKAN, pilih Bluetooth atau Quick Share, lalu '
                      'pilih HP relawan.',
                  'Di HP relawan: buka aplikasi → "Siapkan HP ini dari HP '
                      'Induk" → pilih file yang diterima.',
                  'Relawan login dengan PIN-nya. Hapus file di kedua HP.',
                ],
                note: 'Ada relawan baru atau PIN diganti? Kirim ulang file ini; '
                    'HP Anggota akan memperbarui akunnya tanpa data dobel.',
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                text: 'BAGIKAN (BLUETOOTH / QUICK SHARE)',
                isLoading: _sibuk,
                onPressed: r.bisaDibuat ? () => _kirim(bagikan: true) : null,
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                text: 'SIMPAN KE FILE',
                icon: Icons.save_alt_rounded,
                height: 50,
                onPressed: r.bisaDibuat && !_sibuk
                    ? () => _kirim(bagikan: false)
                    : null,
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Peringatan extends StatelessWidget {
  final String teks;
  const _Peringatan(this.teks);

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
            child: Text(teks,
                style: AppTextStyles.small(p).copyWith(color: p.textPrimary)),
          ),
        ],
      ),
    );
  }
}
