// Layar awal: tautan "HP baru / pindah posko?" dan daftar file dari folder HP.

import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/role_selection/role_selection_screen.dart';
import 'package:flutter_application_1/services/perangkat_service.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/pilih_dari_hp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> buka(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('HP admin/baru: dua pilihan dalam satu tautan', (tester) async {
    await buka(tester, const RoleSelectionScreen());
    expect(find.text('Pulihkan HP pengganti dari cadangan'), findsNothing, reason: 'dirapikan');
    await tester.tap(find.text('HP baru / pindah posko?'));
    await tester.pumpAndSettle();
    expect(find.text('Buka file dari HP admin'), findsOneWidget);
    expect(find.text('Pulihkan HP pengganti'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HP relawan: hanya buka file (pemulihan khusus HP admin)', (tester) async {
    PerangkatService.anggota.value = true;
    addTearDown(() => PerangkatService.anggota.value = false);
    await buka(tester, const RoleSelectionScreen());
    await tester.tap(find.text('HP baru / pindah posko?'));
    await tester.pumpAndSettle();
    expect(find.text('Buka file dari HP admin'), findsOneWidget);
    expect(find.text('Pulihkan HP pengganti'), findsNothing);
  });

  testWidgets('daftar file HP: belum ada folder -> ajakan pilih folder sekali', (tester) async {
    await buka(tester, Builder(
      builder: (c) => Scaffold(
        body: TextButton(
          onPressed: () => PilihDariHp.show(c, const ['.zip']),
          child: const Text('BUKA'),
        ),
      ),
    ));
    await tester.tap(find.text('BUKA'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('PILIH FOLDER FILE MASUK'), findsOneWidget);
    expect(find.text('CARI MANUAL'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
