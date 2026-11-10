// ============================================================
// gabung_paket_service.dart
// GABUNG PAKET DATA POSKO DARI HP LAIN (di HP ini, tanpa internet).
// Dipakai HP Induk untuk menerima data dari HP Anggota, dan HP Anggota
// untuk menerima data gabungan dari HP Induk (sinkron dua arah).
//
// Aturannya sama dengan Import Paket di website:
//  - Posko     : dicocokkan dengan kode (semua HP satu posko memakai kode
//                yang sama sejak File Penyiapan). Posko yang tidak dikenal
//                di HP ini dilewati. Data posko diperbarui jika paket lebih baru.
//  - Pengungsi : kode baru = tambah; kode yang ada = diperbarui HANYA jika
//                diubah_pada paket lebih baru. Penghapusan disimpan sebagai
//                tanda (dihapus_pada) supaya paket lama tidak memunculkannya lagi.
//  - Barang masuk / keluar : kode yang sudah ada dilewati (tidak dobel).
//                Stok di aplikasi selalu dihitung dari catatan, jadi otomatis benar.
//  - Paket yang dibuat oleh HP ini sendiri ditolak.
//
// PAKET DARI WEBSITE PUSAT (info.csv kolom sumber = 'website', dibuat di
// menu Paket Data Posko → Export paket untuk aplikasi) hanya diterima lewat
// periksaWebsite/terapkanWebsite di HP Induk. Bedanya:
//  - Posko yang belum ada di HP ini DITAMBAHKAN (kode tetap kode website,
//    jadi paket dari HP nanti dikenali website sebagai posko yang sama).
//  - Posko dicocokkan dengan kode, lalu nama posko + desa (sama dengan
//    website). Nama sama tapi desa berbeda = error, karena nama posko di
//    HP harus unik.
//  - Akun petugas (petugas.csv) dan foto tidak diambil: akun tetap dibuat
//    admin di HP Induk.
//  - Setelah digabung, stok di HP dibandingkan dengan stok website (stok.csv).
//
// Waktu dibandingkan per DETIK (paket menyimpan sampai detik). Data hasil
// gabung menyimpan waktu dari paket, jadi ekspor ulang menghasilkan waktu sama.
// ============================================================

import 'dart:convert';

import 'package:archive/archive.dart';

import '../core/data_options.dart';
import '../data/data_events.dart';
import '../data/database_tables.dart';
import '../data/local_database.dart';
import '../data/repositories/barang_repository.dart';
import '../data/repositories/logistik_repository.dart';
import '../data/repositories/pengaturan_repository.dart';
import '../data/repositories/pengungsi_repository.dart';
import '../data/repositories/posko_repository.dart';
import '../data/table_store.dart';
import '../models/barang.dart';
import '../models/catatan_logistik.dart';
import '../models/pengungsi.dart';
import '../models/posko.dart';
import '../utils/angka.dart';
import '../utils/kode_unik.dart';
import '../utils/tanggal.dart';
import '../utils/waktu_wib.dart';
import 'csv_service.dart';
import 'paket_data_service.dart';

/// Paket ditolak; [message] siap ditampilkan.
class GabungException implements Exception {
  final String message;
  const GabungException(this.message);

  @override
  String toString() => message;
}

/// Satu baris hasil pemeriksaan / penggabungan.
class BarisGabung {
  static const String tambah = 'tambah';
  static const String perbarui = 'perbarui';
  static const String hapus = 'hapus';
  static const String sama = 'sama';
  static const String lewati = 'lewati';
  static const String error = 'error';

  final String status;
  final String nama;
  final String alasan;

  const BarisGabung(this.status, this.nama, [this.alasan = '']);
}

class HasilGabung {
  final String kodePerangkat;
  final String dieksporOleh;
  final String dibuatPada;
  final List<BarisGabung> posko;
  final List<BarisGabung> pengungsi;
  final List<BarisGabung> masuk;
  final List<BarisGabung> keluar;
  final List<String> barangBaru;

  /// Paket berasal dari website pusat.
  final bool dariWebsite;

  /// Stok yang berbeda antara HP ini dan website (hanya setelah paket
  /// website digabung), contoh "Beras (Posko A): website 100 kg, HP 90 kg".
  final List<String> selisihStok;

  const HasilGabung({
    this.dariWebsite = false,
    this.selisihStok = const [],
    required this.kodePerangkat,
    required this.dieksporOleh,
    required this.dibuatPada,
    required this.posko,
    required this.pengungsi,
    required this.masuk,
    required this.keluar,
    required this.barangBaru,
  });

  static Map<String, int> _hitung(List<BarisGabung> b) {
    final m = <String, int>{};
    for (final x in b) {
      m[x.status] = (m[x.status] ?? 0) + 1;
    }
    return m;
  }

  Map<String, int> get ringkasanPengungsi => _hitung(pengungsi);
  Map<String, int> get ringkasanMasuk => _hitung(masuk);
  Map<String, int> get ringkasanKeluar => _hitung(keluar);
  Map<String, int> get ringkasanPosko => _hitung(posko);

  bool get adaPerubahan => [...posko, ...pengungsi, ...masuk, ...keluar].any(
      (b) => const [BarisGabung.tambah, BarisGabung.perbarui, BarisGabung.hapus]
          .contains(b.status));

  /// Pesan singkat, misal "3 pengungsi baru, 1 diperbarui, 2 barang masuk".
  String get ringkasan {
    String n(Map<String, int> m, String k) => '${m[k] ?? 0}';
    final p = ringkasanPengungsi;
    final k = ringkasanPosko;
    final posko = dariWebsite
        ? 'Posko: ${n(k, BarisGabung.tambah)} baru, '
            '${n(k, BarisGabung.perbarui)} diperbarui · '
        : '';
    return '${posko}Pengungsi: ${n(p, BarisGabung.tambah)} baru, '
        '${n(p, BarisGabung.perbarui)} diperbarui, ${n(p, BarisGabung.hapus)} dihapus · '
        'Barang masuk: ${n(ringkasanMasuk, BarisGabung.tambah)} · '
        'Barang keluar: ${n(ringkasanKeluar, BarisGabung.tambah)}';
  }
}

class GabungPaketService {
  GabungPaketService._();

  /// Kunci pengaturan riwayat sinkron: awalan + kode perangkat pengirim.
  static const String awalanRiwayat = 'sinkron_dari_';

  static const List<String> _wajib = [
    'info.csv', 'posko.csv', 'pengungsi.csv', 'barang_masuk.csv',
    'barang_keluar.csv',
  ];

  /// Periksa paket tanpa menyimpan apa pun (untuk pratinjau).
  static Future<HasilGabung> periksa(List<int> bytes, {TableStore? store}) =>
      _proses(bytes, store ?? LocalDatabase.store, simpan: false);

  /// Gabungkan paket ke HP ini.
  static Future<HasilGabung> terapkan(List<int> bytes, {TableStore? store}) =>
      _proses(bytes, store ?? LocalDatabase.store, simpan: true);

  /// Kunci pengaturan: paket website terakhir yang digabung
  /// ("waktu paket|nama pengekspor").
  static const String kunciImporWebsite = 'impor_website_terakhir';

  /// Periksa paket dari WEBSITE pusat (sudah dibuka kuncinya) tanpa menyimpan.
  static Future<HasilGabung> periksaWebsite(List<int> bytes, {TableStore? store}) =>
      _proses(bytes, store ?? LocalDatabase.store, simpan: false, dariWebsite: true);

  /// Gabungkan paket dari WEBSITE pusat ke HP ini (HP Induk).
  static Future<HasilGabung> terapkanWebsite(List<int> bytes, {TableStore? store}) =>
      _proses(bytes, store ?? LocalDatabase.store, simpan: true, dariWebsite: true);

  // ---------------- BACA ZIP ----------------

  static Map<String, List<Map<String, String>>> _baca(List<int> bytes) {
    final Archive arsip;
    try {
      arsip = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const GabungException(
          'File bukan Paket Data Posko (ZIP) yang valid.');
    }
    final isi = <String, List<Map<String, String>>>{};
    for (final nama in [..._wajib, 'stok.csv', 'petugas.csv']) {
      final f = arsip.findFile(nama);
      if (f == null) {
        if (_wajib.contains(nama)) {
          throw GabungException('File $nama tidak ada di dalam paket.');
        }
        continue;
      }
      isi[nama] = CsvService.decode(utf8.decode(f.content, allowMalformed: true));
    }
    final info = isi['info.csv']!.firstOrNull ?? const {};
    if (info['versi_format'] != PaketData.versiFormat) {
      throw const GabungException(
          'Versi format paket tidak dikenali. Samakan versi aplikasi di kedua HP.');
    }
    return isi;
  }

  // ---------------- PROSES ----------------

  static Future<HasilGabung> _proses(List<int> bytes, TableStore s,
      {required bool simpan, bool dariWebsite = false}) async {
    final isi = _baca(bytes);
    final info = isi['info.csv']!.first;
    final pengaturan = PengaturanRepository.withStore(s);
    if (info['kode_perangkat'] == await pengaturan.kodePerangkat()) {
      throw const GabungException(
          'Paket ini dibuat di HP ini sendiri. Pilih paket dari HP lain.');
    }
    final sumberWebsite = info['sumber'] == 'website';
    if (dariWebsite && !sumberWebsite) {
      throw const GabungException(
          'File ini bukan paket dari website pusat. File dari HP lain posko ini '
          'diterima di menu Sinkron Antar-HP.');
    }
    if (!dariWebsite && sumberWebsite) {
      throw const GabungException(
          'File ini paket dari website pusat. Buka di HP Induk: menu Paket Data '
          'Posko → Import dari Website.');
    }
    if (dariWebsite && await pengaturan.isAnggota()) {
      throw const GabungException(
          'Paket dari website hanya diimpor di HP Induk. HP Anggota menerima '
          'datanya lewat Sinkron Antar-HP dari HP Induk.');
    }

    // ---- posko ----
    final poskoRepo = PoskoRepository.withStore(s);
    final lokal = {for (final p in await poskoRepo.getAll()) p.kode: p};
    final dikenal = <String, int>{}; // kode_posko di paket -> id lokal
    final barisPosko = <BarisGabung>[];
    var idSementara = -1; // posko baru saat pratinjau (belum disimpan)
    for (final r in isi['posko.csv']!) {
      final kode = r['kode_posko'] ?? '';
      final nama = (r['nama_lokasi'] ?? '').trim();
      final diubah = WaktuWib.baca(r['diubah_pada']);
      var ada = lokal[kode];
      var sambung = false;

      if (ada == null && dariWebsite) {
        // Sama dengan website: kode dulu, lalu nama posko + desa.
        Posko? samaNama;
        for (final p in lokal.values) {
          if (_kunci(p.nama) == _kunci(nama)) samaNama = p;
        }
        if (samaNama != null) {
          if (_kunci(samaNama.namaDesa) != _kunci(r['nama_desa'] ?? '')) {
            barisPosko.add(BarisGabung(BarisGabung.error, nama,
                'Nama posko sudah dipakai posko lain di HP ini (desa '
                '"${samaNama.namaDesa}"). Ganti nama salah satu posko dulu.'));
            continue;
          }
          ada = samaNama;
          sambung = true;
        }
      }

      if (ada == null) {
        if (!dariWebsite) {
          barisPosko.add(BarisGabung(BarisGabung.lewati, nama.isEmpty ? '-' : nama,
              'Posko tidak dikenal di HP ini (siapkan HP itu dari HP Induk posko ini)'));
          continue;
        }
        if (!KodeUnik.valid(kode) || nama.isEmpty || diubah == null) {
          barisPosko.add(BarisGabung(BarisGabung.error, nama.isEmpty ? '-' : nama,
              'Kode posko, nama, atau diubah_pada tidak valid'));
          continue;
        }
        final baru = _posko(null, r, diubah);
        final id = simpan
            ? await s.insert(DatabaseTables.posko, baru.toMap()..remove('id'))
            : idSementara--;
        dikenal[kode] = id;
        lokal[kode] = Posko.fromMap(baru.toMap()..['id'] = id);
        barisPosko.add(BarisGabung(BarisGabung.tambah, nama, 'Posko baru dari website'));
        continue;
      }

      dikenal[kode] = ada.id!;
      final catatan = sambung ? 'Disambungkan ke posko yang sudah ada (nama + desa)' : '';
      if (diubah != null && _lebihBaru(diubah, ada.diubahPada)) {
        if (simpan) await s.update(DatabaseTables.posko, ada.id!, _posko(ada, r, diubah).toMap());
        barisPosko.add(BarisGabung(BarisGabung.perbarui, nama,
            sambung ? '$catatan & diperbarui' : 'Data paket lebih baru'));
      } else {
        barisPosko.add(BarisGabung(BarisGabung.sama, nama, catatan));
      }
    }
    if (dikenal.isEmpty) {
      throw GabungException(dariWebsite
          ? 'Tidak ada posko yang bisa diambil dari paket ini.'
              '${barisPosko.isEmpty ? '' : ' ${barisPosko.first.nama}: ${barisPosko.first.alasan}'}'
          : 'Posko di paket ini tidak ada di HP ini. Paket hanya bisa digabung '
              'antar-HP posko yang sama (HP Anggota disiapkan dari HP Induk).');
    }

    // ---- pengungsi ----
    final pengungsiLokal = {
      for (final p in await PengungsiRepository.withStore(s).getAll(termasukDihapus: true))
        p.kode: p,
    };
    final barisPengungsi = <BarisGabung>[];
    for (final r in isi['pengungsi.csv']!) {
      barisPengungsi.add(await _pengungsi(s, r, dikenal, pengungsiLokal, simpan));
    }

    // ---- barang masuk / keluar ----
    final logistik = LogistikRepository.withStore(s);
    final kodeMasuk = {for (final m in await logistik.getMasuk()) m.kode};
    final kodeKeluar = {for (final k in await logistik.getKeluar()) k.kode};
    final barang = _PetaBarang(s, simpan);
    await barang.muat();

    final barisMasuk = <BarisGabung>[];
    for (final r in isi['barang_masuk.csv']!) {
      barisMasuk.add(await _catatan(s, r, dikenal, kodeMasuk, barang, simpan, masuk: true));
    }
    final barisKeluar = <BarisGabung>[];
    for (final r in isi['barang_keluar.csv']!) {
      barisKeluar.add(await _catatan(s, r, dikenal, kodeKeluar, barang, simpan, masuk: false));
    }

    final selisih = <String>[];
    if (simpan) {
      // Riwayat: per HP pengirim ("waktu paket|nama pengekspor"), atau
      // paket website terakhir (tidak tampil di riwayat Sinkron Antar-HP).
      await pengaturan.set(
          dariWebsite ? kunciImporWebsite : '$awalanRiwayat${info['kode_perangkat']}',
          '${info['dibuat_pada'] ?? ''}|${info['diekspor_oleh'] ?? ''}');
      if (dariWebsite) {
        selisih.addAll(await _selisihStok(s, isi['stok.csv'] ?? const [], dikenal, lokal));
      }
      DataEvents.instance.notifyChanged();
    }

    return HasilGabung(
      dariWebsite: dariWebsite,
      selisihStok: selisih,
      kodePerangkat: info['kode_perangkat'] ?? '',
      dieksporOleh: info['diekspor_oleh'] ?? '',
      dibuatPada: info['dibuat_pada'] ?? '',
      posko: barisPosko,
      pengungsi: barisPengungsi,
      masuk: barisMasuk,
      keluar: barisKeluar,
      barangBaru: barang.baru,
    );
  }

  /// [paket] lebih baru dari [lokal]? (dibandingkan per detik)
  static bool _lebihBaru(DateTime paket, DateTime lokal) =>
      WaktuWib.keDetik(paket).isAfter(WaktuWib.keDetik(lokal));

  static DateTime? _waktuOpsional(String? teks) =>
      (teks ?? '').trim().isEmpty ? null : WaktuWib.baca(teks);

  /// Nama untuk dicocokkan: tanpa beda huruf besar/kecil & spasi ganda.
  static String _kunci(String teks) =>
      teks.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  /// Posko dari baris posko.csv. [ada] = posko di HP ini (null = posko baru,
  /// kodenya diambil dari paket). Paket tanpa kolom ketinggian_mdpl (aplikasi
  /// versi lama) tidak mengubah ketinggian.
  static Posko _posko(Posko? ada, Map<String, String> r, DateTime diubah) => Posko(
        id: ada?.id,
        kode: ada?.kode ?? r['kode_posko']!,
        nama: (r['nama_lokasi'] ?? '').trim().isEmpty ? ada!.nama : r['nama_lokasi']!.trim(),
        namaDesa: r['nama_desa'] ?? ada?.namaDesa ?? '',
        alamat: r['alamat_lokasi'] ?? ada?.alamat ?? '',
        luasLokasi: double.tryParse(r['luas_lokasi'] ?? '') ?? ada?.luasLokasi,
        latitude: r['latitude'] ?? ada?.latitude ?? '',
        longitude: r['longitude'] ?? ada?.longitude ?? '',
        ketinggianMdpl: r.containsKey('ketinggian_mdpl')
            ? Angka.baca(r['ketinggian_mdpl'])
            : ada?.ketinggianMdpl,
        statusOperasional: const [Posko.siaga, Posko.beroperasi, Posko.selesai]
                .contains(r['status_operasional'])
            ? r['status_operasional']!
            : ada?.statusOperasional ?? Posko.siaga,
        mulaiBeroperasiAt: _waktuOpsional(r['mulai_beroperasi_at']),
        selesaiBeroperasiAt: _waktuOpsional(r['selesai_beroperasi_at']),
        dibuatPada: ada?.dibuatPada ?? diubah,
        diubahPada: diubah,
      );

  /// Bandingkan stok website (stok.csv) dengan stok HP ini (dihitung dari
  /// catatan) untuk posko di paket. Barang yang tidak ada di salah satu
  /// sisi dianggap stok 0.
  static Future<List<String>> _selisihStok(TableStore s, List<Map<String, String>> stok,
      Map<String, int> dikenal, Map<String, Posko> lokal) async {
    final namaPosko = {for (final p in lokal.values) p.id: p.nama};
    final logistik = LogistikRepository.withStore(s);
    final hasil = <String>[];
    for (final MapEntry(key: kode, value: id) in dikenal.entries) {
      final website = <String, (int, String)>{};
      for (final r in stok.where((r) => r['kode_posko'] == kode)) {
        final nama = r['nama_item'] ?? '';
        website[_kunci(nama)] = (int.tryParse(r['jumlah_stok'] ?? '') ?? 0, r['satuan'] ?? '');
      }
      final hp = {
        for (final b in await logistik.getStok(id)) _kunci(b.barang.namaItem): b,
      };
      final semua = {...website.keys, ...hp.keys};
      for (final k in semua) {
        final w = website[k]?.$1 ?? 0;
        final h = hp[k]?.jumlah ?? 0;
        if (w == h) continue;
        final nama = hp[k]?.barang.namaItem ?? k;
        final satuan = hp[k]?.barang.satuan ?? website[k]?.$2 ?? '';
        hasil.add('$nama (${namaPosko[id] ?? '-'}): website $w $satuan, HP $h $satuan');
      }
    }
    return hasil;
  }

  static Future<BarisGabung> _pengungsi(
    TableStore s,
    Map<String, String> r,
    Map<String, int> dikenal,
    Map<String, Pengungsi> lokal,
    bool simpan,
  ) async {
    final nama = r['nama'] ?? '-';
    final kode = r['kode'] ?? '';
    if (!KodeUnik.valid(kode)) return BarisGabung(BarisGabung.error, nama, 'Kode tidak valid');
    final poskoId = dikenal[r['kode_posko']];
    if (poskoId == null) {
      return BarisGabung(BarisGabung.lewati, nama, 'Posko tidak dikenal di HP ini');
    }
    final diubah = WaktuWib.baca(r['diubah_pada']);
    if (diubah == null) return BarisGabung(BarisGabung.error, nama, 'diubah_pada tidak valid');
    final dihapus = _waktuOpsional(r['dihapus_pada']);
    final jk = r['jenis_kelamin'];
    if (!DataOptions.jenisKelamin.contains(jk)) {
      return BarisGabung(BarisGabung.error, nama, 'Jenis kelamin tidak dikenali');
    }

    final ada = lokal[kode];
    final data = Pengungsi(
      id: ada?.id,
      kode: kode,
      poskoId: poskoId,
      nama: nama,
      asal: r['asal'] ?? '',
      tanggalLahir: Tanggal.baca(r['tanggal_lahir']),
      usia: int.tryParse(r['usia'] ?? '') ?? 0,
      jenisKelamin: jk!,
      nomorKk: r['nomor_kk'] ?? '',
      kondisiKesehatan: (r['kondisi_kesehatan'] ?? '').isEmpty
          ? DataOptions.kondisiSehat
          : r['kondisi_kesehatan']!,
      kelompokRentan: DataOptions.kelompokRentan.contains(r['kelompok_rentan'])
          ? r['kelompok_rentan']!
          : DataOptions.bukanRentan,
      riwayatPenyakit: r['riwayat_penyakit'] ?? '',
      dicatatOleh: r['dicatat_oleh'] ?? '',
      dibuatPada: WaktuWib.baca(r['dibuat_pada']) ?? diubah,
      diubahPada: diubah,
      dihapusPada: dihapus,
      statusKeberadaan: Pengungsi.bacaKeberadaan(r['status_keberadaan']),
      keluarPada: Tanggal.baca(r['keluar_pada']),
      keteranganKeluar: r['keterangan_keluar'] ?? '',
    );

    if (ada == null) {
      // Yang sudah dihapus di HP asal tetap disimpan sebagai tanda.
      if (simpan) await s.insert(DatabaseTables.pengungsi, data.toMap());
      return dihapus == null
          ? BarisGabung(BarisGabung.tambah, nama, 'Pengungsi baru')
          : BarisGabung(BarisGabung.lewati, nama, 'Sudah dihapus di HP asal');
    }
    if (!_lebihBaru(diubah, ada.diubahPada)) {
      return BarisGabung(BarisGabung.sama, nama, 'Versi di HP ini sama atau lebih baru');
    }
    if (simpan) await s.update(DatabaseTables.pengungsi, ada.id!, data.toMap());
    return dihapus != null && !ada.isDihapus
        ? BarisGabung(BarisGabung.hapus, nama, 'Dihapus di HP asal')
        : BarisGabung(BarisGabung.perbarui, nama, 'Data paket lebih baru');
  }

  static Future<BarisGabung> _catatan(
    TableStore s,
    Map<String, String> r,
    Map<String, int> dikenal,
    Set<String> kodeAda,
    _PetaBarang barang,
    bool simpan, {
    required bool masuk,
  }) async {
    final nama = r['nama_item'] ?? '-';
    final kode = r['kode'] ?? '';
    if (!KodeUnik.valid(kode)) return BarisGabung(BarisGabung.error, nama, 'Kode tidak valid');
    if (kodeAda.contains(kode)) return BarisGabung(BarisGabung.sama, nama, 'Sudah ada');
    final poskoId = dikenal[r['kode_posko']];
    if (poskoId == null) {
      return BarisGabung(BarisGabung.lewati, nama, 'Posko tidak dikenal di HP ini');
    }
    final jumlah = int.tryParse(masuk ? r['jumlah_masuk'] ?? '' : r['jumlah_keluar'] ?? '');
    final tanggal = Tanggal.baca(masuk ? r['tanggal_masuk'] : r['tanggal_keluar']);
    final dibuat = WaktuWib.baca(r['dibuat_pada']);
    if (jumlah == null || jumlah < 1 || tanggal == null || dibuat == null) {
      return BarisGabung(BarisGabung.error, nama, 'Jumlah/tanggal tidak valid');
    }
    final tujuan = r['tujuan'] ?? '';
    if (!masuk && !DataOptions.tujuanKeluar.containsKey(tujuan)) {
      return BarisGabung(BarisGabung.error, nama, 'Tujuan tidak dikenali');
    }

    final b = await barang.cari(r['kategori'] ?? '', nama, r['satuan'] ?? '');
    kodeAda.add(kode); // kode sama dua kali di satu paket -> hanya sekali
    if (simpan) {
      await s.insert(
        masuk ? DatabaseTables.barangMasuk : DatabaseTables.barangKeluar,
        masuk
            ? BarangMasuk(
                kode: kode, poskoId: poskoId, barangId: b.id!, jumlah: jumlah,
                sumberBantuan: r['sumber_bantuan'] ?? '', tanggal: tanggal,
                keterangan: r['keterangan'] ?? '', dicatatOleh: r['dicatat_oleh'] ?? '',
                dibuatPada: dibuat,
              ).toMap()
            : BarangKeluar(
                kode: kode, poskoId: poskoId, barangId: b.id!, jumlah: jumlah,
                tujuan: tujuan, penerima: r['penerima'] ?? '', tanggal: tanggal,
                keterangan: r['keterangan'] ?? '', dicatatOleh: r['dicatat_oleh'] ?? '',
                dibuatPada: dibuat,
              ).toMap(),
      );
    }
    return BarisGabung(BarisGabung.tambah, nama);
  }
}

/// Mencocokkan barang paket (kategori + nama) dengan master barang HP ini.
/// Barang yang belum ada ditambahkan ke master (supaya catatannya tetap masuk).
class _PetaBarang {
  _PetaBarang(this._s, this._simpan);

  final TableStore _s;
  final bool _simpan;
  final Map<String, Barang> _byKunci = {};
  final Map<String, int> _kategori = {};
  final List<String> baru = [];
  int _idSementara = -1;

  Future<void> muat() async {
    final repo = BarangRepository.withStore(_s);
    for (final k in await repo.getKategori()) {
      _kategori[k.nama.toLowerCase()] = k.id;
    }
    for (final b in await repo.getAll()) {
      _byKunci[b.kunci] = b;
    }
  }

  Future<Barang> cari(String kategori, String nama, String satuan) async {
    // Nama lama yang sudah digabung (misal "Pakaian Layak Pakai") -> nama baku.
    final baku = DataOptions.namaBakuBarang(nama);
    if (baku != nama) {
      final ada = _byKunci.values.where((b) => b.namaItem.toLowerCase() == baku.toLowerCase());
      if (ada.isNotEmpty) return ada.first;
    }
    var katId = _kategori[kategori.toLowerCase()];
    if (katId == null) {
      katId = _simpan
          ? await _s.insert(DatabaseTables.kategoriLogistik, {'nama': kategori})
          : _idSementara--;
      _kategori[kategori.toLowerCase()] = katId;
    }
    final kunci = Barang.kunciSama(katId, nama);
    final ada = _byKunci[kunci];
    if (ada != null) return ada;

    final b = Barang.baru(kategoriId: katId, namaItem: nama, satuan: satuan);
    final id = _simpan ? await _s.insert(DatabaseTables.barang, b.toMap()) : _idSementara--;
    final hasil = Barang.fromMap(b.toMap()..['id'] = id);
    _byKunci[kunci] = hasil;
    baru.add('$nama ($satuan)');
    return hasil;
  }
}
