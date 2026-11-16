// ============================================================
// sinkron_service.dart
// SINKRON ANTAR-HP SATU POSKO (tanpa internet; file dikirim lewat
// Bluetooth / Quick Share / flashdisk).
//
//   HP Anggota -> HP Induk : data posko (pengungsi, barang masuk/keluar).
//   HP Induk -> HP Anggota : data GABUNGAN posko + pembaruan akun & master
//                            barang (penyiapan.json, PIN/password diacak).
//
// Isi data = format Paket Data Posko (§8), digabung dengan aturan yang sama
// seperti website (gabung_paket_service.dart). HP Induk tidak pernah
// menerima akun dari file; akun hanya dikelola di HP Induk.
// ============================================================

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../data/database_tables.dart';
import '../data/local_database.dart';
import '../data/repositories/pengaturan_repository.dart';
import '../data/table_store.dart';
import '../models/posko.dart';
import '../utils/waktu_wib.dart';
import 'csv_service.dart';
import 'gabung_paket_service.dart';
import 'paket_data_service.dart';
import 'penyiapan_service.dart';

/// Hasil pemeriksaan File Sinkron sebelum digabung.
class PratinjauSinkron {
  final HasilGabung data;

  /// Pembaruan akun dari HP Induk (hanya terisi di HP Anggota).
  final FilePenyiapan? akun;

  /// Jam di HP pengirim tampak lebih maju dari jam HP ini.
  final String? peringatanJam;

  /// Alasan file tidak bisa dipakai di HP ini (null = boleh).
  final String? ditolak;

  const PratinjauSinkron({
    required this.data,
    this.akun,
    this.peringatanJam,
    this.ditolak,
  });
}

/// Satu baris riwayat: file terakhir yang diterima dari HP lain.
class RiwayatSinkron {
  final String kodePerangkat;
  final String waktu; // waktu file dibuat (WIB)
  final String oleh;

  const RiwayatSinkron(this.kodePerangkat, this.waktu, this.oleh);
}

class SinkronService {
  SinkronService._();

  /// Selisih jam yang masih dianggap wajar antar-HP.
  static const Duration toleransiJam = Duration(minutes: 10);

  static TableStore _s(TableStore? store) => store ?? LocalDatabase.store;

  // ---------------- KIRIM ----------------

  /// Buat File Sinkron untuk [posko] dari HP ini.
  /// [pengungsi] / [logistik] false = data itu tidak ikut dikirim (pilih
  /// sebagian). Data yang tidak dikirim tidak berubah di HP tujuan; akun &
  /// master barang dari HP Induk selalu ikut.
  static Future<(String, Uint8List)> buatFile(
    Posko posko, {
    TableStore? store,
    String dibuatOleh = '',
    DateTime? waktu,
    bool pengungsi = true,
    bool logistik = true,
    String awalanNama = 'LOGEVA_sinkron_',
  }) async {
    final s = _s(store);
    final now = waktu ?? DateTime.now();
    final anggota = await PengaturanRepository.withStore(s).isAnggota();
    final semua = await PaketDataService.kumpulkan(
      [posko],
      store: s,
      dieksporOleh: dibuatOleh,
      waktu: now,
    );
    final paket = PaketData(
      dibuatPada: semua.dibuatPada,
      kodePerangkat: semua.kodePerangkat,
      dieksporOleh: semua.dieksporOleh,
      peranPerangkat: semua.peranPerangkat,
      posko: semua.posko,
      relawan: semua.relawan,
      pengungsi: pengungsi ? semua.pengungsi : const [],
      masuk: logistik ? semua.masuk : const [],
      keluar: logistik ? semua.keluar : const [],
      barang: semua.barang,
      stok: logistik ? semua.stok : const {},
      petugas: semua.petugas,
    );

    final arsip = Archive();
    for (final e in paket.csv.entries) {
      arsip.addFile(ArchiveFile.string(e.key, e.value));
    }
    if (!anggota) {
      // HP Induk: akun & master barang terbaru ikut ke HP Anggota.
      final json = await PenyiapanService.buatJson(posko,
          store: s, dibuatOleh: dibuatOleh, waktu: now);
      arsip.addFile(ArchiveFile.string(FilePenyiapan.namaJson, jsonEncode(json)));
    }

    final nama = posko.nama.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
    return (
      '$awalanNama${nama.isEmpty ? 'Posko' : nama}_'
          '${anggota ? 'dari-anggota' : 'dari-induk'}_${WaktuWib.capFile(now)}.zip',
      ZipEncoder().encodeBytes(arsip),
    );
  }

  // ---------------- TERIMA ----------------

  static bool _adaAkun(List<int> bytes) {
    try {
      return ZipDecoder().decodeBytes(bytes).findFile(FilePenyiapan.namaJson) != null;
    } catch (_) {
      return false;
    }
  }

  /// Jumlah data posko di dalam file dari HP Induk (untuk pratinjau di HP
  /// yang belum disiapkan). null = file tidak membawa data posko.
  static ({int pengungsi, int masuk, int keluar})? ringkasanIsi(List<int> bytes) {
    try {
      final arsip = ZipDecoder().decodeBytes(bytes);
      if (arsip.findFile('info.csv') == null) return null;
      List<Map<String, String>> baca(String nama) {
        final f = arsip.findFile(nama);
        return f == null
            ? const []
            : CsvService.decode(utf8.decode(f.content, allowMalformed: true));
      }

      return (
        pengungsi: baca('pengungsi.csv')
            .where((r) => (r['dihapus_pada'] ?? '').isEmpty)
            .length,
        masuk: baca('barang_masuk.csv').length,
        keluar: baca('barang_keluar.csv').length,
      );
    } catch (_) {
      return null;
    }
  }

  /// File dari HP Induk (berisi akun) yang bisa dipakai untuk MENYIAPKAN
  /// HP ini: HP baru, atau HP Anggota dari HP Induk & posko yang sama.
  static Future<bool> bisaMenyiapkan(List<int> bytes, {TableStore? store}) async {
    if (!_adaAkun(bytes)) return false;
    try {
      final file = PenyiapanService.baca(bytes);
      return await PenyiapanService.cekBoleh(file, store: _s(store)) == null;
    } on PenyiapanException {
      return false;
    }
  }

  /// Periksa File Sinkron tanpa menyimpan apa pun.
  static Future<PratinjauSinkron> periksa(List<int> bytes,
      {TableStore? store, DateTime? sekarang}) async {
    final s = _s(store);
    final anggota = await PengaturanRepository.withStore(s).isAnggota();

    FilePenyiapan? akun;
    String? ditolak;
    if (anggota && _adaAkun(bytes)) {
      try {
        akun = PenyiapanService.baca(bytes);
        ditolak = await PenyiapanService.cekBoleh(akun, store: s);
      } on PenyiapanException catch (e) {
        ditolak = e.message;
      }
    }

    final data = await GabungPaketService.periksa(bytes, store: s);
    final dibuat = WaktuWib.baca(data.dibuatPada);
    final batas = (sekarang ?? DateTime.now()).add(toleransiJam);
    final peringatanJam = dibuat != null && dibuat.isAfter(batas)
        ? 'File ini dibuat ${data.dibuatPada} WIB, lebih maju dari jam HP ini. '
            'Periksa tanggal & jam di kedua HP: jam yang salah bisa membuat data '
            'lama dianggap lebih baru.'
        : null;

    return PratinjauSinkron(
      data: data,
      akun: akun,
      peringatanJam: peringatanJam,
      ditolak: ditolak,
    );
  }

  /// Gabungkan File Sinkron ke HP ini. Di HP Anggota, pembaruan akun dari
  /// HP Induk diterapkan lebih dulu.
  static Future<HasilGabung> terapkan(List<int> bytes, {TableStore? store}) async {
    final s = _s(store);
    final cek = await periksa(bytes, store: s);
    if (cek.ditolak != null) throw GabungException(cek.ditolak!);
    if (cek.akun != null) await PenyiapanService.terapkan(cek.akun!, store: s);
    return GabungPaketService.terapkan(bytes, store: s);
  }

  // ---------------- RIWAYAT ----------------

  /// File terakhir yang diterima dari setiap HP lain, terbaru di atas.
  static Future<List<RiwayatSinkron>> riwayat({TableStore? store}) async {
    final hasil = <RiwayatSinkron>[];
    for (final r in await _s(store).getAll(DatabaseTables.pengaturan)) {
      final kunci = r['kunci'] as String;
      if (!kunci.startsWith(GabungPaketService.awalanRiwayat)) continue;
      final nilai = (r['nilai'] as String? ?? '').split('|');
      hasil.add(RiwayatSinkron(
        kunci.substring(GabungPaketService.awalanRiwayat.length),
        nilai.first,
        nilai.length > 1 ? nilai[1] : '',
      ));
    }
    hasil.sort((a, b) => b.waktu.compareTo(a.waktu));
    return hasil;
  }
}
