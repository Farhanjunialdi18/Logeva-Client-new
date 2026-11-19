// ============================================================
// buka_berkas_masuk.dart
// Membuka halaman yang tepat untuk file "Buka dengan LOGEVA":
//   File dari HP admin (akun) -> siapkan HP relawan (Sinkronkan data?)
//   File Sinkron    -> Sinkron Antar-HP        (perlu login)
//   Cadangan        -> Pulihkan Cadangan       (layar awal / admin)
//   Paket website   -> Paket Data Posko        (perlu login admin)
// Kalau perlu login, file disimpan dulu dan dibuka otomatis setelah login
// (admin_shell_screen / relawan_shell_screen memanggil lanjutkan()).
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/repositories/admin_repository.dart';
import '../data/repositories/relawan_repository.dart';
import '../screens/admin/paket/paket_data_screen.dart';
import '../screens/cadangan/cadangan_screen.dart';
import '../services/berkas_masuk_service.dart';
import '../services/kunci_otomatis.dart';
import '../services/session_service.dart';
import '../services/sinkron_service.dart';
import '../utils/app_snackbar.dart';
import '../widgets/sinkron_otomatis.dart';
import 'app_routes.dart';

class BukaBerkasMasuk {
  BukaBerkasMasuk._();

  static const MethodChannel _kanal = MethodChannel('id.gmls.logeva/unduhan');
  static bool _mulai = false;

  /// Dipanggil sekali setelah runApp.
  static void mulai() {
    if (_mulai) return;
    _mulai = true;
    _kanal.setMethodCallHandler((call) async {
      if (call.method == 'berkasMasuk') await _ambil();
    });
    // File yang membuka aplikasi dari keadaan tertutup.
    WidgetsBinding.instance.addPostFrameCallback((_) => _ambil());
  }

  static Future<void> _ambil() async {
    Map<String, Object?>? hasil;
    try {
      hasil = await _kanal.invokeMapMethod<String, Object?>('ambilBerkasMasuk');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
    if (hasil == null) return;
    final nama = hasil['nama'] as String? ?? 'file.zip';
    final bytes = hasil['bytes'] as Uint8List;
    BerkasMasukService.simpan(nama, bytes, BerkasMasukService.kenali(nama, bytes));
    await lanjutkan();
  }

  static BuildContext? get _ctx => KunciOtomatis.instance.navigatorKey.currentContext;

  static void _pesan(String teks, {bool error = false}) {
    final ctx = _ctx;
    if (ctx != null) {
      AppSnackbar.show(ctx, teks, isError: error, duration: const Duration(seconds: 6));
    }
  }

  /// Buka file yang menunggu (kalau ada) sesuai siapa yang sedang login.
  static Future<void> lanjutkan() async {
    final jenis = BerkasMasukService.jenisTertunda;
    if (jenis == null) return;
    // Kunci otomatis dulu: file tidak boleh membuka data tanpa login ulang.
    KunciOtomatis.instance.periksa();
    final nav = KunciOtomatis.instance.navigatorKey.currentState;
    if (nav == null) return;

    final sesi = SessionService.instance;
    final admin = sesi.admin;
    // Admin yang akunnya belum lengkap (password/nama bawaan) belum boleh
    // membuka apa pun.
    final adminSiap = admin != null && !AdminRepository.instance.perluDilengkapi(admin);
    final relawan = sesi.relawan != null;
    final belumLogin = admin == null && !relawan;

    void buka(Widget halaman) => nav.push(MaterialPageRoute(builder: (_) => halaman));

    switch (jenis) {
      case JenisBerkas.penyiapan:
        await _penyiapan();
      case JenisBerkas.sinkron:
        if (!adminSiap && !relawan && await _siapkanDariFile()) {
          // File dari HP Induk di HP relawan yang belum login / masih baru:
          // tanya "Sinkronkan data?" -> akun + data posko -> login PIN.
          await _penyiapan();
        } else if (await _poskoLain()) {
          // File dari HP Induk posko yang TIDAK ADA di HP ini (misal HP bekas
          // HP Induk / posko lain): tidak bisa digabung. Langsung tawarkan
          // KOSONGKAN & SIAPKAN (cadangan otomatis + password admin HP ini).
          await _penyiapan();
        } else if (adminSiap || relawan) {
          final berkas = BerkasMasukService.ambil(JenisBerkas.sinkron);
          final ctx = _ctx;
          if (berkas != null && ctx != null && ctx.mounted) {
            final ok =
                await SinkronOtomatis.sinkron(ctx, berkas.bytes, namaFile: berkas.name);
            if (ok) await periksaAkunRelawan();
          }
        } else if (belumLogin) {
          _pesan('File sinkron diterima. Login dulu, file langsung dibuka setelah login.');
        } else {
          _pesan('File sinkron diterima. Lengkapi dulu akun admin (nama & password), file '
              'langsung dibuka setelahnya.');
        }
      case JenisBerkas.cadangan:
        if (adminSiap) {
          buka(const CadanganScreen());
        } else if (belumLogin) {
          nav.pushNamed(AppRoutes.pulihkanCadangan);
        } else if (relawan) {
          BerkasMasukService.buang();
          _pesan('File cadangan hanya bisa dipulihkan oleh admin.', error: true);
        }
      case JenisBerkas.paketWebsite:
        if (adminSiap) {
          buka(const PaketDataScreen());
        } else if (relawan) {
          BerkasMasukService.buang();
          _pesan('Paket dari website hanya bisa diimpor oleh admin di HP Induk.',
              error: true);
        } else if (belumLogin) {
          _pesan('Paket dari website diterima. Login sebagai admin, file langsung '
              'dibuka setelah login.');
        }
      case JenisBerkas.terkunciLain:
        await _tanyaJenis();
      case JenisBerkas.paketAplikasi:
        BerkasMasukService.buang();
        _pesan('Ini Paket Data Posko untuk pusat. Impor di WEBSITE (menu Import '
            'Paket Posko), bukan di HP.', error: true);
      case JenisBerkas.tidakDikenal:
        BerkasMasukService.buang();
        _pesan('File ini bukan file LOGEVA (Penyiapan, Sinkron, Cadangan, atau '
            'Paket dari website).', error: true);
    }
  }

  /// Setelah akun diperbarui dari HP Induk: relawan yang sedang login tapi
  /// akunnya sudah DINONAKTIFKAN / DIHAPUS admin langsung dikeluarkan.
  static Future<void> periksaAkunRelawan() async {
    final sesi = SessionService.instance.relawan;
    final id = sesi?.relawanId;
    if (sesi == null || id == null) return;
    final akun = await RelawanRepository.instance.findById(id);
    if (akun != null && akun.isAktif) return;
    SessionService.instance.clear();
    final nav = KunciOtomatis.instance.navigatorKey.currentState;
    nav?.pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
    _pesan(
        akun == null
            ? 'Akun ${sesi.nama} sudah dihapus admin. Anda dikeluarkan dari aplikasi.'
            : 'Akun ${sesi.nama} sudah dinonaktifkan admin. Anda dikeluarkan dari aplikasi.',
        error: true);
  }

  /// "Sinkronkan data?" untuk file dari HP Induk; kalau selesai, sesi lama
  /// ditutup dan relawan langsung ke halaman login PIN.
  static Future<void> _penyiapan() async {
    final berkas = BerkasMasukService.ambil(JenisBerkas.penyiapan);
    final ctx = _ctx;
    if (berkas == null || ctx == null) return;
    final siap = await SinkronOtomatis.penyiapan(ctx, berkas.bytes);
    if (!siap) return;
    SessionService.instance.clear();
    final nav = KunciOtomatis.instance.navigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamedAndRemoveUntil(AppRoutes.roleSelection, (_) => false);
    nav.pushNamed(AppRoutes.relawanLogin);
  }

  /// File sinkron dari HP Induk yang bisa menyiapkan HP ini (HP baru atau
  /// HP Anggota posko yang sama)? Kalau ya, file dialihkan ke Penyiapan.
  static Future<bool> _siapkanDariFile() async {
    final berkas = BerkasMasukService.ambil(JenisBerkas.sinkron);
    if (berkas == null) return false;
    final bisa = await SinkronService.bisaMenyiapkan(berkas.bytes);
    BerkasMasukService.simpan(berkas.name, berkas.bytes,
        bisa ? JenisBerkas.penyiapan : JenisBerkas.sinkron);
    return bisa;
  }

  /// File sinkron dari HP Induk untuk posko yang tidak ada di HP ini?
  /// Kalau ya, file dialihkan ke Penyiapan (yang menawarkan kosongkan HP).
  static Future<bool> _poskoLain() async {
    final berkas = BerkasMasukService.ambil(JenisBerkas.sinkron);
    if (berkas == null) return false;
    final lain = await SinkronService.poskoTidakAdaDiHp(berkas.bytes);
    BerkasMasukService.simpan(berkas.name, berkas.bytes,
        lain ? JenisBerkas.penyiapan : JenisBerkas.sinkron);
    return lain;
  }

  /// File terkunci yang namanya diubah: tanyakan jenisnya.
  static Future<void> _tanyaJenis() async {
    final ctx = _ctx;
    if (ctx == null) return;
    final pilihan = await showDialog<JenisBerkas>(
      context: ctx,
      builder: (c) => SimpleDialog(
        title: const Text('File terkunci ini apa?'),
        children: [
          SimpleDialogOption(
            onPressed: () => Navigator.of(c).pop(JenisBerkas.cadangan),
            child: const Text('Cadangan HP (pulihkan data)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(c).pop(JenisBerkas.paketWebsite),
            child: const Text('Paket dari website (impor)'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.of(c).pop(),
            child: const Text('BATAL'),
          ),
        ],
      ),
    );
    final berkas = BerkasMasukService.ambil(JenisBerkas.terkunciLain);
    if (pilihan == null || berkas == null) return;
    BerkasMasukService.simpan(berkas.name, berkas.bytes, pilihan);
    await lanjutkan();
  }
}
