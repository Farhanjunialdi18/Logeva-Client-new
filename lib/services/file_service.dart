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
      : 'Tersimpan di $lokasiTerakhir (buka aplikasi File/Files → Download → LOGEVA).';

  /// Pilih file. Di Android pemilih langsung terbuka di folder Download
  /// (tempat file Bluetooth, Quick Share & LOGEVA). null = batal.
  static Future<({String name, Uint8List bytes})?> _pilih() async {
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
    final file = await _pilih();
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
    final file = await _pilih();
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

  /// Simpan teks CSV. Hasil false = pengguna membatalkan.
  static Future<bool> saveCsv(String fileName, String content) =>
      saveBytes(fileName, Uint8List.fromList(utf8.encode(content)),
          dialogTitle: 'Simpan file CSV');

  /// Simpan file apa pun (misal ZIP Paket Data Posko).
  /// Di Android 10+ file LANGSUNG masuk ke folder Download/LOGEVA (lihat
  /// [lokasiTerakhir]); selain itu pengguna memilih lokasi.
  /// Hasil false = pengguna membatalkan.
  static Future<bool> saveBytes(
    String fileName,
    Uint8List bytes, {
    String dialogTitle = 'Simpan file',
  }) async {
    lokasiTerakhir = null;
    if (_android) {
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
