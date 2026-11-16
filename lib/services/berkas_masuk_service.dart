// ============================================================
// berkas_masuk_service.dart
// "BUKA DENGAN LOGEVA": file ZIP yang diketuk dari notifikasi Quick
// Share / Bluetooth, WhatsApp, atau aplikasi File dikirim Android ke
// aplikasi ini. Di sini jenis file dikenali lalu disimpan sementara
// sampai halaman yang tepat mengambilnya (lihat routes/buka_berkas_masuk.dart).
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../utils/berkas_terkunci.dart';
import 'cadangan_service.dart';
import 'csv_service.dart';
import 'penyiapan_service.dart';

enum JenisBerkas {
  /// File Penyiapan dari HP Induk (penyiapan.json saja).
  penyiapan,

  /// File Sinkron Antar-HP (CSV paket + mungkin penyiapan.json).
  sinkron,

  /// Cadangan seluruh data HP.
  cadangan,

  /// Paket dari website pusat (diimpor di HP Induk).
  paketWebsite,

  /// Paket Data Posko buatan aplikasi: untuk diimpor di WEBSITE.
  paketAplikasi,

  /// File terkunci yang jenisnya tidak bisa ditebak dari namanya
  /// (pengguna memilih: cadangan atau paket website).
  terkunciLain,

  tidakDikenal,
}

typedef BerkasMasuk = ({String name, Uint8List bytes});

class BerkasMasukService {
  BerkasMasukService._();

  static ({String name, Uint8List bytes, JenisBerkas jenis})? _tertunda;

  /// Jenis file yang sedang menunggu dibuka (null = tidak ada).
  static JenisBerkas? get jenisTertunda => _tertunda?.jenis;

  static void simpan(String name, Uint8List bytes, JenisBerkas jenis) =>
      _tertunda = (name: name, bytes: bytes, jenis: jenis);

  static void buang() => _tertunda = null;

  /// Ambil file yang menunggu kalau jenisnya [jenis] (sekali pakai).
  static BerkasMasuk? ambil(JenisBerkas jenis) {
    final t = _tertunda;
    if (t == null || t.jenis != jenis) return null;
    _tertunda = null;
    return (name: t.name, bytes: t.bytes);
  }

  /// Kenali jenis file dari isi ZIP (dan namanya untuk file terkunci, yang
  /// isinya baru bisa dibaca setelah kata sandi diketik).
  static JenisBerkas kenali(String nama, List<int> bytes) {
    final n = nama.toLowerCase();
    if (BerkasTerkunci.terkunci(bytes)) {
      if (n.contains('cadangan')) return JenisBerkas.cadangan;
      if (n.contains('paket_pusat')) return JenisBerkas.paketWebsite;
      if (n.contains('paket_')) return JenisBerkas.paketAplikasi;
      return JenisBerkas.terkunciLain;
    }
    final Archive arsip;
    try {
      arsip = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return JenisBerkas.tidakDikenal;
    }
    if (arsip.findFile(CadanganService.namaJson) != null) return JenisBerkas.cadangan;
    final info = arsip.findFile('info.csv');
    if (info != null) {
      try {
        final baris = CsvService.decode(utf8.decode(info.content, allowMalformed: true));
        if (baris.isNotEmpty && baris.first['sumber'] == 'website') {
          return JenisBerkas.paketWebsite;
        }
      } catch (_) {
        // dianggap file sinkron
      }
      return n.contains('paket_') && !n.contains('sinkron')
          ? JenisBerkas.paketAplikasi
          : JenisBerkas.sinkron;
    }
    if (arsip.findFile(FilePenyiapan.namaJson) != null) return JenisBerkas.penyiapan;
    return JenisBerkas.tidakDikenal;
  }
}
