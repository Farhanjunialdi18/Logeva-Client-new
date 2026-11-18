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
import '../data/repositories/relawan_repository.dart';
import '../data/table_store.dart';
import '../models/posko.dart';
import '../utils/waktu_wib.dart';
import 'csv_service.dart';
import 'gabung_paket_service.dart';
import 'paket_data_service.dart';
import 'penyiapan_service.dart';
import 'session_service.dart';

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

/// Status kirim HP Anggota ke HP Induk.
class StatusKirim {
  /// Perubahan yang dicatat di HP ini sejak terakhir dikirim.
  final int belumTerkirim;

  /// Kapan File Sinkron terakhir dikirim dari HP ini (null = belum pernah).
  final DateTime? terakhirKirim;

  /// Kiriman HP ini yang terakhir sudah digabung di HP Induk (tanda terima).
  final DateTime? diterimaInduk;

  /// Kapan file dari HP Induk terakhir diterima (dibuat) di HP ini.
  final DateTime? terakhirDariInduk;

  const StatusKirim({
    required this.belumTerkirim,
    this.terakhirKirim,
    this.diterimaInduk,
    this.terakhirDariInduk,
  });

  /// Kiriman terakhir sudah dikonfirmasi digabung oleh admin.
  bool get sudahDikonfirmasi =>
      terakhirKirim != null &&
      diterimaInduk != null &&
      !diterimaInduk!.isBefore(terakhirKirim!);
}

/// Status HP seorang relawan, dilihat dari HP Induk (pengingat admin).
class StatusHpRelawan {
  /// Kapan relawan terakhir mengirim data ke HP Induk (null = belum pernah).
  final DateTime? terakhirKirim;

  /// Versi data admin yang ada di HP relawan menurut kiriman terakhirnya.
  final DateTime? dataIndukDilaporkan;

  /// Kapan admin terakhir membagikan file ke relawan ini (Detail Relawan).
  final DateTime? terakhirDibagikan;

  final DateTime? akunBerubah;
  final DateTime? terakhirGabung;

  const StatusHpRelawan({
    this.terakhirKirim,
    this.dataIndukDilaporkan,
    this.terakhirDibagikan,
    this.akunBerubah,
    this.terakhirGabung,
  });

  static DateTime? _maks(DateTime? a, DateTime? b) =>
      a == null ? b : (b == null || a.isAfter(b) ? a : b);

  /// Versi data admin terbaru yang (kemungkinan) ada di HP relawan.
  DateTime? get dataAdminDiHp => _maks(dataIndukDilaporkan, terakhirDibagikan);

  /// Belum pernah dibagikan sama sekali = HP relawan belum disiapkan.
  bool get belumPernahDibagikan => dataAdminDiHp == null;

  /// Akun (PIN / status / relawan baru / dihapus) berubah setelah HP relawan
  /// terakhir menerima data admin -> perubahan BELUM berlaku di HP itu.
  bool get akunBelumBerlaku {
    final versi = dataAdminDiHp;
    return versi != null && akunBerubah != null && akunBerubah!.isAfter(versi);
  }

  /// Ada data gabungan (dari relawan lain) yang belum diterima HP ini.
  bool get adaDataBaru {
    final versi = dataAdminDiHp;
    return versi != null && terakhirGabung != null && terakhirGabung!.isAfter(versi);
  }

  bool get perluDibagikan => belumPernahDibagikan || akunBelumBerlaku || adaDataBaru;

  /// Relawan belum mengirim data hari ini (WIB).
  bool belumKirimHariIni([DateTime? sekarang]) =>
      terakhirKirim == null ||
      WaktuWib.tanggal(terakhirKirim!) != WaktuWib.tanggal(sekarang ?? DateTime.now());
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
    String kodeRelawan = '',
  }) async {
    final s = _s(store);
    final now = waktu ?? DateTime.now();
    final anggota = await PengaturanRepository.withStore(s).isAnggota();
    final laporanAnggota = anggota
        ? CsvService.encode(
            const ['kode_relawan', 'nama_relawan', 'data_induk'],
            [
              [kodeRelawan, dibuatOleh, await _dataIndukMentah(s) ?? ''],
            ],
          )
        : null;
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
    if (laporanAnggota != null) {
      // LAPORAN HP ANGGOTA: siapa pengirimnya & versi data admin yang sudah
      // ada di HP ini, supaya admin tahu HP mana yang perlu dibagikan ulang.
      arsip.addFile(ArchiveFile.string(namaLaporanAnggota, laporanAnggota));
    }
    if (!anggota) {
      // HP Induk: akun & master barang terbaru ikut ke HP Anggota.
      final json = await PenyiapanService.buatJson(posko,
          store: s, dibuatOleh: dibuatOleh, waktu: now);
      arsip.addFile(ArchiveFile.string(FilePenyiapan.namaJson, jsonEncode(json)));
      // TANDA TERIMA: kiriman terakhir dari setiap HP Anggota yang sudah
      // digabung di HP Induk, supaya relawan tahu datanya sudah masuk.
      final terima = await riwayat(store: s);
      if (terima.isNotEmpty) {
        arsip.addFile(ArchiveFile.string(
          namaTandaTerima,
          CsvService.encode(
            const ['kode_perangkat', 'dibuat_pada'],
            [for (final r in terima) [r.kodePerangkat, r.waktu]],
          ),
        ));
      }
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
  /// Isi file untuk LOG SETOR DATA, misal "12 pengungsi, 3 barang masuk,
  /// 1 barang keluar". Kosong kalau file tidak berisi data posko.
  static String teksIsi(List<int> bytes) {
    final isi = ringkasanIsi(bytes);
    return isi == null
        ? ''
        : '${isi.pengungsi} pengungsi, ${isi.masuk} barang masuk, '
            '${isi.keluar} barang keluar';
  }

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
    final hasil = await GabungPaketService.terapkan(bytes, store: s);
    await setelahGabung(bytes, store: s);
    return hasil;
  }

  /// Dipanggil setelah File Sinkron digabung (semua jalur: halaman Sinkron,
  /// Buka dengan LOGEVA, penyiapan):
  ///  - HP Anggota: catat tanda terima dari HP Induk;
  ///  - HP Induk: catat laporan HP Anggota pengirim + waktu gabung.
  static Future<void> setelahGabung(List<int> bytes, {TableStore? store}) async {
    final s = _s(store);
    final pengaturan = PengaturanRepository.withStore(s);
    if (await pengaturan.isAnggota()) {
      await catatTandaTerima(bytes, store: s);
      return;
    }
    await pengaturan.set(
        PengaturanRepository.kunciTerakhirGabung, WaktuWib.tanggalWaktu(DateTime.now()));
    try {
      final arsip = ZipDecoder().decodeBytes(bytes);
      String teks(String nama) {
        final f = arsip.findFile(nama);
        return f == null ? '' : utf8.decode(f.content, allowMalformed: true);
      }

      final info = CsvService.decode(teks('info.csv')).firstOrNull ?? const {};
      final kodeHp = info['kode_perangkat'] ?? '';
      final laporan = CsvService.decode(teks(namaLaporanAnggota)).firstOrNull;
      if (kodeHp.isEmpty || laporan == null) return; // file HP Induk / versi lama
      await pengaturan.set(
        '${PengaturanRepository.awalanHpAnggota}$kodeHp',
        jsonEncode({
          'kode_relawan': laporan['kode_relawan'] ?? '',
          'nama_relawan': laporan['nama_relawan'] ?? '',
          'dikirim': info['dibuat_pada'] ?? '',
          'data_induk': laporan['data_induk'] ?? '',
        }),
      );
    } catch (_) {
      // laporan rusak: abaikan, data tetap tergabung
    }
  }

  static const String namaLaporanAnggota = 'laporan_anggota.csv';

  /// Kode akun relawan yang sedang login ('' = admin / belum login).
  static Future<String> kodeRelawanLogin() async {
    final id = SessionService.instance.relawan?.relawanId;
    if (id == null) return '';
    return (await RelawanRepository.instance.findById(id))?.kode ?? '';
  }

  /// Waktu (teks WIB) file dari HP Induk terakhir digabung di HP ini.
  static Future<String?> _dataIndukMentah(TableStore s) async {
    final induk = await PengaturanRepository.withStore(s).get(PenyiapanService.kunciKodeInduk);
    for (final r in await riwayat(store: s)) {
      if (r.kodePerangkat == induk) return r.waktu;
    }
    return null;
  }

  // ---------------- STATUS HP RELAWAN (HP Induk) ----------------

  /// Status HP setiap relawan (kunci = kode relawan), untuk pengingat admin.
  static Future<Map<String, StatusHpRelawan>> statusHpRelawan({TableStore? store}) async {
    final s = _s(store);
    final p = PengaturanRepository.withStore(s);
    final akunBerubah = WaktuWib.baca(await p.get(PengaturanRepository.kunciAkunBerubah));
    final terakhirGabung = WaktuWib.baca(await p.get(PengaturanRepository.kunciTerakhirGabung));

    // Laporan terbaru per relawan (satu relawan bisa memakai lebih dari 1 HP).
    final laporan = <String, Map<String, dynamic>>{};
    final dibagikan = <String, DateTime>{};
    for (final r in await s.getAll(DatabaseTables.pengaturan)) {
      final kunci = r['kunci'] as String? ?? '';
      final nilai = r['nilai'] as String? ?? '';
      if (kunci.startsWith(PengaturanRepository.awalanHpAnggota)) {
        try {
          final m = jsonDecode(nilai) as Map<String, dynamic>;
          final kode = m['kode_relawan'] as String? ?? '';
          if (kode.isEmpty) continue;
          final lama = laporan[kode];
          if (lama == null || (m['dikirim'] as String).compareTo(lama['dikirim'] as String) > 0) {
            laporan[kode] = m;
          }
        } catch (_) {
          continue;
        }
      } else if (kunci.startsWith(PengaturanRepository.awalanDibagikan)) {
        final w = WaktuWib.baca(nilai);
        if (w != null) dibagikan[kunci.substring(PengaturanRepository.awalanDibagikan.length)] = w;
      }
    }

    final hasil = <String, StatusHpRelawan>{};
    for (final kode in {...laporan.keys, ...dibagikan.keys}) {
      final l = laporan[kode];
      hasil[kode] = StatusHpRelawan(
        terakhirKirim: WaktuWib.baca(l?['dikirim'] as String?),
        dataIndukDilaporkan: WaktuWib.baca(l?['data_induk'] as String?),
        terakhirDibagikan: dibagikan[kode],
        akunBerubah: akunBerubah,
        terakhirGabung: terakhirGabung,
      );
    }
    return hasil;
  }

  /// Status satu relawan; relawan yang belum pernah dibagikan / mengirim
  /// tetap mendapat status (perlu dibagikan).
  static StatusHpRelawan statusUntuk(
          Map<String, StatusHpRelawan> semua, String kodeRelawan,
          {DateTime? akunBerubah, DateTime? terakhirGabung}) =>
      semua[kodeRelawan] ??
      StatusHpRelawan(akunBerubah: akunBerubah, terakhirGabung: terakhirGabung);

  /// Dipanggil setelah admin membagikan file [waktu] ke relawan [kodeRelawan].
  static Future<void> tandaiDibagikan(String kodeRelawan, DateTime waktu,
      {TableStore? store}) async {
    if (kodeRelawan.isEmpty) return;
    await PengaturanRepository.withStore(_s(store)).set(
        '${PengaturanRepository.awalanDibagikan}$kodeRelawan', WaktuWib.tanggalWaktu(waktu));
  }

  // ---------------- TANDA TERIMA ----------------

  static const String namaTandaTerima = 'tanda_terima.csv';

  /// Di HP Anggota: baca tanda terima di file dari HP Induk. Kalau kiriman
  /// HP ini tercantum, simpan waktunya (kiriman itu sudah digabung admin).
  static Future<void> catatTandaTerima(List<int> bytes, {TableStore? store}) async {
    final s = _s(store);
    final pengaturan = PengaturanRepository.withStore(s);
    if (!await pengaturan.isAnggota()) return;
    try {
      final f = ZipDecoder().decodeBytes(bytes).findFile(namaTandaTerima);
      if (f == null) return;
      final kode = await pengaturan.kodePerangkat();
      for (final r in CsvService.decode(utf8.decode(f.content, allowMalformed: true))) {
        if (r['kode_perangkat'] != kode) continue;
        final baru = r['dibuat_pada'] ?? '';
        final lama = await pengaturan.get(PengaturanRepository.kunciDiterimaInduk) ?? '';
        // Format "yyyy-MM-dd HH:mm:ss": urutan teks = urutan waktu.
        if (baru.compareTo(lama) > 0) {
          await pengaturan.set(PengaturanRepository.kunciDiterimaInduk, baru);
        }
      }
    } catch (_) {
      // tanda terima rusak: abaikan, data tetap tergabung
    }
  }

  /// Status kirim HP Anggota ke HP Induk (untuk beranda relawan).
  static Future<StatusKirim> statusKirim({TableStore? store}) async {
    final s = _s(store);
    final p = PengaturanRepository.withStore(s);
    final induk = await p.get(PenyiapanService.kunciKodeInduk);
    String? dariInduk;
    for (final r in await riwayat(store: s)) {
      if (r.kodePerangkat == induk) dariInduk = r.waktu;
    }
    return StatusKirim(
      belumTerkirim: await p.perubahanBelumTerkirim(),
      terakhirKirim: WaktuWib.baca(await p.get(PengaturanRepository.kunciTerakhirKirim)),
      diterimaInduk: WaktuWib.baca(await p.get(PengaturanRepository.kunciDiterimaInduk)),
      terakhirDariInduk: WaktuWib.baca(dariInduk),
    );
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
