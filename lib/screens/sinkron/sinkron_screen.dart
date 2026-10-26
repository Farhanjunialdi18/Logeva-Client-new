// ============================================================
// sinkron_screen.dart
// SINKRON ANTAR-HP SATU POSKO (tanpa internet):
//  1. KIRIM  : buat File Sinkron lalu bagikan (Bluetooth / Quick Share)
//  2. TERIMA : pilih file dari HP lain, periksa, lalu gabungkan
//  3. Riwayat file terakhir yang diterima dari setiap HP
// HP Anggota mengirim datanya ke HP Induk; HP Induk mengirim data gabungan
// (beserta pembaruan akun) kembali ke HP Anggota.
// ============================================================

import 'package:flutter/material.dart';

import '../../data/data_events.dart';
import '../../data/repositories/logistik_repository.dart';
import '../../data/repositories/posko_repository.dart';
import '../../data/repositories/riwayat_repository.dart';
import '../../models/posko.dart';
import '../../models/riwayat_transaksi.dart';
import '../../services/dobel_service.dart';
import '../../services/file_service.dart';
import '../../services/gabung_paket_service.dart';
import '../../services/perangkat_service.dart';
import '../../services/session_service.dart';
import '../../services/sinkron_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../utils/app_snackbar.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/confirm_dialog.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/info_card.dart';
import '../../widgets/langkah_card.dart';
import '../../widgets/page_header.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/secondary_button.dart';
import '../admin/data/pengungsi_dobel_screen.dart';

class SinkronScreen extends StatefulWidget {
  /// Diisi saat dipakai sebagai tab relawan (HP Anggota); kosong = halaman biasa.
  final VoidCallback? onBack;

  const SinkronScreen({super.key, this.onBack});

  @override
  State<SinkronScreen> createState() => _SinkronScreenState();
}

class _SinkronScreenState extends State<SinkronScreen> {
  static const String _label = 'Sinkron Antar-HP';

  List<Posko> _daftarPosko = [];
  int? _poskoId;
  List<RiwayatSinkron> _riwayat = [];
  bool _loading = true;
  bool _mengirim = false;
  bool _menerima = false;

  // File yang sedang diperiksa
  List<int>? _bytes;
  String? _namaFile;
  PratinjauSinkron? _pratinjau;

  /// Barang yang stoknya minus setelah digabung (dicek supervisor).
  List<String> _stokMinus = [];

  /// Grup kemungkinan pengungsi dobel setelah digabung (HP Induk).
  int _dobel = 0;

  bool get _anggota => PerangkatService.isAnggota;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final posko = await PoskoRepository.instance.getAll()
      ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    final riwayat = await SinkronService.riwayat();
    if (!mounted) return;
    setState(() {
      _daftarPosko = posko;
      if (!posko.any((p) => p.id == _poskoId)) {
        _poskoId = posko.isEmpty ? null : posko.first.id;
      }
      _riwayat = riwayat;
      _loading = false;
    });
  }

  Posko? get _posko {
    for (final p in _daftarPosko) {
      if (p.id == _poskoId) return p;
    }
    return null;
  }

  // ---------------- KIRIM ----------------

  Future<void> _kirim({required bool bagikan}) async {
    final posko = _posko;
    if (posko == null) return;
    final yakin = await ConfirmDialog.show(
      context,
      title: 'Berisi data pribadi',
      message: 'File sinkron berisi data pengungsi'
          '${_anggota ? '' : ' dan akun posko (PIN/password diacak)'}. '
          'Kirim hanya ke HP posko ini, lalu hapus file setelah diterima.',
      confirmText: 'SAYA MENGERTI',
    );
    if (!yakin || !mounted) return;

    setState(() => _mengirim = true);
    try {
      final (nama, bytes) = await SinkronService.buatFile(
        posko,
        dibuatOleh: SessionService.instance.namaPencatat,
      );
      final ok = bagikan
          ? await FileService.bagikan(nama, bytes, judul: 'Kirim File Sinkron')
          : await FileService.saveBytes(nama, bytes,
              dialogTitle: 'Simpan File Sinkron');
      if (ok) {
        await RiwayatRepository.instance.log(
          jenis: RiwayatTransaksi.jenisExport,
          jenisData: _label,
          berhasil: true,
          keterangan: nama,
        );
      }
      if (!mounted || !ok) return;
      AppSnackbar.show(
        context,
        _anggota
            ? 'File $nama siap. Terima & gabungkan di HP Induk.'
            : 'File $nama siap. Terima & gabungkan di HP Anggota.',
      );
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  // ---------------- TERIMA ----------------

  Future<void> _pilih() async {
    setState(() => _menerima = true);
    try {
      final f = await FileService.pickZip();
      if (f == null) return;
      final cek = await SinkronService.periksa(f.bytes);
      if (!mounted) return;
      setState(() {
        _bytes = f.bytes;
        _namaFile = f.name;
        _pratinjau = cek;
      });
    } on GabungException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message, isError: true);
    } on FileServiceException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _menerima = false);
    }
  }

  Future<void> _gabungkan() async {
    final bytes = _bytes;
    if (bytes == null) return;
    setState(() => _menerima = true);
    try {
      final hasil = await SinkronService.terapkan(bytes);
      await PerangkatService.muat();
      await RiwayatRepository.instance.log(
        jenis: RiwayatTransaksi.jenisImport,
        jenisData: _label,
        berhasil: true,
        keterangan: '${_namaFile ?? ''}: ${hasil.ringkasan}',
      );
      DataEvents.instance.notifyChanged();
      final minus = <String>[];
      for (final p in _daftarPosko) {
        for (final s in await LogistikRepository.instance.stokMinus(p.id)) {
          minus.add('${s.barang.namaItem} −${-s.jumlah} ${s.barang.satuan}'
              '${_daftarPosko.length > 1 ? ' (${p.nama})' : ''}');
        }
      }
      final dobel = _anggota ? 0 : await DobelService.jumlah();
      if (!mounted) return;
      setState(() {
        _bytes = null;
        _pratinjau = null;
        _stokMinus = minus;
        _dobel = dobel;
      });
      AppSnackbar.show(context, 'Data digabung. ${hasil.ringkasan}. Hapus file sinkron.');
      await _load();
    } on GabungException catch (e) {
      await RiwayatRepository.instance.log(
        jenis: RiwayatTransaksi.jenisImport,
        jenisData: _label,
        berhasil: false,
        keterangan: e.message,
      );
      if (mounted) AppSnackbar.show(context, e.message, isError: true);
    } finally {
      if (mounted) setState(() => _menerima = false);
    }
  }

  // ---------------- TAMPILAN ----------------

  static String _angka(Map<String, int> m) {
    final bagian = [
      if ((m[BarisGabung.tambah] ?? 0) > 0) '${m[BarisGabung.tambah]} baru',
      if ((m[BarisGabung.perbarui] ?? 0) > 0) '${m[BarisGabung.perbarui]} diperbarui',
      if ((m[BarisGabung.hapus] ?? 0) > 0) '${m[BarisGabung.hapus]} dihapus',
      if ((m[BarisGabung.error] ?? 0) > 0) '${m[BarisGabung.error]} error',
    ];
    return bagian.isEmpty ? 'Tidak ada perubahan' : bagian.join(', ');
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

  List<Widget> _bagianPratinjau(PratinjauSinkron cek) {
    final d = cek.data;
    return [
      const SizedBox(height: 14),
      InfoCard(
        title: 'ISI FILE',
        rows: {
          'File': _namaFile ?? '-',
          'Dari': d.dieksporOleh.isEmpty ? '-' : d.dieksporOleh,
          'Dibuat': '${d.dibuatPada} WIB',
          'Pengungsi': _angka(d.ringkasanPengungsi),
          'Barang masuk': _angka(d.ringkasanMasuk),
          'Barang keluar': _angka(d.ringkasanKeluar),
          if (cek.akun != null) 'Akun': '${cek.akun!.relawan.length} relawan, '
              '${cek.akun!.admin.length} admin diperbarui',
          if (d.barangBaru.isNotEmpty) 'Barang baru': d.barangBaru.join(', '),
        },
        note: 'Data yang sudah ada tidak dobel. Data diperbarui hanya jika '
            'versi di file lebih baru.',
      ),
      if (cek.peringatanJam != null) ...[
        const SizedBox(height: 12),
        _kotak(AppColors.sun, Icons.schedule_rounded, cek.peringatanJam!),
      ],
      const SizedBox(height: 14),
      if (cek.ditolak != null)
        _kotak(AppColors.error, Icons.block_rounded, cek.ditolak!)
      else if (!d.adaPerubahan && cek.akun == null)
        _kotak(AppColors.success, Icons.check_circle_outline,
            'Semua data di file ini sudah ada di HP ini.')
      else
        PrimaryButton(
          text: 'GABUNGKAN',
          isLoading: _menerima,
          onPressed: _gabungkan,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final cek = _pratinjau;

    return Scaffold(
      body: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Sinkron Antar-HP',
              subtitle: _anggota
                  ? 'HP Anggota · tanpa internet'
                  : 'HP Induk · tanpa internet',
              onBack: widget.onBack ?? () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            LangkahCard(
              title: 'CARA SINKRON',
              langkah: _anggota
                  ? const [
                      'KIRIM data HP ini ke HP Induk (Bluetooth / Quick Share).',
                      'HP Induk menggabungkan data dari semua HP Anggota.',
                      'TERIMA file gabungan dari HP Induk, supaya data & akun di '
                          'HP ini sama dengan HP Induk.',
                    ]
                  : const [
                      'TERIMA file dari setiap HP Anggota, lalu gabungkan.',
                      'Setelah semua masuk, KIRIM file gabungan ke HP Anggota '
                          '(ikut membawa perubahan akun & master barang).',
                    ],
              note: 'Pastikan tanggal & jam di semua HP benar.',
            ),
            const SizedBox(height: 20),

            // ---- KIRIM ----
            Text('KIRIM', style: AppTextStyles.label(p)),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_daftarPosko.isEmpty)
              const EmptyState(
                icon: Icons.home_work_outlined,
                message: 'Belum ada posko di HP ini.',
              )
            else ...[
              if (_daftarPosko.length > 1) ...[
                AppDropdownField(
                  label: 'POSKO',
                  value: _posko?.nama,
                  items: _daftarPosko.map((e) => e.nama).toList(),
                  onChanged: (v) => setState(() {
                    for (final e in _daftarPosko) {
                      if (e.nama == v) _poskoId = e.id;
                    }
                  }),
                ),
                const SizedBox(height: 12),
              ],
              PrimaryButton(
                text: _anggota ? 'KIRIM KE HP INDUK' : 'KIRIM KE HP ANGGOTA',
                isLoading: _mengirim,
                onPressed: () => _kirim(bagikan: true),
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                text: 'SIMPAN KE FILE',
                icon: Icons.save_alt_rounded,
                height: 50,
                onPressed: _mengirim ? null : () => _kirim(bagikan: false),
              ),
            ],
            const SizedBox(height: 24),

            // ---- TERIMA ----
            Text('TERIMA', style: AppTextStyles.label(p)),
            const SizedBox(height: 10),
            SecondaryButton(
              text: cek == null ? 'PILIH FILE SINKRON' : 'PILIH FILE LAIN',
              icon: Icons.folder_open_rounded,
              height: 54,
              isLoading: _menerima && cek == null,
              onPressed: _menerima ? null : _pilih,
            ),
            if (cek != null) ..._bagianPratinjau(cek),
            if (cek == null && _dobel > 0) ...[
              const SizedBox(height: 14),
              KotakKemungkinanDobel(jumlah: _dobel),
            ],
            if (cek == null && _stokMinus.isNotEmpty) ...[
              const SizedBox(height: 14),
              _kotak(
                AppColors.error,
                Icons.error_outline_rounded,
                'Setelah digabung, stok ini minus: ${_stokMinus.join(', ')}. '
                '${_anggota ? 'Sinkron lagi dengan HP Induk.' : 'Periksa di menu '
                    'Logistik: pastikan semua HP Anggota sudah mengirim datanya, '
                    'lalu catat koreksi bila perlu.'}',
              ),
            ],
            const SizedBox(height: 24),

            // ---- RIWAYAT ----
            Text('TERAKHIR DITERIMA', style: AppTextStyles.label(p)),
            const SizedBox(height: 10),
            if (_riwayat.isEmpty)
              Text('Belum pernah menerima file sinkron.',
                  style: AppTextStyles.small(p))
            else
              InfoCard(
                rows: {
                  for (final r in _riwayat)
                    '${r.oleh.isEmpty ? 'HP' : r.oleh} '
                        '(${r.kodePerangkat.length > 8 ? r.kodePerangkat.substring(0, 8) : r.kodePerangkat})':
                        '${r.waktu} WIB',
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
