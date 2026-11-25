// ============================================================
// logistik_repository.dart
// CATATAN BARANG MASUK / KELUAR dan STOK per posko.
//
// Aturan (sama dengan website, §3.4):
//  - Stok hanya berubah lewat catatan: stok = Σ masuk − Σ keluar.
//  - Barang keluar ditolak kalau melebihi stok saat itu. Pengecualian: di
//    HP Anggota boleh (dengan konfirmasi), karena stoknya bisa ketinggalan
//    dari HP lain sebelum sinkron. Stok minus lalu ditandai untuk dicek.
//  - Tanggal tidak boleh setelah hari ini (WIB).
//  - Catatan bisa DIEDIT & DIHAPUS (koreksi salah input). Hapus = ditandai
//    dihapus (tidak dihitung di stok) supaya ikut terkirim ke HP lain & pusat.
// ============================================================

import '../../core/data_options.dart';
import '../../models/barang.dart';
import '../../models/catatan_logistik.dart';
import '../../utils/waktu_wib.dart';
import '../data_events.dart';
import '../database_tables.dart';
import '../local_database.dart';
import '../table_store.dart';
import 'barang_repository.dart';
import 'pengaturan_repository.dart';

/// Catatan ditolak; [message] siap ditampilkan.
class LogistikException implements Exception {
  final String message;
  const LogistikException(this.message);

  @override
  String toString() => message;
}

class LogistikRepository {
  LogistikRepository._(this._store);
  static final LogistikRepository instance =
      LogistikRepository._(LocalDatabase.store);

  /// Untuk tes: repository dengan penyimpanan sendiri.
  factory LogistikRepository.withStore(TableStore store) =>
      LogistikRepository._(store);

  final TableStore _store;

  // ---------------- AMBIL CATATAN ----------------

  /// Barang masuk. [poskoId] diisi = hanya posko itu. Yang ditandai dihapus
  /// tidak ikut, kecuali [termasukDihapus] (untuk paket & penggabungan).
  Future<List<BarangMasuk>> getMasuk({int? poskoId, bool termasukDihapus = false}) async =>
      (await _store.getAll(DatabaseTables.barangMasuk))
          .map(BarangMasuk.fromMap)
          .where((e) => poskoId == null || e.poskoId == poskoId)
          .where((e) => termasukDihapus || !e.isDihapus)
          .toList();

  Future<List<BarangKeluar>> getKeluar({int? poskoId, bool termasukDihapus = false}) async =>
      (await _store.getAll(DatabaseTables.barangKeluar))
          .map(BarangKeluar.fromMap)
          .where((e) => poskoId == null || e.poskoId == poskoId)
          .where((e) => termasukDihapus || !e.isDihapus)
          .toList();

  /// Masuk & keluar digabung, terbaru di atas (tanggal, lalu waktu dicatat).
  Future<List<CatatanLogistik>> getCatatan({int? poskoId}) async {
    final semua = <CatatanLogistik>[
      ...await getMasuk(poskoId: poskoId),
      ...await getKeluar(poskoId: poskoId),
    ];
    semua.sort((a, b) {
      final t = b.tanggal.compareTo(a.tanggal);
      return t != 0 ? t : b.dibuatPada.compareTo(a.dibuatPada);
    });
    return semua;
  }

  // ---------------- STOK ----------------

  /// Stok semua barang yang pernah tercatat di posko [poskoId].
  /// [termasukPokok] = true: barang pokok (punya kebutuhan harian) ikut
  /// walaupun belum pernah masuk (stok 0), seperti hitungan website.
  /// [semuaBarang] = true: semua barang di master ikut (stok 0 jika belum
  /// ada catatan), misal untuk pilihan barang keluar di HP Anggota.
  Future<List<StokBarang>> getStok(int? poskoId,
      {bool termasukPokok = false, bool semuaBarang = false}) async {
    final jumlah = <int, int>{};
    final terakhir = <int, DateTime>{};
    void catat(CatatanLogistik c, int tanda) {
      jumlah[c.barangId] = (jumlah[c.barangId] ?? 0) + tanda * c.jumlah;
      final t = terakhir[c.barangId];
      if (t == null || c.dibuatPada.isAfter(t)) {
        terakhir[c.barangId] = c.dibuatPada;
      }
    }

    for (final m in await getMasuk(poskoId: poskoId)) {
      catat(m, 1);
    }
    for (final k in await getKeluar(poskoId: poskoId)) {
      catat(k, -1);
    }

    final hasil = <StokBarang>[];
    for (final b in await BarangRepository.withStore(_store).getAll()) {
      if (!semuaBarang &&
          !jumlah.containsKey(b.id) &&
          !(termasukPokok && b.isPokok)) {
        continue;
      }
      hasil.add(StokBarang(
        barang: b,
        jumlah: jumlah[b.id] ?? 0,
        terakhirDiperbarui: terakhir[b.id],
      ));
    }
    return hasil;
  }

  Future<int> stokBarang(int poskoId, int barangId) async {
    var total = 0;
    for (final m in await getMasuk(poskoId: poskoId)) {
      if (m.barangId == barangId) total += m.jumlah;
    }
    for (final k in await getKeluar(poskoId: poskoId)) {
      if (k.barangId == barangId) total -= k.jumlah;
    }
    return total;
  }

  // ---------------- CATAT ----------------

  static void _cekUmum(int jumlah, DateTime tanggal) {
    if (jumlah < 1) throw const LogistikException('Jumlah minimal 1.');
    if (tanggal.isAfter(WaktuWib.hariIni())) {
      throw const LogistikException('Tanggal tidak boleh setelah hari ini.');
    }
  }

  Future<void> catatMasuk(BarangMasuk data) async {
    _cekUmum(data.jumlah, data.tanggal);
    if (data.sumberBantuan.trim().isEmpty) {
      throw const LogistikException('Sumber bantuan wajib diisi.');
    }
    await _store.insert(DatabaseTables.barangMasuk, data.toMap());
    await PengaturanRepository.withStore(_store).tambahPerubahanLokal();
    DataEvents.instance.notifyChanged();
  }

  /// Ditolak kalau jumlah keluar melebihi stok (pesan sama dengan website).
  /// [izinkanMelebihiStok] hanya untuk HP Anggota setelah pengguna
  /// mengonfirmasi (stok HP itu bisa belum lengkap sebelum sinkron).
  Future<void> catatKeluar(
    BarangKeluar data, {
    required Barang barang,
    bool izinkanMelebihiStok = false,
  }) async {
    _cekUmum(data.jumlah, data.tanggal);
    if (!DataOptions.tujuanKeluar.containsKey(data.tujuan)) {
      throw const LogistikException('Pilih untuk apa barang dikeluarkan.');
    }
    final sisa = await stokBarang(data.poskoId!, data.barangId);
    if (data.jumlah > sisa && !izinkanMelebihiStok) {
      throw LogistikException(sisa > 0
          ? 'Stok tidak cukup. Sisa stok hanya $sisa ${barang.satuan}.'
          : 'Stok barang ini sudah habis.');
    }
    await _store.insert(DatabaseTables.barangKeluar, data.toMap());
    await PengaturanRepository.withStore(_store).tambahPerubahanLokal();
    DataEvents.instance.notifyChanged();
  }

  // ---------------- EDIT & HAPUS (koreksi salah input) ----------------

  Future<void> _simpanUbah(String tabel, CatatanLogistik c, Map<String, Object?> map) async {
    if (c.id == null) throw const LogistikException('Catatan tidak ditemukan.');
    await _store.update(tabel, c.id!, map);
    await PengaturanRepository.withStore(_store).tambahPerubahanLokal();
    DataEvents.instance.notifyChanged();
  }

  /// Simpan hasil edit barang masuk. Ditolak kalau stok barang lama jadi
  /// minus (barang sudah terlanjur dikeluarkan), kecuali [izinkanMinus].
  Future<void> ubahMasuk(BarangMasuk lama, BarangMasuk baru,
      {bool izinkanMinus = false}) async {
    _cekUmum(baru.jumlah, baru.tanggal);
    if (baru.sumberBantuan.trim().isEmpty) {
      throw const LogistikException('Sumber bantuan wajib diisi.');
    }
    if (!izinkanMinus) {
      final stokLama = await stokBarang(lama.poskoId!, lama.barangId);
      final sisa = stokLama - lama.jumlah + (baru.barangId == lama.barangId ? baru.jumlah : 0);
      if (sisa < 0) {
        throw LogistikException('Tidak bisa: sebagian barang ini sudah dikeluarkan. '
            'Stok akan menjadi $sisa.');
      }
    }
    await _simpanUbah(DatabaseTables.barangMasuk, lama, baru.toMap());
  }

  /// Simpan hasil edit barang keluar (cek stok sama dengan catat baru).
  Future<void> ubahKeluar(BarangKeluar lama, BarangKeluar baru,
      {required Barang barang, bool izinkanMelebihiStok = false}) async {
    _cekUmum(baru.jumlah, baru.tanggal);
    if (!DataOptions.tujuanKeluar.containsKey(baru.tujuan)) {
      throw const LogistikException('Pilih untuk apa barang dikeluarkan.');
    }
    var sisa = await stokBarang(lama.poskoId!, baru.barangId);
    if (baru.barangId == lama.barangId) sisa += lama.jumlah;
    if (baru.jumlah > sisa && !izinkanMelebihiStok) {
      throw LogistikException(sisa > 0
          ? 'Stok tidak cukup. Sisa stok hanya $sisa ${barang.satuan}.'
          : 'Stok barang ini sudah habis.');
    }
    await _simpanUbah(DatabaseTables.barangKeluar, lama, baru.toMap());
  }

  /// Hapus catatan (ditandai). Barang masuk ditolak kalau stok jadi minus.
  Future<void> hapus(CatatanLogistik c, {bool izinkanMinus = false}) async {
    if (c is BarangMasuk) {
      if (!izinkanMinus && await stokBarang(c.poskoId!, c.barangId) - c.jumlah < 0) {
        throw const LogistikException('Tidak bisa dihapus: sebagian barang ini sudah '
            'dikeluarkan. Hapus / koreksi dulu catatan barang keluarnya.');
      }
      await _simpanUbah(DatabaseTables.barangMasuk, c, c.tandaiDihapus().toMap());
    } else if (c is BarangKeluar) {
      await _simpanUbah(DatabaseTables.barangKeluar, c, c.tandaiDihapus().toMap());
    }
  }

  /// Barang yang stoknya MINUS di posko [poskoId] (keluar > masuk yang
  /// tercatat), misal setelah data beberapa HP digabung.
  Future<List<StokBarang>> stokMinus(int? poskoId) async =>
      (await getStok(poskoId)).where((s) => s.jumlah < 0).toList();
}
