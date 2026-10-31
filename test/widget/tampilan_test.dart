// Tes TAMPILAN: setiap layar baru/berubah dirender dengan data demo di
// layar HP kecil (360 px), tema terang & gelap, dan teks diperbesar 130%.
// Flutter menggagalkan tes kalau ada overflow ("garis kuning-hitam")
// atau error saat menggambar, jadi tes ini menjaga UI tidak berantakan.

import 'package:flutter/material.dart';
import 'package:flutter_application_1/data/demo_data.dart';
import 'package:flutter_application_1/data/local_database.dart';
import 'package:flutter_application_1/data/memory_table_store.dart';
import 'package:flutter_application_1/data/repositories/barang_repository.dart';
import 'package:flutter_application_1/data/repositories/pengungsi_repository.dart';
import 'package:flutter_application_1/data/repositories/posko_repository.dart';
import 'package:flutter_application_1/models/admin.dart';
import 'package:flutter_application_1/models/catatan_logistik.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/screens/admin/data/pengungsi_dobel_screen.dart';
import 'package:flutter_application_1/models/relawan_session.dart';
import 'package:flutter_application_1/screens/admin/barang/barang_form_screen.dart';
import 'package:flutter_application_1/screens/admin/barang/master_barang_screen.dart';
import 'package:flutter_application_1/screens/admin/beranda/admin_beranda_screen.dart';
import 'package:flutter_application_1/screens/admin/data/admin_data_menu_screen.dart';
import 'package:flutter_application_1/screens/admin/data/admin_logistik_screen.dart';
import 'package:flutter_application_1/screens/admin/data/admin_pengungsi_screen.dart';
import 'package:flutter_application_1/screens/admin/kelola_relawan/relawan_akun_detail_screen.dart';
import 'package:flutter_application_1/screens/admin/paket/paket_data_screen.dart';
import 'package:flutter_application_1/screens/admin/posko/kelola_posko_screen.dart';
import 'package:flutter_application_1/screens/admin/posko/posko_detail_screen.dart';
import 'package:flutter_application_1/screens/admin/posko/posko_form_screen.dart';
import 'package:flutter_application_1/screens/admin_login/ganti_password_wajib_screen.dart';
import 'package:flutter_application_1/screens/relawan/beranda/beranda_screen.dart';
import 'package:flutter_application_1/screens/relawan/logistik/barang_keluar_form_screen.dart';
import 'package:flutter_application_1/screens/relawan/logistik/barang_masuk_form_screen.dart';
import 'package:flutter_application_1/screens/relawan/logistik/logistik_screen.dart';
import 'package:flutter_application_1/screens/relawan/pengungsi/pengungsi_form_screen.dart';
import 'package:flutter_application_1/screens/relawan/pengungsi/pengungsi_screen.dart';
import 'package:flutter_application_1/screens/relawan/relawan_shell_screen.dart';
import 'package:flutter_application_1/screens/dashboard/dashboard_screen.dart';
import 'package:flutter_application_1/screens/cadangan/cadangan_screen.dart';
import 'package:flutter_application_1/screens/laporan/laporan_harian_screen.dart';
import 'package:flutter_application_1/screens/relawan/info/info_posko_screen.dart';
import 'package:flutter_application_1/screens/relawan/pengungsi/catat_keluar_screen.dart';
import 'package:flutter_application_1/screens/ringkasan/ringkasan_posko_screen.dart';
import 'package:flutter_application_1/screens/admin/kelola_admin/kelola_admin_screen.dart';
import 'package:flutter_application_1/screens/admin/kelola_relawan/kelola_relawan_screen.dart';
import 'package:flutter_application_1/screens/admin/posko/siapkan_anggota_screen.dart';
import 'package:flutter_application_1/screens/admin/settings/kata_sandi_posko_screen.dart';
import 'package:flutter_application_1/screens/admin/settings/keamanan_screen.dart';
import 'package:flutter_application_1/screens/penyiapan/terima_penyiapan_screen.dart';
import 'package:flutter_application_1/screens/role_selection/role_selection_screen.dart';
import 'package:flutter_application_1/services/perangkat_service.dart';
import 'package:flutter_application_1/screens/sinkron/sinkron_screen.dart';
import 'package:flutter_application_1/services/session_service.dart';
import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/widgets/kotak_peringatan.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Data demo (sama dengan mode Chrome): posko Desa Panggarangan (id 1)
  // beroperasi, 3 pengungsi, barang masuk & keluar.
  LocalDatabase.store = MemoryTableStore(seed: DemoData.seed());

  final relawan = const RelawanSession(
    nama: 'Andi Saputra',
    poskoId: 1,
    posko: 'Desa Panggarangan',
  );
  final admin = Admin(
    id: 1,
    nama: 'Admin GMLS',
    username: 'admin',
    email: 'admin@gmls.id',
    passwordHash: '',
    passwordSalt: '',
    role: 'Super Admin',
    dibuatPada: DateTime(2026),
  );

  /// Render [layar] di HP 360×740 lalu pastikan tidak ada error tampilan.
  Future<void> cek(
    WidgetTester tester,
    Widget layar, {
    required bool gelap,
    required double skalaTeks,
  }) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: gelap ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('id', 'ID'),
      supportedLocales: const [Locale('id', 'ID')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(skalaTeks)),
        child: child!,
      ),
      // Beberapa layar biasanya tampil di dalam Scaffold milik shell.
      home: Scaffold(body: layar),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  /// Satu layar diuji 2 kali: terang + teks normal, gelap + teks 130%.
  /// [hpAnggota] = tampilan di HP Anggota (tombol kelola disembunyikan).
  void layar(String nama, Future<Widget> Function() buat,
      {bool sebagaiAdmin = false, bool hpAnggota = false}) {
    for (final (gelap, skala) in [(false, 1.0), (true, 1.3)]) {
      testWidgets(
          '$nama${hpAnggota ? ' [HP Anggota]' : ''} '
          '(${gelap ? 'gelap' : 'terang'}, teks ${skala}x)', (tester) async {
        PerangkatService.anggota.value = hpAnggota;
        addTearDown(() => PerangkatService.anggota.value = false);
        if (sebagaiAdmin) {
          SessionService.instance.startAdmin(admin);
        } else {
          SessionService.instance.startRelawan(relawan);
        }
        final widget = await tester.runAsync(buat);
        await cek(tester, widget!, gelap: gelap, skalaTeks: skala);
      });
    }
  }

  Future<dynamic> posko() async => PoskoRepository.instance.findById(1);

  // ---------------- RELAWAN ----------------
  layar('Beranda relawan', () async => BerandaScreen(onOpenMenu: (_) {}));
  layar('Data pengungsi relawan',
      () async => PengungsiScreen(onBack: () {}));
  layar('Form pengungsi (tambah)', () async => const PengungsiFormScreen());
  layar('Form pengungsi (edit)', () async {
    final e = (await PengungsiRepository.instance.getByPosko(1)).first;
    return PengungsiFormScreen(existing: e);
  });
  layar('Logistik relawan', () async => LogistikScreen(onBack: () {}));
  layar('Form barang masuk',
      () async => BarangMasukFormScreen(posko: await posko()));
  layar('Form barang keluar',
      () async => BarangKeluarFormScreen(posko: await posko()));
  layar('Kebutuhan & komposisi',
      () async => RingkasanPoskoScreen(posko: await posko()));

  testWidgets('isi terisi: tugas, SPHERE, status stok tampil', (tester) async {
    SessionService.instance.startRelawan(relawan);
    await cek(tester, BerandaScreen(onOpenMenu: (_) {}),
        gelap: false, skalaTeks: 1);
    expect(find.text('TUGAS HARI INI'), findsOneWidget);
    // Demo: stok masih cukup, ada 1 pengungsi demam & 2 kelompok rentan.
    expect(find.text('Periksa kondisi 1 pengungsi yang sedang sakit'),
        findsOneWidget);
    expect(find.text('Cek kebutuhan khusus 2 pengungsi rentan'), findsOneWidget);

    final p = await tester.runAsync(posko);
    await cek(tester, RingkasanPoskoScreen(posko: p), gelap: false, skalaTeks: 1);
    expect(find.text('KEBUTUHAN HARIAN AKTUAL (SPHERE)'), findsOneWidget);
    expect(find.text('Toilet minimal'), findsOneWidget);
    expect(find.textContaining('PERHATIAN MEDIS'), findsOneWidget);
  });

  // ---------------- ADMIN ----------------
  layar(
    'Beranda admin',
    () async => AdminBerandaScreen(
      onOpenTab: (_) {},
      onOpenDataPage: (_) {},
      onLogout: () {},
    ),
    sebagaiAdmin: true,
  );
  layar('Menu data', () async => AdminDataMenuScreen(onBack: () {}),
      sebagaiAdmin: true);
  layar('Data posko', () async => const KelolaPoskoScreen(),
      sebagaiAdmin: true);
  layar('Detail posko (beroperasi)',
      () async => const PoskoDetailScreen(poskoId: 1),
      sebagaiAdmin: true);
  layar('Detail posko (belum lengkap)',
      () async => const PoskoDetailScreen(poskoId: 2),
      sebagaiAdmin: true);
  layar('Form posko', () async => PoskoFormScreen(existing: await posko()),
      sebagaiAdmin: true);
  layar('Data pengungsi admin', () async => const AdminPengungsiScreen(),
      sebagaiAdmin: true);
  layar('Data logistik admin', () async => const AdminLogistikScreen(),
      sebagaiAdmin: true);
  layar('Master barang', () async => const MasterBarangScreen(),
      sebagaiAdmin: true);
  layar('Form barang', () async {
    final b = (await BarangRepository.instance.getAll()).first;
    return BarangFormScreen(existing: b);
  }, sebagaiAdmin: true);
  layar('Paket data posko', () async => const PaketDataScreen(),
      sebagaiAdmin: true);
  layar('Wajib ganti password', () async => const GantiPasswordWajibScreen(),
      sebagaiAdmin: true);
  layar('Detail relawan', () async => const RelawanAkunDetailScreen(relawanId: 1),
      sebagaiAdmin: true);

  // ---------------- HP INDUK / ANGGOTA (Tahap B) ----------------
  layar('Layar awal', () async => const RoleSelectionScreen());
  layar('Layar awal', () async => const RoleSelectionScreen(), hpAnggota: true);
  layar('Siapkan HP Anggota', () async => SiapkanAnggotaScreen(posko: await posko()),
      sebagaiAdmin: true);
  layar('Siapkan dari HP Induk', () async => const TerimaPenyiapanScreen());
  for (final (nama, buat) in <(String, Future<Widget> Function())>[
    ('Detail posko', () async => const PoskoDetailScreen(poskoId: 1)),
    ('Data posko', () async => const KelolaPoskoScreen()),
    ('Kelola relawan', () async => KelolaRelawanScreen(onBack: () {})),
    ('Detail relawan', () async => const RelawanAkunDetailScreen(relawanId: 1)),
    ('Kelola admin', () async => KelolaAdminScreen(onBack: () {})),
    ('Keamanan', () async => const KeamananScreen()),
    ('Master barang', () async => const MasterBarangScreen()),
  ]) {
    layar(nama, buat, sebagaiAdmin: true, hpAnggota: true);
  }

  // ---------------- DASHBOARD GRAFIK ----------------
  layar('Dashboard grafik semua posko', () async => const DashboardScreen(),
      sebagaiAdmin: true);
  layar('Dashboard grafik satu posko',
      () async => const DashboardScreen(poskoId: 1));

  testWidgets('dashboard grafik: semua bagian tampil & bisa dibuka dari beranda',
      (tester) async {
    SessionService.instance.startRelawan(relawan);
    await cek(tester, BerandaScreen(onOpenMenu: (_) {}), gelap: false, skalaTeks: 1);
    expect(find.text('DASHBOARD GRAFIK'), findsOneWidget);

    await cek(tester, const DashboardScreen(poskoId: 1), gelap: true, skalaTeks: 1.3);
    for (final judul in [
      'Keterisian Posko',
      'Jenis Kelamin',
      'Kelompok Usia',
      'Kelompok Rentan',
      'Kondisi Kesehatan',
      'Pengungsi Baru (7 Hari)',
      'Barang Masuk & Keluar (7 Hari)',
      'Status Stok Barang Pokok',
      'Stok Cukup Untuk Berapa Hari',
    ]) {
      await tester.scrollUntilVisible(find.text(judul), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text(judul), findsOneWidget, reason: judul);
    }
    expect(tester.takeException(), isNull);
  });

  // ---------------- KESIAPAN LAPANGAN (27 Okt) ----------------
  layar('Cadangan & pemulihan', () async => const CadanganScreen(), sebagaiAdmin: true);
  layar('Kata sandi posko', () async => const KataSandiPoskoScreen(), sebagaiAdmin: true);
  layar('Kata sandi posko', () async => const KataSandiPoskoScreen(),
      sebagaiAdmin: true, hpAnggota: true);
  layar('Ekspor paket (belum ada kata sandi)', () async => const PaketDataScreen(),
      sebagaiAdmin: true);
  layar('Pulihkan dari layar awal', () async => const CadanganScreen(dariLayarAwal: true));
  layar('Laporan harian semua posko', () async => const LaporanHarianScreen(),
      sebagaiAdmin: true);
  layar('Laporan harian satu posko', () async => const LaporanHarianScreen(poskoId: 1));
  layar('Info posko & akun relawan', () async => const InfoPoskoScreen(poskoId: 1));
  layar('Catat keluar posko', () async {
    final e = (await PengungsiRepository.instance.getByPosko(1)).first;
    return CatatKeluarScreen(pengungsi: e);
  });

  testWidgets('filter pengungsi & status keluar posko tampil rapi', (tester) async {
    // Data demo bersama: satu pengungsi dirujuk, dikembalikan di akhir tes.
    final repo = PengungsiRepository.instance;
    final asli = (await tester.runAsync(() => repo.getByPosko(1)))!.first;
    await tester.runAsync(() => repo.update(asli.catatKeluar(DataOptions.dirujuk,
        DateTime(2026, 10, 26), 'RSUD Pandeglang dengan nama yang cukup panjang')));
    addTearDown(() => tester.runAsync(() => repo.update(asli)));

    SessionService.instance.startRelawan(relawan);
    for (final (gelap, skala) in [(false, 1.0), (true, 1.3)]) {
      await cek(tester, PengungsiScreen(onBack: () {}), gelap: gelap, skalaTeks: skala);
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(find.text('Pengungsi di Posko'), findsOneWidget);
      expect(find.textContaining('orang sudah keluar posko'), findsOneWidget);

      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();
      expect(find.textContaining('↗ '), findsNWidgets(2),
          reason: 'baris yang keluar ditandai + keterangan tanda');

      // Panel bisa masih terbuka dari putaran sebelumnya (state tetap).
      if (find.text('KELOMPOK RENTAN').evaluate().isEmpty) {
        await tester.tap(find.text('Filter lanjutan'));
        await tester.pumpAndSettle();
      }
      expect(find.text('KELOMPOK RENTAN'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }

    SessionService.instance.startAdmin(admin);
    await cek(tester, const AdminPengungsiScreen(), gelap: true, skalaTeks: 1.3);
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('Filter lanjutan'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await cek(tester, const DashboardScreen(), gelap: true, skalaTeks: 1.3);
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Sudah Keluar dari Posko'), 300,
        scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tambah barang: peringatan nama lama & nama mirip', (tester) async {
    SessionService.instance.startAdmin(admin);
    await cek(tester, const BarangFormScreen(), gelap: true, skalaTeks: 1.3);
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Pakaian Layak Pakai');
    await tester.pumpAndSettle();
    expect(find.textContaining('sudah digabung ke "Baju"'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Baju Anak');
    await tester.pumpAndSettle();
    expect(find.textContaining('Mirip barang yang sudah ada: Baju'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Terpal');
    await tester.pumpAndSettle();
    expect(find.textContaining('belum ada di Master Logistik pusat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ---------------- PERINGATAN KAPASITAS & STOK ----------------
  testWidgets('peringatan posko penuh & stok: kotak rapi di beranda dan form',
      (tester) async {
    // Data terpisah supaya tes lain tidak terpengaruh.
    final asli = LocalDatabase.store;
    LocalDatabase.store = MemoryTableStore(seed: DemoData.seed());
    addTearDown(() => LocalDatabase.store = asli);

    await tester.runAsync(() async {
      final store = LocalDatabase.store;
      final p = (await PoskoRepository.withStore(store).findById(1))!;
      final ada = await PengungsiRepository.withStore(store).count(poskoId: 1);
      final list = [
        for (var i = ada; i < p.kapasitas; i++)
          Pengungsi.baru(
            poskoId: 1,
            nama: 'Orang $i',
            asal: 'X',
            tanggalLahir: DateTime(1990),
            jenisKelamin: DataOptions.lakiLaki,
          ),
      ];
      await PengungsiRepository.withStore(store).addMany(list);
    });

    SessionService.instance.startRelawan(relawan);
    for (final (gelap, skala) in [(false, 1.0), (true, 1.3)]) {
      await cek(tester, BerandaScreen(onOpenMenu: (_) {}), gelap: gelap, skalaTeks: skala);
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(find.text('Posko Desa Panggarangan sudah penuh'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await cek(tester, const PengungsiFormScreen(), gelap: gelap, skalaTeks: skala);
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(find.text('Posko Desa Panggarangan sudah penuh'), findsOneWidget);
      expect(find.textContaining('Stok'), findsNothing,
          reason: 'di form hanya peringatan kapasitas');
      expect(tester.takeException(), isNull);
    }

    SessionService.instance.startAdmin(admin);
    await cek(tester, const KotakPeringatan(), gelap: true, skalaTeks: 1.3);
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.text('Posko Desa Panggarangan sudah penuh'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ---------------- SINKRON (Tahap D) ----------------
  layar('Sinkron antar-HP', () async => const SinkronScreen(), sebagaiAdmin: true);
  layar('Sinkron antar-HP', () async => const SinkronScreen(), hpAnggota: true);
  layar('Beranda relawan', () async => BerandaScreen(onOpenMenu: (_) {}),
      hpAnggota: true);
  layar('Menu data', () async => AdminDataMenuScreen(onBack: () {}),
      sebagaiAdmin: true, hpAnggota: true);

  testWidgets('HP Anggota: beranda relawan punya menu sinkron', (tester) async {
    PerangkatService.anggota.value = true;
    addTearDown(() => PerangkatService.anggota.value = false);
    SessionService.instance.startRelawan(relawan);
    await cek(tester, BerandaScreen(onOpenMenu: (_) {}), gelap: false, skalaTeks: 1);
    expect(find.text('SINKRON DENGAN HP INDUK'), findsOneWidget);

    PerangkatService.anggota.value = false;
    await cek(tester, BerandaScreen(onOpenMenu: (_) {}), gelap: false, skalaTeks: 1);
    expect(find.text('SINKRON DENGAN HP INDUK'), findsNothing,
        reason: 'di HP Induk sinkron dilakukan admin');
  });

  layar('Menu relawan', () async => const RelawanShellScreen(), hpAnggota: true);

  testWidgets('HP Anggota: tab Riwayat relawan diganti Sinkron', (tester) async {
    PerangkatService.anggota.value = true;
    addTearDown(() => PerangkatService.anggota.value = false);
    SessionService.instance.startRelawan(relawan);
    await cek(tester, const RelawanShellScreen(), gelap: false, skalaTeks: 1);
    expect(find.text('Riwayat'), findsNothing);
    expect(find.text('RIWAYAT TRANSAKSI'), findsNothing);
    await tester.tap(find.text('Sinkron'));
    await tester.pumpAndSettle();
    expect(find.text('KIRIM KE HP INDUK'), findsOneWidget);

    PerangkatService.anggota.value = false;
    await cek(tester, const RelawanShellScreen(), gelap: false, skalaTeks: 1);
    expect(find.text('Riwayat'), findsOneWidget);
    expect(find.text('Sinkron'), findsNothing);
  });

  testWidgets('relawan: tidak ada tombol CSV di Data Pengungsi', (tester) async {
    SessionService.instance.startRelawan(relawan);
    await cek(tester, PengungsiScreen(onBack: () {}), gelap: false, skalaTeks: 1);
    expect(find.text('IMPORT CSV'), findsNothing);
    expect(find.text('EXPORT CSV'), findsNothing);
  });

  testWidgets('HP Anggota: tombol kelola diganti keterangan HP Induk',
      (tester) async {
    PerangkatService.anggota.value = true;
    addTearDown(() => PerangkatService.anggota.value = false);
    SessionService.instance.startAdmin(admin);
    await cek(tester, const PoskoDetailScreen(poskoId: 1),
        gelap: false, skalaTeks: 1);
    expect(find.text('HAPUS POSKO'), findsNothing);
    expect(find.text('TUTUP OPERASI'), findsNothing);
    expect(find.text('SIAPKAN HP ANGGOTA'), findsNothing);
    expect(find.text(PerangkatService.pesanDikelolaInduk), findsOneWidget);
    expect(find.text('KEBUTUHAN & KOMPOSISI'), findsOneWidget,
        reason: 'melihat kebutuhan tetap boleh');
  });

  // ---------------- STOK DI BEBERAPA HP (Tahap E) ----------------
  layar('Form barang keluar',
      () async => BarangKeluarFormScreen(posko: await posko()), hpAnggota: true);

  testWidgets('stok minus: kotak peringatan tampil rapi', (tester) async {
    SessionService.instance.startRelawan(relawan);
    // Air Mineral di demo: masuk 300 -> keluar 400 = minus 100.
    final air = (await tester.runAsync(() => BarangRepository.instance.getAll()))!
        .firstWhere((b) => b.namaItem == 'Air Mineral');
    final id = await tester.runAsync(() => LocalDatabase.store.insert(
          'barang_keluar',
          BarangKeluar.baru(
            poskoId: 1,
            barang: air,
            jumlah: 400,
            tujuan: 'dibagikan',
            tanggal: DateTime(2026, 10, 24),
          ).toMap(),
        ));
    addTearDown(() => LocalDatabase.store.delete('barang_keluar', id!));

    for (final (gelap, skala) in [(false, 1.0), (true, 1.3)]) {
      await cek(tester, LogistikScreen(onBack: () {}), gelap: gelap, skalaTeks: skala);
      expect(find.textContaining('Stok minus: Air Mineral −100 liter'), findsOneWidget);
    }
  });

  // ---------------- PENGUNGSI DOBEL (Tahap F) ----------------
  testWidgets('kemungkinan dobel: kotak di Data Pengungsi & layar periksa rapi',
      (tester) async {
    SessionService.instance.startAdmin(admin);
    // Budi Santoso (demo) dicatat lagi di "HP lain": nama & tanggal lahir sama.
    final id = await tester.runAsync(() => LocalDatabase.store.insert(
          'pengungsi',
          Pengungsi.baru(
            poskoId: 1,
            nama: 'budi santoso',
            asal: 'Desa Panggarangan',
            tanggalLahir: DateTime(1984, 3, 12),
            jenisKelamin: 'Laki-laki',
            dicatatOleh: 'Relawan HP 2',
          ).toMap(),
        ));
    addTearDown(() => LocalDatabase.store.delete('pengungsi', id!));

    for (final (gelap, skala) in [(false, 1.0), (true, 1.3)]) {
      await cek(tester, const AdminPengungsiScreen(), gelap: gelap, skalaTeks: skala);
      expect(find.textContaining('1 kemungkinan pengungsi dobel'), findsOneWidget);

      await cek(tester, const PengungsiDobelScreen(), gelap: gelap, skalaTeks: skala);
      expect(find.text('PAKAI DATA 1'), findsOneWidget);
      expect(find.text('PAKAI DATA 2'), findsOneWidget);
      expect(find.text('BUKAN ORANG YANG SAMA'), findsOneWidget);
    }
  });
}
