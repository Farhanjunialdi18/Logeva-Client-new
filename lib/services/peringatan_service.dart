// ============================================================
// peringatan_service.dart
// PERINGATAN POSKO (notifikasi lokal + kotak di dalam aplikasi):
//  - Kapasitas: hampir penuh (>= 80%) dan penuh (>= 100%).
//  - Stok barang: cukup untuk KURANG DARI 7 HARI (ada waktu menunggu
//    bantuan logistik datang) dan sudah habis. Hanya posko beroperasi,
//    rumus sama dengan layar Kebutuhan (kebutuhan_service).
// Notifikasi hanya dikirim saat batas BARU terlewati, bukan setiap kali
// data berubah. Keadaan terakhir disimpan per posko di tabel pengaturan,
// jadi kalau keadaan membaik lalu memburuk lagi, notifikasi muncul lagi.
// Diperiksa setiap kali data berubah (tambah pengungsi, import, sinkron,
// barang keluar) dan saat aplikasi dibuka.
// ============================================================

import 'dart:async';
import 'dart:convert';

import '../data/data_events.dart';
import '../data/local_database.dart';
import '../data/repositories/pengaturan_repository.dart';
import '../data/repositories/pengungsi_repository.dart';
import '../data/repositories/posko_repository.dart';
import '../data/table_store.dart';
import '../models/posko.dart';
import 'kebutuhan_service.dart';
import 'notifikasi_service.dart';
import 'ringkasan_posko_service.dart';

/// Tingkat keterisian posko.
class TingkatIsi {
  TingkatIsi._();

  static const int aman = 0;
  static const int hampirPenuh = 80; // persen
  static const int penuh = 100; // persen

  static int dari(int? persen) {
    if (persen == null) return aman;
    if (persen >= penuh) return penuh;
    if (persen >= hampirPenuh) return hampirPenuh;
    return aman;
  }
}

/// Satu barang yang stoknya kurang dari [PeringatanService.batasHariStok] hari.
class StokKurang {
  final KebutuhanBarang kebutuhan;

  const StokKurang(this.kebutuhan);

  bool get habis => kebutuhan.jumlahStok <= 0;
  String get nama => kebutuhan.barang.namaItem;
  String get teks =>
      '$nama (${KebutuhanService.teksHari(kebutuhan.cukupHari).toLowerCase()})';
}

/// Keadaan satu posko yang perlu diperhatikan.
class PeringatanPosko {
  final Posko posko;
  final int jumlahPengungsi;
  final List<StokKurang> stok; // paling cepat habis dulu

  const PeringatanPosko({
    required this.posko,
    required this.jumlahPengungsi,
    required this.stok,
  });

  int? get persen => posko.kapasitas <= 0
      ? null
      : (jumlahPengungsi * 100 / posko.kapasitas).round();
  int get tingkatIsi => TingkatIsi.dari(persen);
  int get sisaTempat =>
      (posko.kapasitas - jumlahPengungsi).clamp(0, posko.kapasitas);

  bool get adaKapasitas => tingkatIsi != TingkatIsi.aman;
  bool get adaStok => stok.isNotEmpty;
  bool get adaPeringatan => adaKapasitas || adaStok;

  String get judulKapasitas => tingkatIsi == TingkatIsi.penuh
      ? '${posko.label} sudah penuh'
      : '${posko.label} hampir penuh';

  String get isiKapasitas => tingkatIsi == TingkatIsi.penuh
      ? '$jumlahPengungsi/${posko.kapasitas} orang ($persen%). '
          'Arahkan pengungsi baru ke posko lain.'
      : '$jumlahPengungsi/${posko.kapasitas} orang ($persen%), '
          'sisa $sisaTempat tempat.';

  String get judulStok => stok.any((s) => s.habis)
      ? 'Stok habis di ${posko.label}'
      : 'Stok ${posko.label} kurang dari ${PeringatanService.batasHariStok} hari';

  String get isiStok {
    const tampil = 3;
    final nama = stok.take(tampil).map((s) => s.teks).join(', ');
    final lain = stok.length > tampil ? ' dan ${stok.length - tampil} barang lain' : '';
    return '$nama$lain. Ajukan bantuan logistik sekarang supaya sempat datang.';
  }
}

class PeringatanService {
  PeringatanService._();

  /// Stok yang cukup untuk kurang dari sekian hari diberi peringatan
  /// (sama dengan target kiriman 7 hari di layar Kebutuhan).
  static const int batasHariStok = KebutuhanService.targetHari;

  static String _kunci(Posko p) => 'peringatan_${p.kode}';

  /// Keadaan semua posko (atau satu posko) saat ini. Posko tanpa
  /// peringatan ikut dikembalikan; pakai [PeringatanPosko.adaPeringatan].
  static Future<List<PeringatanPosko>> keadaan({
    int? poskoId,
    TableStore? store,
  }) async {
    final s = store ?? LocalDatabase.store;
    final semua = await PoskoRepository.withStore(s).getAll();
    final hasil = <PeringatanPosko>[];
    for (final p in semua) {
      if (poskoId != null && p.id != poskoId) continue;
      final jumlah = await PengungsiRepository.withStore(s).count(poskoId: p.id);
      var stok = <StokKurang>[];
      // Status stok hanya dihitung untuk posko beroperasi (sama dengan website).
      if (p.isBeroperasi && jumlah > 0) {
        final r = await RingkasanPoskoService.muat(p, store: s);
        stok = [
          for (final k in r.stok)
            if (k.cukupHari != null && k.cukupHari! < batasHariStok) StokKurang(k),
        ]..sort((a, b) => a.kebutuhan.cukupHari!.compareTo(b.kebutuhan.cukupHari!));
      }
      hasil.add(PeringatanPosko(posko: p, jumlahPengungsi: jumlah, stok: stok));
    }
    return hasil;
  }

  /// Bandingkan keadaan sekarang dengan yang terakhir disimpan, kirim
  /// notifikasi untuk batas yang baru terlewati, lalu simpan keadaan.
  /// Mengembalikan jumlah notifikasi yang dikirim.
  static Future<int> periksa({TableStore? store}) async {
    final s = store ?? LocalDatabase.store;
    final pengaturan = PengaturanRepository.withStore(s);
    var terkirim = 0;

    for (final w in await keadaan(store: s)) {
      final lama = _baca(await pengaturan.get(_kunci(w.posko)));
      final stokSekarang = {
        for (final st in w.stok) '${st.kebutuhan.barang.id}': st.habis ? 'habis' : 'kurang',
      };

      // Kapasitas: hanya saat naik tingkat (aman -> 80% -> 100%).
      if (w.tingkatIsi > lama.isi) {
        await NotifikasiService.tampilkan(
            _id(w.posko, 1), w.judulKapasitas, w.isiKapasitas);
        terkirim++;
      }

      // Stok: barang yang baru masuk daftar, atau berubah dari kurang ke habis.
      final baru = stokSekarang.entries.any((e) =>
          lama.stok[e.key] == null || (e.value == 'habis' && lama.stok[e.key] != 'habis'));
      if (baru) {
        await NotifikasiService.tampilkan(_id(w.posko, 2), w.judulStok, w.isiStok);
        terkirim++;
      }

      final simpan = jsonEncode({'isi': w.tingkatIsi, 'stok': stokSekarang});
      if (simpan != lama.json) await pengaturan.set(_kunci(w.posko), simpan);
    }
    return terkirim;
  }

  /// id notifikasi tetap per posko & jenis (1 = kapasitas, 2 = stok).
  static int _id(Posko p, int jenis) => (p.id ?? 0) * 10 + jenis;

  static ({int isi, Map<String, String> stok, String? json}) _baca(String? json) {
    try {
      final m = jsonDecode(json ?? '') as Map<String, dynamic>;
      return (
        isi: (m['isi'] as num?)?.toInt() ?? TingkatIsi.aman,
        stok: (m['stok'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {},
        json: json,
      );
    } catch (_) {
      return (isi: TingkatIsi.aman, stok: <String, String>{}, json: null);
    }
  }

  // ---------------- PEMICU OTOMATIS ----------------

  static Timer? _jeda;
  static bool _berjalan = false;

  /// Dipanggil sekali dari main(): siapkan notifikasi, minta izin,
  /// periksa sekarang, lalu periksa lagi setiap kali data berubah.
  static Future<void> mulai() async {
    await NotifikasiService.mulai();
    await NotifikasiService.mintaIzin();
    DataEvents.instance.addListener(_jadwalkan);
    _jadwalkan();
  }

  /// Beberapa perubahan beruntun (misal import CSV) diperiksa sekali saja.
  static void _jadwalkan() {
    _jeda?.cancel();
    _jeda = Timer(const Duration(seconds: 1), () async {
      if (_berjalan) return _jadwalkan();
      _berjalan = true;
      try {
        await periksa();
      } catch (_) {
        // Peringatan tidak boleh mengganggu pencatatan data.
      } finally {
        _berjalan = false;
      }
    });
  }
}
