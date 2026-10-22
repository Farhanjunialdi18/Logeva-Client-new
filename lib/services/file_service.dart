// ============================================================
// file_service.dart
// Memilih file CSV (import) & menyimpan file CSV (export).
// Memakai package file_picker versi 10.x.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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

  /// Simpan teks CSV. Hasil false = pengguna membatalkan.
  static Future<bool> saveCsv(String fileName, String content) async {
    final bytes = Uint8List.fromList(utf8.encode(content));

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Simpan file CSV',
      fileName: fileName,
      bytes: bytes,
    );

    // Di web file langsung terunduh, jadi selalu dianggap berhasil.
    if (kIsWeb) return true;
    return path != null;
  }
}
