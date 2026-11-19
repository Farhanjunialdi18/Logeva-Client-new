// ============================================================
// pilih_dari_hp.dart
// BUKA FILE TANPA MENCARI DI PEMILIH FILE ANDROID: LOGEVA menampilkan
// sendiri daftar file dari folder tempat file masuk (Quick Share,
// Bluetooth, dokumen WhatsApp), terbaru di atas. Folder dipilih SEKALI
// saja; izinnya disimpan Android. File LOGEVA ditandai.
// Masih ada jalan "CARI MANUAL" (pemilih file Android biasa).
// Dipasang ke FileService.pemilihHp di main.dart.
// ============================================================

import 'package:flutter/material.dart';

import '../services/file_service.dart';
import '../services/kunci_otomatis.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PilihDariHp {
  PilihDariHp._();

  static const Object _cariManual = 'cariManual';

  static void pasang() {
    FileService.pemilihHp = (ekstensi) async {
      final ctx = KunciOtomatis.instance.navigatorKey.currentContext;
      if (ctx == null) return const HasilFlashdisk.cariDiHp();
      return show(ctx, ekstensi);
    };
  }

  static Future<HasilFlashdisk> show(BuildContext context, List<String> ekstensi) async {
    final dipilih = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      builder: (c) => _Daftar(ekstensi: ekstensi),
    );
    if (dipilih == null) return const HasilFlashdisk.batal();
    if (dipilih == _cariManual) return const HasilFlashdisk.cariDiHp();
    final berkas = dipilih as BerkasFlashdisk;
    final bytes = await FileService.bacaFlashdisk(berkas);
    return HasilFlashdisk.dipilih((name: berkas.nama, bytes: bytes));
  }
}

class _Daftar extends StatefulWidget {
  final List<String> ekstensi;
  const _Daftar({required this.ekstensi});

  @override
  State<_Daftar> createState() => _DaftarState();
}

class _DaftarState extends State<_Daftar> {
  List<FolderHp> _folder = [];
  List<BerkasFlashdisk> _berkas = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _muat();
  }

  Future<void> _muat() async {
    setState(() => _loading = true);
    try {
      final h = await FileService.daftarFolderHp(widget.ekstensi);
      if (!mounted) return;
      setState(() {
        _folder = h.folder;
        // File LOGEVA di atas, lalu yang lain; masing-masing terbaru dulu.
        _berkas = [
          ...h.berkas.where((b) => _logeva(b)),
          ...h.berkas.where((b) => !_logeva(b)),
        ];
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static bool _logeva(BerkasFlashdisk b) => b.nama.toLowerCase().contains('logeva');

  Future<void> _tambahFolder() async {
    final nama = await FileService.izinFolderHp();
    if (nama != null) await _muat();
  }

  static String _waktu(DateTime w) {
    String d(int n) => n.toString().padLeft(2, '0');
    return '${d(w.day)}/${d(w.month)} ${d(w.hour)}:${d(w.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final belumAdaFolder = !_loading && _folder.isEmpty;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_open_rounded, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Pilih file', style: AppTextStyles.cardTitle(p))),
                ],
              ),
              const SizedBox(height: 6),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (belumAdaFolder) ...[
                Text(
                  'Supaya tidak perlu mencari file setiap kali, pilih SEKALI folder '
                  'tempat file masuk:\n'
                  '• Quick Share: Download → Quick Share\n'
                  '• Bluetooth: Download → Bluetooth (atau folder Bluetooth)\n'
                  'Buka foldernya, lalu tekan "Gunakan folder ini" → Izinkan.',
                  style: AppTextStyles.small(p).copyWith(color: p.textPrimary),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _tambahFolder,
                  icon: const Icon(Icons.create_new_folder_rounded),
                  label: const Text('PILIH FOLDER FILE MASUK'),
                ),
              ] else ...[
                Text(
                  'Dari folder: ${_folder.map((f) => f.nama).join(', ')}. '
                  'Ketuk file yang mau dibuka; terbaru di atas.',
                  style: AppTextStyles.small(p),
                ),
                const SizedBox(height: 8),
                if (_berkas.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Belum ada file ${widget.ekstensi.join('/')} di folder ini. '
                      'File dikirim ke folder lain? Tambah folder, atau cari manual.',
                      style: AppTextStyles.small(p).copyWith(color: AppColors.sun),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _berkas.length,
                      itemBuilder: (_, i) {
                        final b = _berkas[i];
                        final logeva = _logeva(b);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.folder_zip_rounded,
                              color: logeva ? AppColors.primary : p.textSecondary),
                          title: Text(b.nama, style: AppTextStyles.body(p)),
                          subtitle: Text('${b.folder} · ${_waktu(b.waktu)}',
                              style: AppTextStyles.small(p)),
                          trailing: i == 0 && logeva
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
              ],
              const SizedBox(height: 4),
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('BATAL'),
                  ),
                  if (!_loading && !belumAdaFolder)
                    TextButton.icon(
                      onPressed: _tambahFolder,
                      icon: const Icon(Icons.create_new_folder_rounded, size: 18),
                      label: const Text('+ FOLDER'),
                    ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(PilihDariHp._cariManual),
                    icon: const Icon(Icons.search_rounded, size: 18),
                    label: const Text('CARI MANUAL'),
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
