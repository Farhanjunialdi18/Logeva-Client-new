// KOSONGKAN HP oleh relawan: ditolak selama masih ada data yang belum
// disetor ke admin (data tidak boleh hilang tanpa sampai ke admin).

import 'package:flutter/material.dart';
import 'package:flutter_application_1/data/demo_data.dart';
import 'package:flutter_application_1/data/local_database.dart';
import 'package:flutter_application_1/data/memory_table_store.dart';
import 'package:flutter_application_1/data/repositories/pengaturan_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/models/relawan_session.dart';
import 'package:flutter_application_1/services/perangkat_service.dart';
import 'package:flutter_application_1/services/session_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/kosongkan_hp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LocalDatabase.store = MemoryTableStore(seed: DemoData.seed());

  testWidgets('relawan dengan data belum disetor tidak bisa mengosongkan HP',
      (tester) async {
    PerangkatService.anggota.value = true;
    addTearDown(() => PerangkatService.anggota.value = false);
    SessionService.instance.startRelawan(const RelawanSession(
        nama: 'Andi Saputra', relawanId: 1, poskoId: 1, posko: 'Desa Panggarangan'));
    await tester.runAsync(() => PengaturanRepository.instance.tambahPerubahanLokal(2));

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => KosongkanHp.jalankan(context),
            child: const Text('KOSONGKAN'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('KOSONGKAN'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump();
    }

    expect(find.text('Setor data dulu'), findsOneWidget);
    expect(find.textContaining('2 perubahan yang BELUM disetor'), findsOneWidget);
    expect(find.text('Kosongkan HP ini?'), findsNothing, reason: 'tidak lanjut');
    expect(await tester.runAsync(() => PoskoRepository.instance.count()), greaterThan(0),
        reason: 'data tidak terhapus');
  });
}
