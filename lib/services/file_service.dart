// ============================================================
// file_service.dart
// Memilih file CSV/ZIP (import), menyimpan file (export), dan membagikan
// file lewat menu Bagikan Android (Bluetooth, Quick Share, dll. — semua
// bekerja tanpa internet).
// Memakai package file_picker versi 10.x.
// ============================================================

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class PickedCsv {
  final String name;
  final String content;

  const PickedCsv({required this.name, required this.content});
}

/// Satu file di flashdisk (dari [FileService.daftarFlashdisk]).
class BerkasFlashdisk {
  final String nama;
  final String folder; // '' = folder utama flashdisk
  final String uri;
  final int ukuran; // byte
  final DateTime waktu;

  const BerkasFlashdisk({
    required this.nama,
    required this.folder,
    required this.uri,
    required this.ukuran,
    required this.waktu,
  });
}

/// Hasil daftar flashdisk: file dipilih, batal, atau "cari di HP saja".
class HasilFlashdisk {
  final ({String name, Uint8List bytes})? berkas;
  final bool batal;

  const HasilFlashdisk.dipilih(({String name, Uint8List bytes}) this.berkas) : batal = false;
  const HasilFlashdisk.batal()
      : berkas = null,
        batal = true;
  const HasilFlashdisk.cariDiHp()
      : berkas = null,
        batal = false;
}

class FileServiceException implements Exception {
  final String message;
  const FileServiceException(this.message);

  @override
  String toString() => message;
}

class FileService {
  FileService._();

  /// Folder tetap tempat semua file LOGEVA disimpan di HP Android.
  static const String folderUnduhan = 'Download/LOGEVA';

  /// Lokasi file yang terakhir disimpan (misal "Download/LOGEVA/x.zip"),
  /// null kalau lokasinya dipilih sendiri lewat pemilih lokasi.
  static String? lokasiTerakhir;

  static const MethodChannel _kanal = MethodChannel('id.gmls.logeva/unduhan');

  static bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Teks lokasi untuk pesan setelah menyimpan.
  static String pesanTersimpan(String fileName) => lokasiTerakhir == null
      ? 'File $fileName tersimpan.'
      : lokasiTerakhir!.startsWith('Download/')
          ? 'Tersimpan di $lokasiTerakhir (buka aplikasi File/Files → Download → LOGEVA).'
          : 'Tersimpan di flashdisk: $lokasiTerakhir';

  // ---------------- IMPOR DARI FLASHDISK ----------------

  /// Tampilan daftar file flashdisk (diisi widgets/pilih_dari_flashdisk.dart
  /// saat aplikasi mulai, karena service tidak punya BuildContext).
  static Future<HasilFlashdisk> Function(List<String> ekstensi)? pemilihFlashdisk;

  /// Flashdisk (USB OTG) sedang tercolok?
  static Future<bool> adaFlashdisk() async {
    if (!_android) return false;
    try {
      return await _kanal.invokeMethod<bool>('adaFlashdisk') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// File berakhiran [ekstensi] di flashdisk, terbaru di atas. Pertama kali
  /// Android meminta izin sekali. null = izin dibatalkan.
  static Future<List<BerkasFlashdisk>?> daftarFlashdisk(List<String> ekstensi) async {
    try {
      final hasil = await _kanal.invokeListMethod<Map<Object?, Object?>>(
          'daftarFlashdisk', {'ekstensi': ekstensi});
      if (hasil == null) return null;
      return [
        for (final m in hasil)
          BerkasFlashdisk(
            nama: m['nama'] as String,
            folder: m['folder'] as String? ?? '',
            uri: m['uri'] as String,
            ukuran: (m['ukuran'] as num?)?.toInt() ?? 0,
            waktu: DateTime.fromMillisecondsSinceEpoch((m['waktu'] as num?)?.toInt() ?? 0),
          ),
      ];
    } on PlatformException catch (e) {
      if (e.code == 'TIDAK_ADA') {
        throw const FileServiceException('Flashdisk tidak terdeteksi lagi. Colokkan ulang.');
      }
      throw FileServiceException('Flashdisk tidak bisa dibaca: ${e.message}');
    }
  }

  static Future<Uint8List> bacaFlashdisk(BerkasFlashdisk berkas) async {
    try {
      final bytes = await _kanal.invokeMethod<Uint8List>('bacaFlashdisk', {'uri': berkas.uri});
      if (bytes == null) throw const FileServiceException('Isi file tidak bisa dibaca.');
      return bytes;
    } on PlatformException catch (e) {
      throw FileServiceException('File di flashdisk tidak bisa dibaca: ${e.message}');
    }
  }

  /// Pilih file. Kalau flashdisk tercolok, LOGEVA menampilkan sendiri daftar
  /// file di flashdisk (tanpa pemilih file Android). Selain itu pemilih
  /// langsung terbuka di folder Download (tempat file Bluetooth, Quick Share &
  /// LOGEVA). null = batal.
  static Future<({String name, Uint8List bytes})?> _pilih(List<String> ekstensi) async {
    final pemilih = pemilihFlashdisk;
    if (pemilih != null && await adaFlashdisk()) {
      final hasil = await pemilih(ekstensi);
      if (hasil.batal) return null;
      if (hasil.berkas != null) return hasil.berkas;
      // pengguna memilih "cari di HP": lanjut ke pemilih biasa
    }
    if (_android) {
      try {
        final hasil = await _kanal.invokeMapMethod<String, Object?>('pilih');
        if (hasil == null) return null;
        return (name: hasil['nama'] as String, bytes: hasil['bytes'] as Uint8List);
      } on MissingPluginException {
        // lanjut ke pemilih bawaan
      } on PlatformException catch (e) {
        if (e.code == 'GAGAL') {
          throw const FileServiceException('Isi file tidak bisa dibaca.');
        }
      }
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any, // file dari Bluetooth sering tanpa jenis yang jelas
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      throw const FileServiceException('Isi file tidak bisa dibaca.');
    }
    return (name: file.name, bytes: bytes);
  }

  /// Buka pemilih file. Hasil null = pengguna membatalkan.
  static Future<PickedCsv?> pickCsv() async {
    final file = await _pilih(const ['.csv']);
    if (file == null) return null;
    if (!file.name.toLowerCase().endsWith('.csv')) {
      throw const FileServiceException('File harus berformat .csv');
    }
    return PickedCsv(
      name: file.name,
      content: utf8.decode(file.bytes, allowMalformed: true),
    );
  }

  /// Pilih file ZIP (File Penyiapan / paket sinkron). null = batal.
  static Future<({String name, Uint8List bytes})?> pickZip() async {
    final file = await _pilih(const ['.zip']);
    if (file == null) return null;
    if (!file.name.toLowerCase().endsWith('.zip')) {
      throw const FileServiceException('File harus berformat .zip');
    }
    return file;
  }

  /// Buka menu Bagikan Android untuk mengirim file ke HP lain (Bluetooth,
  /// Quick Share/Nearby Share, dll.). Hasil false = dibatalkan.
  static Future<bool> bagikan(String fileName, Uint8List bytes,
      {String judul = 'Kirim file'}) async {
    final hasil = await SharePlus.instance.share(ShareParams(
      title: judul,
      files: [XFile.fromData(bytes, mimeType: 'application/zip', name: fileName)],
      fileNameOverrides: [fileName],
    ));
    return hasil.status != ShareResultStatus.dismissed;
  }

  /// Bagikan teks (SMS, WhatsApp, Bluetooth, dll.). Hasil false = dibatalkan.
  static Future<bool> bagikanTeks(String teks, {String judul = 'Bagikan'}) async {
    final hasil = await SharePlus.instance.share(ShareParams(text: teks, subject: judul));
    return hasil.status != ShareResultStatus.dismissed;
  }

  /// Simpan file LANGSUNG ke folder LOGEVA di flashdisk (USB OTG), tanpa
  /// mencari lokasi. Pertama kali Android meminta izin sekali (layar langsung
  /// terbuka di flashdisk, cukup tekan Izinkan). Lokasi tersimpan di
  /// [lokasiTerakhir]. Hasil false = dibatalkan.
  /// Melempar [FileServiceException] kalau flashdisk tidak terdeteksi.
  static Future<bool> simpanKeFlashdisk(String fileName, Uint8List bytes) async {
    lokasiTerakhir = null;
    if (_android) {
      try {
        lokasiTerakhir = await _kanal.invokeMethod<String>('simpanFlashdisk', {
          'nama': fileName,
          'bytes': bytes,
          'mime': fileName.toLowerCase().endsWith('.csv') ? 'text/csv' : 'application/zip',
        });
        return lokasiTerakhir != null;
      } on MissingPluginException {
        // lanjut ke pemilih lokasi
      } on PlatformException catch (e) {
        switch (e.code) {
          case 'TIDAK_ADA':
            throw const FileServiceException(
                'Flashdisk tidak terdeteksi. Colokkan flashdisk ke HP (pakai '
                'konektor OTG), tunggu sebentar, lalu coba lagi.');
          case 'BUKAN_FLASHDISK':
            throw const FileServiceException(
                'Yang dipilih bukan flashdisk. Coba lagi, lalu tekan Izinkan / '
                'Gunakan folder ini di layar flashdisk.');
          case 'GAGAL':
            throw FileServiceException('Gagal menyimpan ke flashdisk: ${e.message}');
          // TIDAK_DIDUKUNG (Android lama): lanjut ke pemilih lokasi
        }
      }
    }
    return saveBytes(fileName, bytes, dialogTitle: 'Simpan ke flashdisk', pilihLokasi: true);
  }

  /// Simpan teks CSV. Hasil false = pengguna membatalkan.
  /// Flashdisk tercolok = langsung ke flashdisk (folder LOGEVA); selain itu
  /// langsung ke Download/LOGEVA.
  static Future<bool> saveCsv(String fileName, String content) async {
    final bytes = Uint8List.fromList(utf8.encode(content));
    if (await adaFlashdisk()) return simpanKeFlashdisk(fileName, bytes);
    return saveBytes(fileName, bytes, dialogTitle: 'Simpan file CSV');
  }

  /// Simpan file apa pun (misal ZIP Paket Data Posko).
  /// Di Android 10+ file LANGSUNG masuk ke folder Download/LOGEVA (lihat
  /// [lokasiTerakhir]); selain itu pengguna memilih lokasi.
  /// [pilihLokasi] = selalu buka pemilih lokasi (misal flashdisk USB OTG).
  /// Hasil false = pengguna membatalkan.
  static Future<bool> saveBytes(
    String fileName,
    Uint8List bytes, {
    String dialogTitle = 'Simpan file',
    bool pilihLokasi = false,
  }) async {
    lokasiTerakhir = null;
    if (_android && !pilihLokasi) {
      try {
        lokasiTerakhir = await _kanal.invokeMethod<String>('simpan', {
          'nama': fileName,
          'bytes': bytes,
          'mime': fileName.toLowerCase().endsWith('.csv')
              ? 'text/csv'
              : 'application/zip',
        });
        if (lokasiTerakhir != null) return true;
      } on MissingPluginException {
        // lanjut ke pemilih lokasi
      } on PlatformException {
        // Android 9 ke bawah / gagal: lanjut ke pemilih lokasi
      }
    }
    final path = await FilePicker.platform.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      bytes: bytes,
    );

    // Di web file langsung terunduh, jadi selalu dianggap berhasil.
    if (kIsWeb) return true;
    return path != null;
  }
}
