// ============================================================
// posko.dart
// Bentuk data POSKO pengungsian, mengikuti tabel `lokasis` website.
//
// [kode]  = kode unik (UUID) untuk Paket Data Posko, tidak pernah berubah.
// [nama]  = masih dipakai sebagai penghubung ke data pengungsi & logistik
//           (kolom 'posko' di tabel tersebut) sampai keduanya pindah ke id.
// Relawan sudah merujuk posko lewat [id] (kolom relawan.posko_id).
// ============================================================

import '../utils/kode_unik.dart';
import '../utils/waktu_wib.dart';
import 'model_utils.dart';

/// Aksi mengubah status operasional (sama dengan website).
enum AksiOperasional { mulai, tutup, siaga }

/// Aksi tidak bisa dilakukan; [message] siap ditampilkan ke pengguna.
class PoskoException implements Exception {
  final String message;
  const PoskoException(this.message);

  @override
  String toString() => message;
}

class Posko {
  // ---- Status operasional (nilai sama persis dengan website) ----
  static const String siaga = 'siaga';
  static const String beroperasi = 'beroperasi';
  static const String selesai = 'selesai';

  /// Kapasitas = luas ÷ 3,5 m² per orang (LokasiImportController::M2_PER_ORANG).
  static const double m2PerOrang = 3.5;

  final int? id;
  final String kode;
  final String nama; // nama_lokasi, contoh: 'Desa Panggarangan'
  final String namaDesa;
  final String alamat;
  final double? luasLokasi; // m², null = belum diisi
  final String latitude; // teks angka desimal, kosong = belum diisi
  final String longitude;
  final String statusOperasional;
  final DateTime? mulaiBeroperasiAt;
  final DateTime? selesaiBeroperasiAt;
  final DateTime dibuatPada;
  final DateTime diubahPada;

  const Posko({
    this.id,
    required this.kode,
    required this.nama,
    this.namaDesa = '',
    this.alamat = '',
    this.luasLokasi,
    this.latitude = '',
    this.longitude = '',
    this.statusOperasional = siaga,
    this.mulaiBeroperasiAt,
    this.selesaiBeroperasiAt,
    required this.dibuatPada,
    required this.diubahPada,
  });

  /// Posko baru: kode unik & waktu dibuat otomatis.
  factory Posko.baru({
    required String nama,
    String namaDesa = '',
    String alamat = '',
    double? luasLokasi,
    String latitude = '',
    String longitude = '',
  }) {
    final now = DateTime.now();
    return Posko(
      kode: KodeUnik.buat(),
      nama: nama,
      namaDesa: namaDesa,
      alamat: alamat,
      luasLokasi: luasLokasi,
      latitude: latitude,
      longitude: longitude,
      dibuatPada: now,
      diubahPada: now,
    );
  }

  String get label => 'Posko $nama';

  // ---------------- KAPASITAS ----------------

  /// round(luas ÷ 3,5); 0 kalau luas belum diisi.
  static int hitungKapasitas(double? luas) {
    if (luas == null || luas <= 0) return 0;
    return (luas / m2PerOrang).round();
  }

  int get kapasitas => hitungKapasitas(luasLokasi);

  // ---------------- STATUS OPERASIONAL ----------------

  bool get isBeroperasi => statusOperasional == beroperasi;

  String get statusLabel => switch (statusOperasional) {
        beroperasi => 'Beroperasi',
        selesai => 'Selesai',
        _ => 'Siaga',
      };

  /// Hari ke-N operasi = (hari ini − tanggal mulai) + 1, tanggal WIB.
  /// null kalau posko tidak sedang beroperasi.
  int? hariKe([DateTime? sekarang]) {
    final mulai = mulaiBeroperasiAt;
    if (!isBeroperasi || mulai == null) return null;
    DateTime tanggal(DateTime t) {
      final w = WaktuWib.jamDinding(t);
      return DateTime.utc(w.year, w.month, w.day);
    }

    return tanggal(sekarang ?? DateTime.now()).difference(tanggal(mulai)).inDays +
        1;
  }

  /// Aksi yang boleh dilakukan dari status sekarang.
  List<AksiOperasional> get aksiTersedia => switch (statusOperasional) {
        beroperasi => const [AksiOperasional.tutup],
        selesai => const [AksiOperasional.mulai, AksiOperasional.siaga],
        _ => const [AksiOperasional.mulai],
      };

  /// Hasil posko setelah [aksi]. Aturan sama dengan
  /// StatusOperasionalService website (tanpa persetujuan pusat, karena
  /// di aplikasi offline admin lokal yang memutuskan).
  Posko ubahStatus(AksiOperasional aksi, [DateTime? sekarang]) {
    final now = sekarang ?? DateTime.now();
    switch (aksi) {
      case AksiOperasional.mulai:
        if (isBeroperasi) throw const PoskoException('Posko sudah beroperasi.');
        return _salin(
          status: beroperasi,
          mulai: now,
          selesai: null,
          diubah: now,
        );
      case AksiOperasional.tutup:
        if (!isBeroperasi) {
          throw const PoskoException('Posko sedang tidak beroperasi.');
        }
        return _salin(
          status: selesai,
          mulai: mulaiBeroperasiAt,
          selesai: now,
          diubah: now,
        );
      case AksiOperasional.siaga:
        if (statusOperasional != selesai) {
          throw const PoskoException(
              'Hanya posko yang sudah ditutup yang bisa dikembalikan ke siaga.');
        }
        return _salin(status: siaga, mulai: null, selesai: null, diubah: now);
    }
  }

  Posko _salin({
    required String status,
    required DateTime? mulai,
    required DateTime? selesai,
    required DateTime diubah,
  }) {
    return Posko(
      id: id,
      kode: kode,
      nama: nama,
      namaDesa: namaDesa,
      alamat: alamat,
      luasLokasi: luasLokasi,
      latitude: latitude,
      longitude: longitude,
      statusOperasional: status,
      mulaiBeroperasiAt: mulai,
      selesaiBeroperasiAt: selesai,
      dibuatPada: dibuatPada,
      diubahPada: diubah,
    );
  }

  /// Salinan dengan biodata posko baru (status operasional tidak berubah).
  Posko ubahData({
    required String nama,
    required String namaDesa,
    required String alamat,
    required double? luasLokasi,
    required String latitude,
    required String longitude,
  }) {
    return Posko(
      id: id,
      kode: kode,
      nama: nama,
      namaDesa: namaDesa,
      alamat: alamat,
      luasLokasi: luasLokasi,
      latitude: latitude,
      longitude: longitude,
      statusOperasional: statusOperasional,
      mulaiBeroperasiAt: mulaiBeroperasiAt,
      selesaiBeroperasiAt: selesaiBeroperasiAt,
      dibuatPada: dibuatPada,
      diubahPada: DateTime.now(),
    );
  }

  // ---------------- KELENGKAPAN UNTUK PAKET ----------------

  /// Kolom wajib Paket Data Posko yang masih kosong (kosong = lengkap).
  List<String> get dataBelumLengkap => [
        if (namaDesa.trim().isEmpty) 'Nama desa',
        if (alamat.trim().isEmpty) 'Alamat',
        if (kapasitas <= 0) 'Luas lokasi',
        if (latitude.trim().isEmpty) 'Latitude',
        if (longitude.trim().isEmpty) 'Longitude',
      ];

  bool get lengkap => dataBelumLengkap.isEmpty;

  // ---------------- DATABASE ----------------

  Map<String, Object?> toMap() => {
        'id': id,
        'kode': kode,
        'nama': nama,
        'nama_desa': namaDesa,
        'alamat': alamat,
        'luas_lokasi': luasLokasi,
        'kapasitas_pengungsi': kapasitas,
        'latitude': latitude,
        'longitude': longitude,
        'status_operasional': statusOperasional,
        'mulai_beroperasi_at': mulaiBeroperasiAt?.toIso8601String(),
        'selesai_beroperasi_at': selesaiBeroperasiAt?.toIso8601String(),
        'dibuat_pada': dibuatPada.toIso8601String(),
        'diubah_pada': diubahPada.toIso8601String(),
      };

  factory Posko.fromMap(Map<String, Object?> map) {
    final status = asText(map['status_operasional']);
    final dibuat = asDate(map['dibuat_pada']);
    final luas = map['luas_lokasi'];
    return Posko(
      id: asInt(map['id']),
      kode: asText(map['kode']),
      nama: asText(map['nama']),
      namaDesa: asText(map['nama_desa']),
      alamat: asText(map['alamat']),
      luasLokasi: luas is num ? luas.toDouble() : double.tryParse(asText(luas)),
      latitude: asText(map['latitude']),
      longitude: asText(map['longitude']),
      statusOperasional:
          const [beroperasi, selesai].contains(status) ? status : siaga,
      mulaiBeroperasiAt: asDateOrNull(map['mulai_beroperasi_at']),
      selesaiBeroperasiAt: asDateOrNull(map['selesai_beroperasi_at']),
      dibuatPada: dibuat,
      diubahPada: asDateOrNull(map['diubah_pada']) ?? dibuat,
    );
  }
}
