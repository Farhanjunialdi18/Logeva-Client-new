// ============================================================
// dobel_service.dart
// PENGUNGSI DOBEL DARI BEBERAPA HP: orang yang sama (nama + tanggal lahir
// sama di posko yang sama, aturan website) tapi dicatat di HP berbeda,
// sehingga kodenya berbeda dan tidak tergabung otomatis.
//
// Di HP Induk, supervisor memutuskan:
//  - GABUNGKAN : satu data dipakai; isian yang kosong dilengkapi dari
//                duplikatnya; duplikatnya DITANDAI DIHAPUS sehingga ikut
//                terhapus di HP Anggota & di pusat lewat sinkron / paket.
//  - BUKAN ORANG YANG SAMA : disimpan, grup itu tidak ditampilkan lagi
//                (kecuali ada data baru yang ikut cocok).
// ============================================================

import 'dart:convert';

import '../data/data_events.dart';
import '../data/local_database.dart';
import '../data/repositories/pengaturan_repository.dart';
import '../data/repositories/pengungsi_repository.dart';
import '../data/repositories/posko_repository.dart';
import '../data/table_store.dart';
import '../models/pengungsi.dart';

/// Satu kelompok data yang kemungkinan orang yang sama.
class GrupDobel {
  final String posko;
  final List<Pengungsi> data; // minimal 2, terlama di atas

  const GrupDobel({required this.posko, required this.data});

  /// Penanda grup (kode semua anggotanya, terurut).
  String get kunci => (data.map((p) => p.kode).toList()..sort()).join(',');

  String get nama => data.first.nama;
}

class DobelService {
  DobelService._();

  static const String kunciBukanDobel = 'bukan_dobel';

  static TableStore _s(TableStore? store) => store ?? LocalDatabase.store;

  static Future<Set<String>> _bukanDobel(TableStore s) async {
    final teks = await PengaturanRepository.withStore(s).get(kunciBukanDobel);
    if (teks == null || teks.isEmpty) return {};
    return {for (final k in jsonDecode(teks) as List) k as String};
  }

  /// Semua grup kemungkinan dobel yang belum diputuskan.
  static Future<List<GrupDobel>> cari({TableStore? store}) async {
    final s = _s(store);
    final abaikan = await _bukanDobel(s);
    final namaPosko = {
      for (final p in await PoskoRepository.withStore(s).getAll()) p.id: p.nama,
    };

    final kelompok = <String, List<Pengungsi>>{};
    for (final p in await PengungsiRepository.withStore(s).getAll()) {
      final k = p.kunci;
      if (k == null) continue; // data lama tanpa tanggal lahir
      (kelompok['${p.poskoId}|$k'] ??= []).add(p);
    }

    final hasil = <GrupDobel>[];
    for (final daftar in kelompok.values) {
      if (daftar.length < 2) continue;
      daftar.sort((a, b) => a.dibuatPada.compareTo(b.dibuatPada));
      final grup = GrupDobel(posko: namaPosko[daftar.first.poskoId] ?? '-', data: daftar);
      if (!abaikan.contains(grup.kunci)) hasil.add(grup);
    }
    hasil.sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    return hasil;
  }

  static Future<int> jumlah({TableStore? store}) async =>
      (await cari(store: store)).length;

  /// Pakai [pilihan] sebagai data orang ini; duplikat lain ditandai dihapus.
  static Future<void> gabungkan(GrupDobel grup, Pengungsi pilihan,
      {TableStore? store}) async {
    final repo = PengungsiRepository.withStore(_s(store));
    final lain = grup.data.where((p) => p.kode != pilihan.kode).toList();

    // Lengkapi isian yang kosong dari duplikatnya.
    String isi(String Function(Pengungsi) ambil) {
      final sendiri = ambil(pilihan);
      if (sendiri.trim().isNotEmpty) return sendiri;
      for (final p in lain) {
        if (ambil(p).trim().isNotEmpty) return ambil(p);
      }
      return sendiri;
    }

    await repo.update(pilihan.ubahData(
      poskoId: pilihan.poskoId,
      nama: pilihan.nama,
      asal: isi((p) => p.asal),
      tanggalLahir: pilihan.tanggalLahir!,
      jenisKelamin: pilihan.jenisKelamin,
      nomorKk: isi((p) => p.nomorKk),
      kondisiKesehatan: pilihan.kondisiKesehatan,
      // Kelompok rentan yang tercatat di salah satu HP tidak boleh hilang.
      kelompokRentan: pilihan.isRentan
          ? pilihan.kelompokRentan
          : (lain.where((p) => p.isRentan).firstOrNull?.kelompokRentan ??
              pilihan.kelompokRentan),
      riwayatPenyakit: isi((p) => p.riwayatPenyakit),
    ));
    for (final p in lain) {
      await repo.hapus(p);
    }
    DataEvents.instance.notifyChanged();
  }

  /// Simpan keputusan "bukan orang yang sama" untuk [grup].
  static Future<void> bukanOrangYangSama(GrupDobel grup, {TableStore? store}) async {
    final s = _s(store);
    final daftar = await _bukanDobel(s)..add(grup.kunci);
    await PengaturanRepository.withStore(s)
        .set(kunciBukanDobel, jsonEncode(daftar.toList()));
    DataEvents.instance.notifyChanged();
  }
}
