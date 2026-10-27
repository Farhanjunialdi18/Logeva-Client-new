// ============================================================
// laporan_harian_service.dart
// LAPORAN HARIAN berupa TEKS SINGKAT: bisa disalin, dikirim lewat SMS
// (tetap jalan tanpa internet selama ada sinyal telepon), Bluetooth,
// atau dibacakan lewat radio/HT ke posko induk.
// Isi per posko: status, keterisian, komposisi, perhatian medis,
// kedatangan & kepergian hari ini, stok kurang dari 7 hari, tugas.
// Rumus sama dengan layar Kebutuhan & Dashboard.
// ============================================================

import '../data/local_database.dart';
import '../data/repositories/pengungsi_repository.dart';
import '../data/repositories/posko_repository.dart';
import '../data/table_store.dart';
import '../utils/waktu_wib.dart';
import 'kebutuhan_service.dart';
import 'peringatan_service.dart';
import 'ringkasan_posko_service.dart';

class LaporanHarianService {
  LaporanHarianService._();

  static const List<String> _bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  static bool _hariSama(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// [poskoId] null = semua posko (yang beroperasi, atau semua kalau tidak
  /// ada yang beroperasi). [oleh] = nama pembuat laporan.
  static Future<String> buat({
    int? poskoId,
    String oleh = '',
    TableStore? store,
    DateTime? sekarang,
  }) async {
    final s = store ?? LocalDatabase.store;
    final waktu = sekarang ?? DateTime.now();
    final w = WaktuWib.jamDinding(waktu);
    final hariIni = DateTime(w.year, w.month, w.day);

    var posko = await PoskoRepository.withStore(s).getAll();
    if (poskoId != null) {
      posko = posko.where((p) => p.id == poskoId).toList();
    } else if (posko.any((p) => p.isBeroperasi)) {
      posko = posko.where((p) => p.isBeroperasi).toList();
    }
    posko.sort((a, b) => a.nama.compareTo(b.nama));

    final semuaOrang = await PengungsiRepository.withStore(s).getAll();
    final b = StringBuffer()
      ..writeln('LAPORAN HARIAN LOGEVA')
      ..writeln('${w.day} ${_bulan[w.month - 1]} ${w.year}, '
          '${w.hour.toString().padLeft(2, '0')}.${w.minute.toString().padLeft(2, '0')} WIB');
    if (posko.isEmpty) {
      b.writeln('\nBelum ada posko.');
    }

    for (final p in posko) {
      final r = await RingkasanPoskoService.muat(p, store: s);
      final k = r.komposisi;
      final orang = semuaOrang.where((e) => e.poskoId == p.id);
      final baru = orang
          .where((e) => _hariSama(WaktuWib.jamDinding(e.dibuatPada), hariIni))
          .length;
      final keluar = orang
          .where((e) => !e.masihDiPosko && e.keluarPada != null && _hariSama(e.keluarPada!, hariIni))
          .length;

      b
        ..writeln()
        ..writeln('== ${p.label.toUpperCase()} ==')
        ..writeln([
          'Status: ${p.statusLabel}',
          if (p.hariKe(waktu) != null) 'hari ke-${p.hariKe(waktu)}',
          if (p.isBeroperasi) TingkatBantuan.label(r.bantuan.tingkat),
        ].join(' · '));

      b.writeln(k.kapasitas > 0
          ? 'Pengungsi: ${k.total}/${k.kapasitas} orang (${k.persenIsi}%), sisa ${k.sisaTempat} tempat'
          : 'Pengungsi: ${k.total} orang');
      if (k.total > 0) {
        b
          ..writeln('- Laki-laki ${k.lakiLaki}, perempuan ${k.perempuan}')
          ..writeln('- ${[
            for (final e in k.usia.entries)
              if (e.value > 0) '${e.key.split(' ').first} ${e.value}',
          ].join(', ')}');
        if (k.rentan.isNotEmpty) {
          b.writeln('- Rentan: ${[for (final e in k.rentan.entries) '${e.key} ${e.value}'].join(', ')}');
        }
        if (r.jumlahSakit > 0) b.writeln('- Perlu perhatian medis: ${r.jumlahSakit} orang');
      }
      b.writeln('Hari ini: $baru datang, $keluar keluar posko');

      final kurang = r.stok
          .where((x) =>
              x.cukupHari != null && x.cukupHari! < PeringatanService.batasHariStok)
          .toList()
        ..sort((a, b) => a.cukupHari!.compareTo(b.cukupHari!));
      if (kurang.isNotEmpty) {
        b.writeln('Stok kurang dari ${PeringatanService.batasHariStok} hari:');
        for (final x in kurang) {
          b.writeln('- ${x.barang.namaItem}: ${KebutuhanService.teksHari(x.cukupHari).toLowerCase()}'
              '${(x.kekurangan ?? 0) > 0 ? ', butuh ${x.kekurangan} ${x.barang.satuan}' : ''}');
        }
      } else if (p.isBeroperasi && k.total > 0) {
        b.writeln('Stok barang pokok cukup untuk ${PeringatanService.batasHariStok} hari ke depan.');
      }
    }

    if (oleh.trim().isNotEmpty) b.writeln('\nDilaporkan oleh: ${oleh.trim()}');
    return b.toString().trimRight();
  }
}
