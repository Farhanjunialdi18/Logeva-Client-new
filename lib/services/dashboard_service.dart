// ============================================================
// dashboard_service.dart
// Data untuk DASHBOARD GRAFIK: ringkasan angka, komposisi pengungsi,
// keterisian posko, tren 7 hari terakhir, dan keadaan stok.
// Cakupan: semua posko (admin) atau satu posko (relawan / filter).
// Semua rumus kebutuhan & status memakai kebutuhan_service (sama
// dengan website), jadi angka di grafik sama dengan layar Kebutuhan.
// ============================================================

import '../data/local_database.dart';
import '../data/repositories/logistik_repository.dart';
import '../data/repositories/pengungsi_repository.dart';
import '../data/repositories/posko_repository.dart';
import '../data/table_store.dart';
import '../models/posko.dart';
import '../utils/waktu_wib.dart';
import 'kebutuhan_service.dart';
import 'ringkasan_posko_service.dart';

/// Satu hari di grafik tren.
class HariGrafik {
  final DateTime tanggal; // tanggal kalender WIB (jam 00:00)
  final int pengungsiBaru;
  final int barangMasuk; // jumlah catatan
  final int barangKeluar; // jumlah catatan

  const HariGrafik({
    required this.tanggal,
    this.pengungsiBaru = 0,
    this.barangMasuk = 0,
    this.barangKeluar = 0,
  });
}

/// Keterisian satu posko.
class IsiPosko {
  final Posko posko;
  final int jumlah;

  const IsiPosko(this.posko, this.jumlah);

  /// null = kapasitas belum bisa dihitung (luas lokasi kosong).
  int? get persen =>
      posko.kapasitas <= 0 ? null : (jumlah * 100 / posko.kapasitas).round();
}

class DataDashboard {
  /// null = semua posko.
  final Posko? posko;
  final int jumlahPosko;
  final int poskoBeroperasi;
  final KomposisiPengungsi komposisi;
  final int sakit;
  final List<IsiPosko> isiPosko;
  final List<HariGrafik> tren; // 7 hari, terlama dulu
  /// Status stok barang pokok (semua posko dijumlah): status -> jumlah barang.
  final Map<String, int> statusStok;
  /// Hanya untuk satu posko: barang yang daya tahannya bisa dihitung,
  /// paling cepat habis dulu.
  final List<KebutuhanBarang> ketahanan;
  /// Posko beroperasi per tingkat bantuan (TingkatBantuan).
  final Map<String, int> tingkatPosko;

  /// Pengungsi yang sudah keluar posko: status keberadaan -> jumlah.
  final Map<String, int> keluarPosko;

  const DataDashboard({
    required this.posko,
    required this.jumlahPosko,
    required this.poskoBeroperasi,
    required this.komposisi,
    required this.sakit,
    required this.isiPosko,
    required this.tren,
    required this.statusStok,
    required this.ketahanan,
    required this.tingkatPosko,
    this.keluarPosko = const {},
  });

  int get sehat => komposisi.total - sakit;
  int get jumlahKeluar => keluarPosko.values.fold(0, (a, b) => a + b);
  int get pengungsiBaru7Hari => tren.fold(0, (a, h) => a + h.pengungsiBaru);
}

class DashboardService {
  DashboardService._();

  static const int jumlahHari = 7;

  /// [poskoId] null = semua posko. [sekarang] untuk tes.
  static Future<DataDashboard> muat({
    int? poskoId,
    TableStore? store,
    DateTime? sekarang,
  }) async {
    final s = store ?? LocalDatabase.store;
    final semuaPosko = await PoskoRepository.withStore(s).getAll();
    final cakupan = poskoId == null
        ? semuaPosko
        : semuaPosko.where((p) => p.id == poskoId).toList();

    // Semua yang pernah dicatat (untuk tren kedatangan & yang sudah keluar),
    // dan yang masih di posko (untuk komposisi, kapasitas, kesehatan).
    final pernah = (await PengungsiRepository.withStore(s).getAll())
        .where((e) => poskoId == null || e.poskoId == poskoId)
        .toList();
    final pengungsi = pernah.where((e) => e.masihDiPosko).toList();
    final keluarPosko = <String, int>{};
    for (final e in pernah.where((e) => !e.masihDiPosko)) {
      keluarPosko[e.statusKeberadaan] = (keluarPosko[e.statusKeberadaan] ?? 0) + 1;
    }
    final logistik = LogistikRepository.withStore(s);
    final masuk = await logistik.getMasuk(poskoId: poskoId);
    final keluar = await logistik.getKeluar(poskoId: poskoId);

    // ---- komposisi & kesehatan ----
    final kapasitas = cakupan.fold(0, (a, p) => a + p.kapasitas);
    final komposisi = KebutuhanService.komposisi(pengungsi, kapasitas);
    final sakit = pengungsi.where(KebutuhanService.isSakit).length;

    // ---- keterisian per posko ----
    final perPosko = <int?, int>{};
    for (final e in pengungsi) {
      perPosko[e.poskoId] = (perPosko[e.poskoId] ?? 0) + 1;
    }
    final isi = [for (final p in cakupan) IsiPosko(p, perPosko[p.id] ?? 0)]
      ..sort((a, b) => (b.persen ?? -1).compareTo(a.persen ?? -1));

    // ---- tren 7 hari (tanggal WIB) ----
    final hariIni = WaktuWib.hariIni(sekarang);
    final hari = [
      for (var i = jumlahHari - 1; i >= 0; i--)
        DateTime(hariIni.year, hariIni.month, hariIni.day - i),
    ];
    int hitung(Iterable<DateTime> tanggal, DateTime h) =>
        tanggal.where((t) => t.year == h.year && t.month == h.month && t.day == h.day).length;
    final tglPengungsi = pernah.map((e) => WaktuWib.jamDinding(e.dibuatPada)).toList();
    final tren = [
      for (final h in hari)
        HariGrafik(
          tanggal: h,
          pengungsiBaru: hitung(tglPengungsi, h),
          barangMasuk: hitung(masuk.map((m) => m.tanggal), h),
          barangKeluar: hitung(keluar.map((k) => k.tanggal), h),
        ),
    ];

    // ---- stok & status bantuan ----
    final statusStok = {
      StatusStok.merah: 0,
      StatusStok.kuning: 0,
      StatusStok.hijau: 0,
      StatusStok.netral: 0,
    };
    final tingkat = {for (final t in TingkatBantuan.urutan) t: 0};
    var ketahanan = <KebutuhanBarang>[];
    var beroperasi = 0;
    for (final p in cakupan) {
      final r = await RingkasanPoskoService.muat(p, store: s);
      for (final k in r.stok) {
        statusStok[k.status] = (statusStok[k.status] ?? 0) + 1;
      }
      if (p.isBeroperasi) {
        beroperasi++;
        final t = r.bantuan.tingkat;
        if (t != null) tingkat[t] = (tingkat[t] ?? 0) + 1;
      }
      if (poskoId != null) {
        ketahanan = r.stok.where((k) => k.cukupHari != null).toList()
          ..sort((a, b) => a.cukupHari!.compareTo(b.cukupHari!));
      }
    }

    return DataDashboard(
      posko: poskoId == null ? null : (cakupan.isEmpty ? null : cakupan.first),
      jumlahPosko: cakupan.length,
      poskoBeroperasi: beroperasi,
      komposisi: komposisi,
      sakit: sakit,
      isiPosko: isi,
      tren: tren,
      statusStok: statusStok,
      ketahanan: ketahanan,
      tingkatPosko: tingkat,
      keluarPosko: keluarPosko,
    );
  }
}
