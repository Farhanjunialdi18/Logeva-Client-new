// Tes wajib ganti password bawaan admin & aturan password baru.

import 'dart:io';

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/data/repositories/admin_repository.dart';
import 'package:flutter_application_1/data/sqlite_table_store.dart';
import 'package:flutter_application_1/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('aturan password baru (sama dengan website)', () {
    test('minimal 8 karakter, huruf dan angka', () {
      expect(Validators.passwordBaru(''), isNotNull);
      expect(Validators.passwordBaru('abc123'), 'Password minimal 8 karakter.');
      expect(Validators.passwordBaru('abcdefgh'),
          'Password harus berisi huruf dan angka.');
      expect(Validators.passwordBaru('12345678'),
          'Password harus berisi huruf dan angka.');
      expect(Validators.passwordBaru('posko2026'), isNull);
    });

    test('password bawaan tidak boleh dipakai lagi', () {
      expect(Validators.passwordBaru(AdminRepository.defaultPassword),
          'Jangan memakai password bawaan.');
    });

    test('edit akun: kosong = tidak diganti', () {
      expect(Validators.passwordBaruOptional(''), isNull);
      expect(Validators.passwordBaruOptional('abc'), isNotNull);
    });
  });

  group('akun bawaan', () {
    late Directory folder;
    late SqliteTableStore store;
    late AdminRepository repo;

    setUp(() async {
      folder = await Directory.systemTemp.createTemp('logeva_admin_');
      store = SqliteTableStore(
          path: '${folder.path}/logeva.db', factory: databaseFactoryFfi);
      repo = AdminRepository.withStore(store);
      await repo.ensureDefaultAdmin();
    });

    tearDown(() async {
      await store.close();
      await folder.delete(recursive: true);
    });

    test('admin bawaan terdeteksi wajib ganti password', () async {
      final admin = (await repo.getAll()).single;
      expect(admin.username, 'admin');
      expect(admin.role, DataOptions.roleSuperAdmin);
      expect(repo.masihPasswordBawaan(admin), isTrue);
    });

    test('setelah diganti tidak diminta lagi', () async {
      final admin = (await repo.getAll()).single;
      expect(await repo.gantiPassword(admin, 'posko2026'), isNull);
      final baru = (await repo.getAll()).single;
      expect(repo.masihPasswordBawaan(baru), isFalse);
    });

    test('password lama salah / sama dengan lama ditolak', () async {
      final admin = (await repo.getAll()).single;
      expect(await repo.gantiPassword(admin, 'posko2026', lama: 'salah'),
          'Password lama salah.');
      expect(await repo.gantiPassword(admin, AdminRepository.defaultPassword),
          'Password baru harus berbeda dari password lama.');
      expect(repo.masihPasswordBawaan((await repo.getAll()).single), isTrue);
    });
  });
}
