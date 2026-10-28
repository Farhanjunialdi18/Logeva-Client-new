// ============================================================
// demo_data.dart
// Contoh data, HANYA untuk tampilan di Chrome (web).
// Tidak pernah masuk ke database SQLite di Android.
// ============================================================

import '../core/data_options.dart';
import '../models/barang.dart';
import '../models/catatan_logistik.dart';
import '../models/pengungsi.dart';
import '../models/posko.dart';
import '../models/relawan.dart';
import '../models/riwayat_transaksi.dart';
import '../utils/waktu_wib.dart';
import 'database_tables.dart';

class DemoData {
  DemoData._();

  static Map<String, List<Map<String, Object?>>> seed() {
    final now = DateTime.now();

    // poskoId 1 = Desa Panggarangan (lihat daftar posko di bawah).
    final pengungsi = [
      Pengungsi.baru(
        poskoId: 1,
        nama: 'Budi Santoso',
        asal: 'Desa Panggarangan',
        tanggalLahir: DateTime(1984, 3, 12),
        jenisKelamin: DataOptions.lakiLaki,
        nomorKk: '3602011203840001',
      ),
      Pengungsi.baru(
        poskoId: 1,
        nama: 'Siti Aminah',
        asal: 'Desa Panggarangan',
        tanggalLahir: DateTime(1997, 7, 25),
        jenisKelamin: DataOptions.perempuan,
        kelompokRentan: 'Ibu Hamil',
      ),
      Pengungsi.baru(
        poskoId: 1,
        nama: 'Mak Iyah',
        asal: 'Desa Cikaret',
        tanggalLahir: DateTime(1952, 1, 5),
        jenisKelamin: DataOptions.perempuan,
        kondisiKesehatan: 'Demam',
        kelompokRentan: 'Lansia',
        riwayatPenyakit: 'Hipertensi',
      ),
    ];

    // Master barang & kategori sama dengan isi awal database (versi 7).
    final kategori = [
      for (final (i, nama) in DataOptions.kategoriLogistik.indexed)
        {'id': i + 1, 'nama': nama},
    ];
    final barang = [
      for (final (nama, kat, satuan, kebutuhan) in DataOptions.barangAwal)
        Barang.baru(
          kategoriId: kat,
          namaItem: nama,
          satuan: satuan,
          kebutuhanHarian: kebutuhan,
        ),
    ];
    // id barang di memori = urutan di daftar baku (mulai 1).
    Barang id(String nama) {
      final i = barang.indexWhere((b) => b.namaItem == nama);
      return Barang.fromMap(barang[i].toMap()..['id'] = i + 1);
    }
    final hariIni = WaktuWib.hariIni();
    final masuk = [
      BarangMasuk.baru(
        poskoId: 1,
        barang: id('Beras'),
        jumlah: 50,
        sumberBantuan: 'BPBD Lebak',
        tanggal: hariIni.subtract(const Duration(days: 2)),
      ),
      BarangMasuk.baru(
        poskoId: 1,
        barang: id('Air Mineral'),
        jumlah: 300,
        sumberBantuan: 'Donatur warga',
        tanggal: hariIni.subtract(const Duration(days: 1)),
      ),
      BarangMasuk.baru(
        poskoId: 2,
        barang: id('Selimut'),
        jumlah: 40,
        sumberBantuan: 'BNPB',
        tanggal: hariIni,
      ),
    ];
    final keluar = [
      BarangKeluar.baru(
        poskoId: 1,
        barang: id('Beras'),
        jumlah: 12,
        tujuan: 'dapur_umum',
        tanggal: hariIni,
      ),
    ];

    final riwayat = [
      RiwayatTransaksi(
        jenis: RiwayatTransaksi.jenisImport,
        jenisData: 'Data Pengungsi',
        berhasil: true,
        jumlahBaris: 3,
        waktu: now.subtract(const Duration(days: 1)),
      ),
    ];

    // Urutan ini menentukan id di memori: Desa Panggarangan = 1, Cisolok = 2.
    final posko = [
      Posko.baru(
        nama: 'Desa Panggarangan',
        namaDesa: 'Panggarangan',
        alamat: 'Kec. Panggarangan',
        luasLokasi: 1050,
        latitude: '-6.9195',
        longitude: '106.1297',
      ).ubahStatus(AksiOperasional.mulai, now.subtract(const Duration(days: 2))),
      Posko.baru(nama: 'Cisolok', namaDesa: 'Cisolok', alamat: 'Kec. Cisolok'),
    ];

    final relawan = [
      Relawan(
        nama: 'Andi Saputra',
        kontak: 'andi@gmail.com',
        pin: '123456',
        poskoId: 1,
        posko: 'Desa Panggarangan',
        dibuatPada: now.subtract(const Duration(hours: 3)),
      ),
    ];

    // Catatan: akun admin TIDAK ditaruh di sini. Admin pertama dibuat
    // otomatis oleh AdminRepository.ensureDefaultAdmin() (web & Android).
    return {
      DatabaseTables.pengungsi: pengungsi.map((e) => e.toMap()).toList(),
      DatabaseTables.kategoriLogistik: kategori,
      DatabaseTables.barang: barang.map((e) => e.toMap()).toList(),
      DatabaseTables.barangMasuk: masuk.map((e) => e.toMap()).toList(),
      DatabaseTables.barangKeluar: keluar.map((e) => e.toMap()).toList(),
      DatabaseTables.riwayat: riwayat.map((e) => e.toMap()).toList(),
      DatabaseTables.posko: posko.map((e) => e.toMap()).toList(),
      DatabaseTables.relawan: relawan.map((e) => e.toMap()).toList(),
    };
  }
}
