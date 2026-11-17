// ============================================================
// pilih_dari_flashdisk.dart
// IMPOR DARI FLASHDISK TANPA PEMILIH FILE ANDROID: saat flashdisk
// tercolok, setiap tombol impor menampilkan daftar file di flashdisk
// (terbaru di atas, ditandai TERBARU). Cukup ketuk satu file.
// Pertama kali Android meminta izin flashdisk sekali.
// Dipasang ke FileService.pemilihFlashdisk di main.dart.
// ============================================================

import 'package:flutter/material.dart';

import '../services/file_service.dart';
import '../services/kunci_otomatis.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PilihDariFlashdisk {
  PilihDariFlashdisk._();

  /// Pasang ke FileService (sekali, saat aplikasi mulai).
  static void pasang() {
    FileService.pemilihFlashdisk = (ekstensi) async {
      final ctx = KunciOtomatis.instance.navigatorKey.currentContext;
      if (ctx == null) return const HasilFlashdisk.cariDiHp();
      return show(ctx, ekstensi);
    };
  }

  static Future<HasilFlashdisk> show(BuildContext context, List<String> ekstensi) async {
    final List<BerkasFlashdisk>? daftar;
    try {
      daftar = await FileService.daftarFlashdisk(ekstensi);
    } on FileServiceException {
      return const HasilFlashdisk.cariDiHp(); // flashdisk dicabut: pakai HP
    }
    if (daftar == null) return const HasilFlashdisk.batal();
    if (!context.mounted) return const HasilFlashdisk.batal();

    final dipilih = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _Daftar(daftar: daftar!, ekstensi: ekstensi),
    );
    if (dipilih == null) return const HasilFlashdisk.batal();
    if (dipilih == _cariDiHp) return const HasilFlashdisk.cariDiHp();
    final berkas = dipilih as BerkasFlashdisk;
    final bytes = await FileService.bacaFlashdisk(berkas);
    return HasilFlashdisk.dipilih((name: berkas.nama, bytes: bytes));
  }

  static const Object _cariDiHp = 'cariDiHp';
}

class _Daftar extends StatelessWidget {
  final List<BerkasFlashdisk> daftar;
  final List<String> ekstensi;

  const _Daftar({required this.daftar, required this.ekstensi});

  static String _ukuran(int b) => b >= 1024 * 1024
      ? '${(b / 1024 / 1024).toStringAsFixed(1)} MB'
      : '${(b / 1024).ceil()} KB';

  static String _waktu(DateTime w) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(w.day)}/${d(w.month)}/${w.year} ${d(w.hour)}:${d(w.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.usb_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Pilih file dari flashdisk',
                        style: AppTextStyles.cardTitle(p)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                daftar.isEmpty
                    ? 'Tidak ada file ${ekstensi.join('/')} di flashdisk (folder '
                        'utama & satu folder di bawahnya). Salin file ke flashdisk '
                        'dulu, atau cari di HP.'
                    : 'Ketuk file yang mau dibuka. Terbaru di atas.',
                style: AppTextStyles.small(p),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: daftar.length,
                  itemBuilder: (_, i) {
                    final b = daftar[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        b.nama.toLowerCase().endsWith('.csv')
                            ? Icons.table_chart_rounded
                            : Icons.folder_zip_rounded,
                        color: i == 0 ? AppColors.primary : p.textSecondary,
                      ),
                      title: Text(b.nama, style: AppTextStyles.body(p)),
                      subtitle: Text(
                        '${b.folder.isEmpty ? 'Folder utama' : b.folder} · '
                        '${_waktu(b.waktu)} · ${_ukuran(b.ukuran)}',
                        style: AppTextStyles.small(p),
                      ),
                      trailing: i == 0
                          ? const Text('TERBARU',
                              style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11))
                          : null,
                      onTap: () => Navigator.of(context).pop(b),
                    );
                  },
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('BATAL'),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(PilihDariFlashdisk._cariDiHp),
                    icon: const Icon(Icons.phone_android_rounded, size: 18),
                    label: const Text('CARI DI HP'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
