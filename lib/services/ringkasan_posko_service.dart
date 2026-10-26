// ============================================================
// ringkasan_posko_service.dart
// Mengambil data satu posko dari database lalu menghitung kebutuhan
// bantuan, komposisi, dan perhatian medis (rumus di kebutuhan_service).
// ============================================================

import '../data/repositories/logistik_repository.dart';
import '../data/repositories/pengungsi_repository.dart';
import '../data/repositories/posko_repository.dart';
import '../data/table_store.dart';
import '../data/local_database.dart';
import '../models/pengungsi.dart';
import '../models/posko.dart';
import '../utils/waktu_wib.dart';
import 'kebutuhan_service.dart';

class RingkasanPosko {
  final Posko posko;
  final KomposisiPengungsi komposisi;
  final StatusBantuan bantuan;
  final List<Pengungsi> perhatianMedis;
  final List<TugasHarian> tugas;
  final KebutuhanSphere sphere;

  const RingkasanPosko({
    required this.posko,
    required this.komposisi,
    required this.bantuan,
    required this.perhatianMedis,
    required this.tugas,
    required this.sphere,
  });

  List<KebutuhanBarang> get stok => bantuan.stok;
  int get jumlahSakit => perhatianMedis.where(KebutuhanService.isSakit).length;
}

class RingkasanPoskoService {
  RingkasanPoskoService._();

  static Future<RingkasanPosko> muat(Posko posko, {TableStore? store}) async {
    final s = store ?? LocalDatabase.store;
    final pengungsi =
        await PengungsiRepository.withStore(s).getByPosko(posko.id);
    final logistik = LogistikRepository.withStore(s);
    final stok = await logistik.getStok(posko.id, termasukPokok: true);
    final hariIni = WaktuWib.hariIni();
    final adaKeluarHariIni = (await logistik.getKeluar(poskoId: posko.id))
        .any((k) => k.tanggal == hariIni);

    final komposisi = KebutuhanService.komposisi(pengungsi, posko.kapasitas);
    final kebutuhan = KebutuhanService.hitung(stok, pengungsi.length);
    final medis = KebutuhanService.perhatianMedis(pengungsi);
    return RingkasanPosko(
      posko: posko,
      komposisi: komposisi,
      bantuan: KebutuhanService.statusBantuan(posko, kebutuhan, komposisi),
      perhatianMedis: medis,
      tugas: KebutuhanService.tugasHariIni(
        stok: kebutuhan,
        komposisi: komposisi,
        perhatianMedis: medis,
        adaBarangKeluarHariIni: adaKeluarHariIni,
      ),
      sphere: KebutuhanService.sphere(pengungsi.length),
    );
  }

  /// Semua posko yang sedang BEROPERASI, urut dari yang paling butuh bantuan.
  static Future<List<RingkasanPosko>> poskoBeroperasi({TableStore? store}) async {
    final s = store ?? LocalDatabase.store;
    final hasil = <RingkasanPosko>[];
    for (final p in await PoskoRepository.withStore(s).getAll()) {
      if (p.isBeroperasi) hasil.add(await muat(p, store: s));
    }
    hasil.sort((a, b) => KebutuhanService.bandingkan(a.bantuan, b.bantuan));
    return hasil;
  }
}
