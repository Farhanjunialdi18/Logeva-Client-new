// ============================================================
// paket_data_service.dart
// EKSPOR PAKET DATA POSKO (§8): satu file ZIP berisi 6 CSV untuk dibawa
// lewat USB lalu digabung di website pusat (menu Import Paket Data Posko).
//
//   info.csv           versi format, waktu ekspor, kode perangkat
//   posko.csv          data posko (dicocokkan dengan kode_posko)
//   pengungsi.csv      biodata & kesehatan, TERMASUK yang ditandai dihapus
//   barang_masuk.csv   catatan logistik (kode yang sudah diimpor dilewati)
//   barang_keluar.csv  catatan logistik
//   stok.csv           stok di HP, hanya untuk pengecekan di pusat
//   petugas.csv        nama & kontak admin (penanggung jawab) dan relawan aktif,
//                      supaya pusat tahu siapa yang bisa dihubungi. TANPA PIN/password.
//
// Aturan format (wajib persis): UTF-8, pemisah koma, judul kolom persis,
// tanggal YYYY-MM-DD, tanggal-waktu YYYY-MM-DD HH:MM:SS WIB, desimal titik,
// kolom tanpa nilai dikosongkan. Ekspor selalu berisi SELURUH data posko,
// sehingga paket yang sama aman diimpor berkali-kali (lihat kolom kode).
// ============================================================

import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../data/local_database.dart';
import '../data/repositories/admin_repository.dart';
import '../data/repositories/barang_repository.dart';
import '../data/repositories/logistik_repository.dart';
import '../data/repositories/pengaturan_repository.dart';
import '../data/repositories/pengungsi_repository.dart';
import '../data/repositories/relawan_repository.dart';
import '../data/repositories/riwayat_repository.dart';
import '../data/table_store.dart';
import '../models/barang.dart';
import '../models/catatan_logistik.dart';
import '../models/pengungsi.dart';
import '../models/posko.dart';
import '../models/riwayat_transaksi.dart';
import '../utils/angka.dart';
import '../utils/berkas_terkunci.dart';
import '../utils/tanggal.dart';
import '../utils/waktu_wib.dart';
import 'csv_service.dart';
import 'file_service.dart';
import 'session_service.dart';
import 'transfer_service.dart';

/// Satu petugas di petugas.csv.
class PetugasPaket {
  static const String admin = 'admin';
  static const String relawan = 'relawan';

  /// null = admin: penanggung jawab SEMUA posko di paket.
  final int? poskoId;
  final String peran;
  final String nama;
  final String kontak;

  /// Kode unik akun: sama di HP Induk & HP Anggota, supaya pusat bisa
  /// menampilkan setiap petugas satu kali walau paket datang dari banyak HP.
  final String kodeAkun;

  const PetugasPaket({
    this.poskoId,
    this.kodeAkun = '',
    required this.peran,
    required this.nama,
    required this.kontak,
  });
}

/// Semua data yang masuk ke satu paket.
class PaketData {
  static const String versiFormat = '1';

  final DateTime dibuatPada;
  final String kodePerangkat;
  final String dieksporOleh;

  /// 'induk' / 'anggota' (HP mana yang mengirim paket ini).
  final String peranPerangkat;
  final List<Posko> posko;

  /// Nama relawan per posko (relawan_penanggung_jawab).
  final Map<int, List<String>> relawan;
  final List<Pengungsi> pengungsi; // termasuk yang dihapus
  final List<BarangMasuk> masuk;
  final List<BarangKeluar> keluar;
  final Map<int, Barang> barang;
  final Map<int, List<StokBarang>> stok; // per posko
  final List<PetugasPaket> petugas; // admin & relawan aktif

  const PaketData({
    required this.dibuatPada,
    required this.kodePerangkat,
    required this.dieksporOleh,
    this.peranPerangkat = 'induk',
    required this.posko,
    required this.relawan,
    required this.pengungsi,
    required this.masuk,
    required this.keluar,
    required this.barang,
    required this.stok,
    this.petugas = const [],
  });

  // ---------------- JUDUL KOLOM (persis §8) ----------------

  /// Kolom tambahan di akhir (peran_perangkat, kode_akun) boleh tidak ada
  /// di paket lama; website tetap menerimanya.
  static const List<String> kolomInfo = [
    'versi_format', 'dibuat_pada', 'kode_perangkat', 'diekspor_oleh',
    'peran_perangkat',
  ];
  static const List<String> kolomPosko = [
    'kode_posko', 'nama_lokasi', 'nama_desa', 'alamat_lokasi', 'luas_lokasi',
    'kapasitas_pengungsi', 'latitude', 'longitude', 'status_operasional',
    'mulai_beroperasi_at', 'selesai_beroperasi_at',
    'relawan_penanggung_jawab', 'diubah_pada',
  ];
  static const List<String> kolomPengungsi = [
    'kode', 'kode_posko', 'nama', 'asal', 'tanggal_lahir', 'nomor_kk', 'usia',
    'jenis_kelamin', 'kondisi_kesehatan', 'kelompok_rentan',
    'riwayat_penyakit', 'dicatat_oleh', 'dibuat_pada', 'diubah_pada',
    'dihapus_pada',
    // Sejak 27 Okt 2026 (versi format tetap '1'; paket lama tanpa kolom ini
    // = semua masih di posko).
    'status_keberadaan', 'keluar_pada', 'keterangan_keluar',
  ];
  static const List<String> kolomMasuk = [
    'kode', 'kode_posko', 'nama_item', 'kategori', 'satuan', 'jumlah_masuk',
    'sumber_bantuan', 'tanggal_masuk', 'keterangan', 'dicatat_oleh',
    'dibuat_pada',
  ];
  static const List<String> kolomKeluar = [
    'kode', 'kode_posko', 'nama_item', 'kategori', 'satuan', 'jumlah_keluar',
    'tujuan', 'penerima', 'tanggal_keluar', 'keterangan', 'dicatat_oleh',
    'dibuat_pada',
  ];
  static const List<String> kolomStok = [
    'kode_posko', 'nama_item', 'satuan', 'jumlah_stok',
  ];
  static const List<String> kolomPetugas = [
    'kode_posko', 'peran', 'nama', 'kontak', 'kode_akun',
  ];

  // ---------------- NILAI ----------------

  static String _waktu(DateTime? t) => t == null ? '' : WaktuWib.tanggalWaktu(t);

  Map<int, String> get _kodePosko => {for (final p in posko) p.id!: p.kode};

  /// Nama file: `paket_<nama-posko-tanpa-spasi>_<YYYYMMDD-HHMM>.zip`.
  /// Lebih dari satu posko: nama posko diganti "SemuaPosko".
  String get namaFile {
    final nama = posko.length == 1 ? posko.single.nama : 'SemuaPosko';
    final bersih = nama.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
    return 'paket_${bersih.isEmpty ? 'Posko' : bersih}_'
        '${WaktuWib.capFile(dibuatPada)}.zip';
  }

  /// Isi setiap file CSV (nama file -> teks).
  Map<String, String> get csv {
    final kodePosko = _kodePosko;
    List<String> barangKolom(int id) {
      final b = barang[id];
      return [b?.namaItem ?? '', b?.kategori ?? '', b?.satuan ?? ''];
    }

    return {
      'info.csv': CsvService.encode(kolomInfo, [
        [versiFormat, _waktu(dibuatPada), kodePerangkat, dieksporOleh, peranPerangkat],
      ]),
      'posko.csv': CsvService.encode(kolomPosko, [
        for (final p in posko)
          [
            p.kode,
            p.nama,
            p.namaDesa,
            p.alamat,
            p.luasLokasi == null ? '' : Angka.ekspor(p.luasLokasi!),
            '${p.kapasitas}',
            p.latitude,
            p.longitude,
            p.statusOperasional,
            _waktu(p.mulaiBeroperasiAt),
            _waktu(p.selesaiBeroperasiAt),
            (relawan[p.id] ?? const []).join(', '),
            _waktu(p.diubahPada),
          ],
      ]),
      'pengungsi.csv': CsvService.encode(kolomPengungsi, [
        for (final e in pengungsi)
          [
            e.kode,
            kodePosko[e.poskoId] ?? '',
            e.nama,
            e.asal,
            e.tanggalLahir == null ? '' : Tanggal.format(e.tanggalLahir!),
            e.nomorKk,
            '${e.usia}',
            e.jenisKelamin,
            e.kondisiKesehatan,
            e.kelompokRentan,
            e.riwayatPenyakit,
            e.dicatatOleh,
            _waktu(e.dibuatPada),
            _waktu(e.diubahPada),
            _waktu(e.dihapusPada),
            e.statusKeberadaan,
            e.keluarPada == null ? '' : Tanggal.format(e.keluarPada!),
            e.keteranganKeluar,
          ],
      ]),
      'barang_masuk.csv': CsvService.encode(kolomMasuk, [
        for (final m in masuk)
          [
            m.kode,
            kodePosko[m.poskoId] ?? '',
            ...barangKolom(m.barangId),
            '${m.jumlah}',
            m.sumberBantuan,
            Tanggal.format(m.tanggal),
            m.keterangan,
            m.dicatatOleh,
            _waktu(m.dibuatPada),
          ],
      ]),
      'barang_keluar.csv': CsvService.encode(kolomKeluar, [
        for (final k in keluar)
          [
            k.kode,
            kodePosko[k.poskoId] ?? '',
            ...barangKolom(k.barangId),
            '${k.jumlah}',
            k.tujuan,
            k.penerima,
            Tanggal.format(k.tanggal),
            k.keterangan,
            k.dicatatOleh,
            _waktu(k.dibuatPada),
          ],
      ]),
      'stok.csv': CsvService.encode(kolomStok, [
        for (final p in posko)
          for (final s in stok[p.id] ?? const <StokBarang>[])
            [p.kode, s.barang.namaItem, s.barang.satuan, '${s.jumlah}'],
      ]),
      'petugas.csv': CsvService.encode(kolomPetugas, [
        for (final t in petugas)
          [kodePosko[t.poskoId] ?? '', t.peran, t.nama, t.kontak, t.kodeAkun],
      ]),
    };
  }

  /// File ZIP berisi semua CSV di akar ZIP.
  Uint8List get zip {
    final arsip = Archive();
    for (final e in csv.entries) {
      arsip.addFile(ArchiveFile.string(e.key, e.value));
    }
    return ZipEncoder().encodeBytes(arsip);
  }

  // ---------------- RINGKASAN UNTUK LAYAR ----------------

  int get jumlahPengungsiAktif => pengungsi.where((e) => !e.isDihapus).length;
  int get jumlahPengungsiDihapus => pengungsi.where((e) => e.isDihapus).length;

  List<PetugasPaket> get admin =>
      petugas.where((t) => t.peran == PetugasPaket.admin).toList();
  List<PetugasPaket> relawanPosko(int? poskoId) => petugas
      .where((t) => t.peran == PetugasPaket.relawan && t.poskoId == poskoId)
      .toList();
}

/// Hasil pemeriksaan sebelum ekspor.
class PeriksaPaket {
  /// Harus diperbaiki dulu; ekspor tidak bisa dilanjutkan.
  final List<String> penghalang;

  /// Boleh tetap diekspor, tapi pengguna perlu tahu.
  final List<String> peringatan;

  const PeriksaPaket({required this.penghalang, required this.peringatan});

  bool get bisaEkspor => penghalang.isEmpty;
}

class PaketDataService {
  PaketDataService._();

  static const String _label = 'Paket Data Posko';

  /// Kumpulkan seluruh data [posko] dari database.
  static Future<PaketData> kumpulkan(
    List<Posko> posko, {
    TableStore? store,
    String? kodePerangkat,
    String? dieksporOleh,
    DateTime? waktu,
  }) async {
    final s = store ?? LocalDatabase.store;
    final ids = posko.map((p) => p.id).toSet();
    final logistik = LogistikRepository.withStore(s);

    // Petugas aktif: admin = penanggung jawab semua posko di HP ini,
    // relawan = petugas di posko tugasnya. PIN & password tidak ikut.
    final relawan = <int, List<String>>{};
    final petugas = <PetugasPaket>[
      for (final a in await AdminRepository.withStore(s).getAll())
        if (a.isAktif)
          PetugasPaket(
            peran: PetugasPaket.admin,
            nama: a.nama,
            kontak: a.email,
            kodeAkun: a.kode,
          ),
    ];
    for (final r in await RelawanRepository.withStore(s).getAll()) {
      if (r.poskoId != null && ids.contains(r.poskoId) && r.isAktif) {
        (relawan[r.poskoId!] ??= []).add(r.nama);
        petugas.add(PetugasPaket(
          poskoId: r.poskoId,
          kodeAkun: r.kode,
          peran: PetugasPaket.relawan,
          nama: r.nama,
          kontak: r.kontak,
        ));
      }
    }

    return PaketData(
      dibuatPada: waktu ?? DateTime.now(),
      kodePerangkat: kodePerangkat ??
          await PengaturanRepository.withStore(s).kodePerangkat(),
      dieksporOleh: dieksporOleh ?? SessionService.instance.namaPencatat,
      peranPerangkat: await PengaturanRepository.withStore(s).peranPerangkat(),
      posko: posko,
      relawan: relawan,
      pengungsi: (await PengungsiRepository.withStore(s)
              .getAll(termasukDihapus: true))
          .where((e) => ids.contains(e.poskoId))
          .toList(),
      masuk: (await logistik.getMasuk())
          .where((e) => ids.contains(e.poskoId))
          .toList(),
      keluar: (await logistik.getKeluar())
          .where((e) => ids.contains(e.poskoId))
          .toList(),
      barang: {
        for (final b in await BarangRepository.withStore(s).getAll()) b.id!: b,
      },
      stok: {for (final p in posko) p.id!: await logistik.getStok(p.id)},
      petugas: petugas,
    );
  }

  /// Periksa kelengkapan. Posko wajib lengkap (kolom wajib posko.csv);
  /// pengungsi lama tanpa tanggal lahir hanya diperingatkan.
  static PeriksaPaket periksa(PaketData paket) {
    final penghalang = <String>[
      if (paket.posko.isEmpty) 'Belum ada posko yang dipilih.',
      for (final p in paket.posko)
        if (!p.lengkap)
          '${p.label}: lengkapi ${p.dataBelumLengkap.join(', ')} '
              '(menu Data Posko).',
    ];

    final peringatan = <String>[];
    for (final p in paket.posko) {
      final tanpaLahir = paket.pengungsi
          .where((e) => e.poskoId == p.id && !e.isDihapus && e.perluDilengkapi)
          .length;
      if (tanpaLahir > 0) {
        peringatan.add('${p.label}: $tanpaLahir pengungsi belum punya tanggal '
            'lahir (data versi lama). Sebaiknya dilengkapi dulu.');
      }
    }
    if (paket.admin.isEmpty) {
      peringatan.add('Tidak ada admin aktif, jadi pusat tidak tahu siapa '
          'penanggung jawabnya.');
    }
    for (final a in paket.admin) {
      if (a.kontak.trim().isEmpty ||
          a.kontak.trim().toLowerCase() == AdminRepository.defaultEmail) {
        peringatan.add('Kontak admin ${a.nama} masih bawaan '
            '(${AdminRepository.defaultEmail}). Ganti dengan email yang bisa '
            'dihubungi di Settings → Profil Admin.');
      }
    }
    for (final p in paket.posko) {
      if (paket.relawanPosko(p.id).isEmpty) {
        peringatan.add('${p.label}: belum ada relawan aktif yang ditugaskan.');
      }
    }
    return PeriksaPaket(penghalang: penghalang, peringatan: peringatan);
  }

  static const String pesanBelumAdaKataSandi =
      'Kata sandi posko belum diatur. Supervisor mengaturnya di HP Induk: '
      'Settings → Kata Sandi Posko.';

  /// Isi file paket yang disimpan: ZIP paket yang DIKUNCI kata sandi posko
  /// (data pribadi pengungsi dibawa keluar posko). Melempar StateError kalau
  /// kata sandi posko belum diatur.
  static Future<Uint8List> berkasTerkunci(PaketData paket, {TableStore? store}) async {
    final kataSandi = await PengaturanRepository.withStore(store ?? LocalDatabase.store)
        .kataSandiBerkas();
    if (kataSandi.isEmpty) throw StateError(pesanBelumAdaKataSandi);
    return BerkasTerkunci.kunci(paket.zip, kataSandi);
  }

  /// Simpan paket ke file ZIP (pengguna memilih lokasi, misal flashdisk).
  static Future<TransferResult> simpan(PaketData paket) async {
    try {
      final berkas = await berkasTerkunci(paket);
      final saved = await FileService.saveBytes(
        paket.namaFile,
        berkas,
        dialogTitle: 'Simpan Paket Data Posko',
      );
      if (!saved) {
        return const TransferResult(
            TransferStatus.cancelled, 'Ekspor dibatalkan.');
      }
      final jumlah = paket.pengungsi.length +
          paket.masuk.length +
          paket.keluar.length;
      await RiwayatRepository.instance.log(
        jenis: RiwayatTransaksi.jenisExport,
        jenisData: _label,
        berhasil: true,
        jumlahBaris: jumlah,
        keterangan: '${paket.namaFile}: ${paket.posko.length} posko, '
            '${paket.pengungsi.length} pengungsi, ${paket.masuk.length} '
            'barang masuk, ${paket.keluar.length} barang keluar',
      );
      return TransferResult(
        TransferStatus.success,
        'Paket ${paket.namaFile} tersimpan dan dikunci kata sandi posko.\n\n'
        'Bawa file ini ke pusat lalu impor di menu Import Paket Posko (pusat '
        'mengetik kata sandi posko saat impor pertama). Hapus file dari '
        'flashdisk setelah diimpor karena berisi data pribadi.',
      );
    } on StateError catch (e) {
      return TransferResult(TransferStatus.failed, e.message);
    } catch (e) {
      await RiwayatRepository.instance.log(
        jenis: RiwayatTransaksi.jenisExport,
        jenisData: _label,
        berhasil: false,
        keterangan: '$e',
      );
      return TransferResult(TransferStatus.failed, 'Ekspor gagal: $e');
    }
  }
}
