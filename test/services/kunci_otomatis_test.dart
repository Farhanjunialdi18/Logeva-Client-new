// Kunci otomatis: 10 menit tidak disentuh -> keluar ke layar awal.

import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/relawan_session.dart';
import 'package:flutter_application_1/routes/app_routes.dart';
import 'package:flutter_application_1/services/kunci_otomatis.dart';
import 'package:flutter_application_1/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final kunci = KunciOtomatis.instance;
  var sekarang = DateTime(2026, 10, 27, 9);

  setUp(() {
    sekarang = DateTime(2026, 10, 27, 9);
    kunci.jam = () => sekarang;
  });
  tearDown(() {
    kunci.jam = DateTime.now;
    SessionService.instance.clear();
  });

  Future<void> pasang(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      navigatorKey: kunci.navigatorKey,
      builder: (context, child) => kunci.bungkus(child!),
      routes: {
        AppRoutes.roleSelection: (_) => const Scaffold(body: Text('LAYAR AWAL')),
        '/data': (_) => const Scaffold(body: Center(child: Text('DATA PENGUNGSI'))),
      },
      initialRoute: '/data',
    ));
    SessionService.instance.startRelawan(
        const RelawanSession(nama: 'Andi', poskoId: 1, posko: 'Balai Desa'));
    kunci.sentuh();
  }

  testWidgets('tidak dipakai 10 menit: keluar ke layar awal', (tester) async {
    await pasang(tester);

    sekarang = sekarang.add(const Duration(minutes: 9));
    expect(kunci.periksa(), isFalse);
    expect(SessionService.instance.relawan, isNotNull);

    sekarang = sekarang.add(const Duration(minutes: 1));
    expect(kunci.periksa(), isTrue);
    await tester.pumpAndSettle();
    expect(SessionService.instance.relawan, isNull);
    expect(find.text('LAYAR AWAL'), findsOneWidget);
    expect(find.textContaining('dikunci karena tidak dipakai 10 menit'), findsOneWidget);
  });

  testWidgets('menyentuh layar menunda kunci', (tester) async {
    await pasang(tester);
    sekarang = sekarang.add(const Duration(minutes: 8));
    await tester.tap(find.text('DATA PENGUNGSI'));
    sekarang = sekarang.add(const Duration(minutes: 8));
    expect(kunci.periksa(), isFalse, reason: 'baru 8 menit sejak disentuh');
    expect(SessionService.instance.relawan, isNotNull);
  });

  testWidgets('belum login: tidak ada yang dikunci', (tester) async {
    await pasang(tester);
    SessionService.instance.clear();
    sekarang = sekarang.add(const Duration(hours: 1));
    expect(kunci.periksa(), isFalse);
  });
}
