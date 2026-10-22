// ============================================================
// demo_data.dart
// Contoh data, HANYA untuk tampilan di Chrome (web).
// Tidak pernah masuk ke database SQLite di Android.
// ============================================================

import '../models/logistik.dart';
import '../models/pengungsi.dart';
import '../models/posko.dart';
import '../models/relawan.dart';
import '../models/riwayat_transaksi.dart';
import 'database_tables.dart';

class DemoData {
  DemoData._();

  static Map<String, List<Map<String, Object?>>> seed() {
    final now = DateTime.now();

    final pengungsi = [
      Pengungsi(
        nama: 'Budi Santoso',
        jenisKelamin: 'L',
        usia: 42,
        kondisi: 'Sehat',
        domisili: 'Desa Panggarangan',
        posko: 'Desa Panggarangan',
        dibuatPada: now,
      ),
      Pengungsi(
        nama: 'Siti Aminah',
        jenisKelamin: 'P',
        usia: 29,
        kondisi: 'Perlu Perawatan',
        domisili: 'Desa Panggarangan',
        posko: 'Desa Panggarangan',
        dibuatPada: now,
      ),
      Pengungsi(
        nama: 'Ahmad Saputra',
        jenisKelamin: 'L',
        usia: 35,
        kondisi: 'Sehat',
        domisili: 'Desa Panggarangan',
        posko: 'Desa Panggarangan',
        dibuatPada: now,
      ),
    ];

    final logistik = [
      Logistik(
        namaBarang: 'Selimut',
        kategori: 'Perlengkapan',
        jumlah: 40,
        satuan: 'Buah',
        posko: 'Cisolok',
        dibuatPada: now,
      ),
      Logistik(
        namaBarang: 'Beras',
        kategori: 'Makanan',
        jumlah: 25,
        satuan: 'Kg',
        posko: 'Desa Panggarangan',
        dibuatPada: now,
      ),
      Logistik(
        namaBarang: 'Air Mineral',
        kategori: 'Minuman',
        jumlah: 50,
        satuan: 'Dus',
        posko: 'Desa Panggarangan',
        dibuatPada: now,
      ),
    ];

    final riwayat = [
      RiwayatTransaksi(
        jenis: RiwayatTransaksi.jenisImport,
        jenisData: 'Data Logistik',
        berhasil: true,
        jumlahBaris: 3,
        waktu: now.subtract(const Duration(days: 1)),
      ),
    ];

    final posko = [
      Posko(nama: 'Desa Panggarangan', alamat: 'Kec. Panggarangan', dibuatPada: now),
      Posko(nama: 'Cisolok', alamat: 'Kec. Cisolok', dibuatPada: now),
    ];

    final relawan = [
      Relawan(
        nama: 'Andi Saputra',
        kontak: 'andi@gmail.com',
        pin: '123456',
        posko: 'Desa Panggarangan',
        dibuatPada: now.subtract(const Duration(hours: 3)),
      ),
    ];

    // Catatan: akun admin TIDAK ditaruh di sini. Admin pertama dibuat
    // otomatis oleh AdminRepository.ensureDefaultAdmin() (web & Android).
    return {
      DatabaseTables.pengungsi: pengungsi.map((e) => e.toMap()).toList(),
      DatabaseTables.logistik: logistik.map((e) => e.toMap()).toList(),
      DatabaseTables.riwayat: riwayat.map((e) => e.toMap()).toList(),
      DatabaseTables.posko: posko.map((e) => e.toMap()).toList(),
      DatabaseTables.relawan: relawan.map((e) => e.toMap()).toList(),
    };
  }
}
