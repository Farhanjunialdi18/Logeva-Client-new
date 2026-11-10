// ============================================================
// impor_website_bagian.dart
// IMPORT PAKET DARI WEBSITE PUSAT (HP Induk): file dari menu website
// Paket Data Posko → Export paket untuk aplikasi.
//  1. Pilih file ZIP (dikunci kata sandi yang dibuat admin website)
//  2. Pratinjau: posko baru / diperbarui, pengungsi, barang masuk & keluar
//  3. Gabungkan (tidak dobel; posko yang belum ada di HP ini ditambahkan)
// Aturan penggabungan ada di gabung_paket_service.dart.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/riwayat_repository.dart';
import '../../../models/riwayat_transaksi.dart';
import '../../../services/file_service.dart';
import '../../../services/gabung_paket_service.dart';
import '../../../services/perangkat_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/berkas_terkunci.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/minta_kata_sandi_dialog.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/secondary_button.dart';

class ImporWebsiteBagian extends StatefulWidget {
  const ImporWebsiteBagian({super.key});

  @override
  State<ImporWebsiteBagian> createState() => _ImporWebsiteBagianState();
}

class _ImporWebsiteBagianState extends State<ImporWebsiteBagian> {
  static const String _label = 'Paket dari Website';

  bool _sibuk = false;
  List<int>? _bytes; // isi paket yang sudah dibuka kuncinya
  String? _namaFile;
  HasilGabung? _pratinjau;
  HasilGabung? _hasil;

  /// Buka kunci paket; kalau salah, minta ulang. null = dibatalkan.
  Future<List<int>?> _buka(List<int> berkas) async {
    String? kataSandi;
    String? salah;
    while (true) {
      try {
        return BerkasTerkunci.buka(berkas, kataSandi);
      } on BerkasTerkunciException catch (e) {
        if (!e.perluKataSandi || !mounted) rethrow;
        if (kataSandi != null) salah = 'Kata sandi salah.';
        kataSandi = await MintaKataSandiDialog.show(
          context,
          judul: 'Kata sandi paket',
          pesan: 'Paket dari website dikunci. Masukkan kata sandi yang dibuat '
              'admin website saat mengekspor paket ini.',
          pesanSalah: salah,
        );
        if (kataSandi == null) return null;
      }
    }
  }

  Future<void> _pilih() async {
    setState(() => _sibuk = true);
    try {
      final f = await FileService.pickZip();
      if (f == null) return;
      final bytes = await _buka(f.bytes);
      if (bytes == null) return;
      final cek = await GabungPaketService.periksaWebsite(bytes);
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _namaFile = f.name;
        _pratinjau = cek;
        _hasil = null;
      });
    } on GabungException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message, isError: true);
    } on BerkasTerkunciException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message, isError: true);
    } on FileServiceException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _gabungkan() async {
    final bytes = _bytes;
    if (bytes == null) return;
    final yakin = await ConfirmDialog.show(
      context,
      title: 'Gabungkan data website?',
      message: 'Posko yang belum ada di HP ini ditambahkan. Data yang sudah ada '
          'hanya diperbarui jika versi website lebih baru. Setelah itu, kirim '
          'data ke HP Anggota lewat Sinkron Antar-HP.',
      confirmText: 'GABUNGKAN',
    );
    if (!yakin || !mounted) return;

    setState(() => _sibuk = true);
    try {
      final hasil = await GabungPaketService.terapkanWebsite(bytes);
      await RiwayatRepository.instance.log(
        jenis: RiwayatTransaksi.jenisImport,
        jenisData: _label,
        berhasil: true,
        keterangan: '${_namaFile ?? ''}: ${hasil.ringkasan}',
      );
      DataEvents.instance.notifyChanged();
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _pratinjau = null;
        _hasil = hasil;
      });
      AppSnackbar.show(context, 'Data website digabung. ${hasil.ringkasan}.');
    } on GabungException catch (e) {
      await RiwayatRepository.instance.log(
        jenis: RiwayatTransaksi.jenisImport,
        jenisData: _label,
        berhasil: false,
        keterangan: e.message,
      );
      if (mounted) AppSnackbar.show(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  static String _angka(Map<String, int> m) {
    final bagian = [
      if ((m[BarisGabung.tambah] ?? 0) > 0) '${m[BarisGabung.tambah]} baru',
      if ((m[BarisGabung.perbarui] ?? 0) > 0) '${m[BarisGabung.perbarui]} diperbarui',
      if ((m[BarisGabung.hapus] ?? 0) > 0) '${m[BarisGabung.hapus]} dihapus',
      if ((m[BarisGabung.sama] ?? 0) > 0) '${m[BarisGabung.sama]} sudah ada',
      if ((m[BarisGabung.error] ?? 0) > 0) '${m[BarisGabung.error]} error',
    ];
    return bagian.isEmpty ? '-' : bagian.join(', ');
  }

  Widget _kotak(Color warna, IconData ikon, String teks) {
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
            child: Text(teks,
                style: AppTextStyles.small(p).copyWith(color: p.textPrimary)),
          ),
        ],
      ),
    );
  }

  List<Widget> _bagianPratinjau(HasilGabung d) {
    final masalah = [
      for (final b in [...d.posko, ...d.pengungsi, ...d.masuk, ...d.keluar])
        if (b.status == BarisGabung.error) '${b.nama}: ${b.alasan}',
    ];
    final poskoBaru = [
      for (final b in d.posko)
        if (b.status == BarisGabung.tambah) b.nama,
    ];
    return [
      const SizedBox(height: 14),
      InfoCard(
        title: 'ISI PAKET WEBSITE',
        rows: {
          'File': _namaFile ?? '-',
          'Diekspor oleh': d.dieksporOleh.isEmpty ? '-' : d.dieksporOleh,
          'Dibuat': '${d.dibuatPada} WIB',
          'Posko': _angka(d.ringkasanPosko),
          if (poskoBaru.isNotEmpty) 'Posko baru': poskoBaru.join(', '),
          'Pengungsi': _angka(d.ringkasanPengungsi),
          'Barang masuk': _angka(d.ringkasanMasuk),
          'Barang keluar': _angka(d.ringkasanKeluar),
          if (d.barangBaru.isNotEmpty) 'Barang baru': d.barangBaru.join(', '),
        },
        note: 'Data yang sudah ada tidak dobel. Akun petugas dari website tidak '
            'ikut: relawan untuk posko baru ditambahkan di Kelola Relawan.',
      ),
      if (masalah.isNotEmpty) ...[
        const SizedBox(height: 12),
        _kotak(AppColors.error, Icons.error_outline_rounded,
            'Tidak diambil:\n• ${masalah.take(10).join('\n• ')}'
            '${masalah.length > 10 ? '\n…dan ${masalah.length - 10} lainnya' : ''}'),
      ],
      const SizedBox(height: 14),
      if (!d.adaPerubahan)
        _kotak(AppColors.success, Icons.check_circle_outline,
            'Semua data di paket ini sudah ada di HP ini.')
      else
        PrimaryButton(
          text: 'GABUNGKAN',
          isLoading: _sibuk,
          onPressed: _gabungkan,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final cek = _pratinjau;
    final hasil = _hasil;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('IMPORT DARI WEBSITE PUSAT', style: AppTextStyles.label(p)),
        const SizedBox(height: 8),
        Text(
          'Untuk HP posko yang baru, atau setelah ada data yang dicatat di '
          'website. File dibuat admin website di menu Paket Data Posko → '
          'Export paket untuk aplikasi.',
          style: AppTextStyles.small(p),
        ),
        const SizedBox(height: 12),
        if (PerangkatService.isAnggota)
          _kotak(AppColors.accentBlue, Icons.info_outline_rounded,
              'Hanya di HP Induk. HP Anggota menerima datanya lewat Sinkron '
              'Antar-HP dari HP Induk.')
        else ...[
          SecondaryButton(
            text: cek == null ? 'PILIH PAKET DARI WEBSITE' : 'PILIH FILE LAIN',
            icon: Icons.cloud_download_outlined,
            height: 54,
            isLoading: _sibuk && cek == null,
            onPressed: _sibuk ? null : _pilih,
          ),
          if (cek != null) ..._bagianPratinjau(cek),
          if (cek == null && hasil != null) ...[
            const SizedBox(height: 14),
            _kotak(AppColors.success, Icons.check_circle_outline,
                'Digabung: ${hasil.ringkasan}. Hapus file paket dari HP/flashdisk '
                'karena berisi data pribadi.'),
            if (hasil.selisihStok.isNotEmpty) ...[
              const SizedBox(height: 12),
              _kotak(AppColors.sun, Icons.warning_amber_rounded,
                  'Stok di HP berbeda dengan website (stok HP dihitung dari '
                  'catatan barang masuk & keluar):\n• '
                  '${hasil.selisihStok.take(10).join('\n• ')}'
                  '${hasil.selisihStok.length > 10 ? '\n…dan ${hasil.selisihStok.length - 10} lainnya' : ''}'),
            ],
          ],
        ],
      ],
    );
  }
}
