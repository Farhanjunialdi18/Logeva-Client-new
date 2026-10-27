// ============================================================
// file_service.dart
// Memilih file CSV/ZIP (import), menyimpan file (export), dan membagikan
// file lewat menu Bagikan Android (Bluetooth, Quick Share, dll. — semua
// bekerja tanpa internet).
// Memakai package file_picker versi 10.x.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

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

  /// Buka pemilih file. Hasil null = pengguna membatalkan.
  static Future<PickedCsv?> pickCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any, // 'any' lebih aman di Android untuk file .csv
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    if (!file.name.toLowerCase().endsWith('.csv')) {
      throw const FileServiceException('File harus berformat .csv');
    }

    final bytes = file.bytes;
    if (bytes == null) {
      throw const FileServiceException('Isi file tidak bisa dibaca.');
    }

    return PickedCsv(
      name: file.name,
      content: utf8.decode(bytes, allowMalformed: true),
    );
  }

  /// Pilih file ZIP (File Penyiapan / paket sinkron). null = batal.
  static Future<({String name, Uint8List bytes})?> pickZip() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any, // file dari Bluetooth sering tanpa jenis yang jelas
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final file = result.files.single;
    if (!file.name.toLowerCase().endsWith('.zip')) {
      throw const FileServiceException('File harus berformat .zip');
    }
    final bytes = file.bytes;
    if (bytes == null) {
      throw const FileServiceException('Isi file tidak bisa dibaca.');
    }
    return (name: file.name, bytes: bytes);
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
  /// Hasil false = pengguna membatalkan.
  static Future<bool> saveBytes(
    String fileName,
    Uint8List bytes, {
    String dialogTitle = 'Simpan file',
  }) async {
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
