// ============================================================
// kebutuhan_service.dart
// RUMUS KEBUTUHAN BANTUAN & KOMPOSISI PENGUNGSI, disalin dari website
// (app/Services/OperasionalLokasiService.php) supaya hasilnya IDENTIK:
//
//   kebutuhan_per_hari = kebutuhan_harian × jumlah_pengungsi
//   cukup_hari         = round(stok ÷ kebutuhan_per_hari, 1)   (null jika 0)
//   status             = null -> netral, < 1 -> merah, < 3 -> kuning, lainnya hijau
//   kekurangan         = max(0, ceil(kebutuhan_per_hari × 7 − stok))
//
// Catatan: status & teks hari memakai cukup_hari yang SUDAH dibulatkan
// 1 desimal, sama dengan website. Urutan operasi float juga sama,
// supaya hasil ceil() tidak berbeda.
// File ini tidak membaca database: semua masukan diberikan pemanggil.
// ============================================================

import 'dart:math';

import '../core/data_options.dart';
import '../models/barang.dart';
import '../models/catatan_logistik.dart';
import '../models/pengungsi.dart';
import '../models/posko.dart';

// ---------------- STATUS STOK ----------------

class StatusStok {
  StatusStok._();

  static const String merah = 'merah'; // Kritis
  static const String kuning = 'kuning'; // Menipis
  static const String hijau = 'hijau'; // Aman
  static const String netral = 'netral'; // Belum dihitung

  static String label(String status) => switch (status) {
        merah => 'Kritis',
        kuning => 'Menipis',
        hijau => 'Aman',
        _ => 'Belum dihitung',
      };
}

/// Hasil hitung satu barang di satu posko.
class KebutuhanBarang {
  final Barang barang;
  final int jumlahStok;
  final bool belumPernahMasuk;
  final double kebutuhanHariIni; // dibulatkan 1 desimal
  final double? cukupHari; // dibulatkan 1 desimal, null = tidak dihitung
  final String status;
  final int? kekurangan; // jumlah yang perlu dikirim untuk 7 hari

  const KebutuhanBarang({
    required this.barang,
    required this.jumlahStok,
    required this.belumPernahMasuk,
    required this.kebutuhanHariIni,
    required this.cukupHari,
    required this.status,
    required this.kekurangan,
  });

  bool get perluDikirim => (kekurangan ?? 0) > 0;
  bool get mendesak =>
      status == StatusStok.merah || status == StatusStok.kuning;
}

// ---------------- STATUS BANTUAN POSKO ----------------

class TingkatBantuan {
  TingkatBantuan._();

  static const String segera = 'segera';
  static const String pantau = 'pantau';
  static const String belum = 'belum';
  static const String cukup = 'cukup';

  /// Urutan daftar "Posko Butuh Bantuan" (paling mendesak dulu).
  static const List<String> urutan = [segera, pantau, belum, cukup];

  static String label(String? tingkat) => switch (tingkat) {
        segera => 'Butuh bantuan segera',
        pantau => 'Perlu dipantau',
        belum => 'Belum bisa dihitung',
        cukup => 'Tercukupi',
        _ => 'Tidak beroperasi',
      };

  static String kalimat(String? tingkat) => switch (tingkat) {
        segera => 'Posko ini butuh bantuan segera',
        pantau => 'Posko ini perlu dipantau',
        belum => 'Kebutuhan belum bisa dihitung',
        cukup => 'Kebutuhan posko saat ini tercukupi',
        _ => 'Posko tidak sedang beroperasi',
      };
}

class StatusBantuan {
  /// null = posko tidak sedang beroperasi.
  final String? tingkat;
  final List<String> alasan;

  /// Barang yang perlu dikirim, urut dari yang paling cepat habis.
  final List<KebutuhanBarang> kebutuhan;
  final List<KebutuhanBarang> stok;

  /// Kelompok rentan yang ada di posko -> (jumlah, kebutuhan khusus).
  final Map<String, (int, String)> rentan;
  final int jumlahPengungsi;
  final int persenIsi;

  const StatusBantuan({
    required this.tingkat,
    required this.alasan,
    required this.kebutuhan,
    required this.stok,
    required this.rentan,
    required this.jumlahPengungsi,
    required this.persenIsi,
  });

  /// Hari terkecil di daftar kebutuhan (untuk mengurutkan posko).
  double? get cukupHariTerkecil {
    double? min;
    for (final k in kebutuhan) {
      final h = k.cukupHari;
      if (h != null && (min == null || h < min)) min = h;
    }
    return min;
  }
}

// ---------------- KOMPOSISI PENGUNGSI ----------------

class KomposisiPengungsi {
  final int total;
  final int kapasitas;
  final int lakiLaki;
  final int perempuan;
  final Map<String, int> usia; // kelompok usia -> jumlah
  final Map<String, int> rentan; // kelompok rentan (selain "Tidak") -> jumlah

  const KomposisiPengungsi({
    required this.total,
    required this.kapasitas,
    required this.lakiLaki,
    required this.perempuan,
    required this.usia,
    required this.rentan,
  });

  /// Keterisian (%) = min(100, round(total ÷ kapasitas × 100)).
  int get persenIsi =>
      kapasitas > 0 ? (total / kapasitas * 100).round().clamp(0, 100) : 0;

  int get sisaTempat => (kapasitas - total) < 0 ? 0 : kapasitas - total;

  int get totalRentan => rentan.values.fold(0, (a, b) => a + b);
}

// ---------------- TUGAS HARI INI & SPHERE ----------------

class PrioritasTugas {
  PrioritasTugas._();

  static const String tinggi = 'tinggi';
  static const String sedang = 'sedang';
  static const String rendah = 'rendah';

  static const List<String> urutan = [tinggi, sedang, rendah];

  static String label(String prioritas) => switch (prioritas) {
        tinggi => 'Prioritas tinggi',
        sedang => 'Sedang',
        _ => 'Rutin',
      };
}

/// Satu tugas relawan hari ini (OperasionalLokasiService::tugasHariIni).
class TugasHarian {
  final String prioritas;

  /// Jenis tugas, untuk ikon: pengungsi, logistik, medis, kapasitas,
  /// rentan, keluar, master.
  final String jenis;
  final String teks;
  final String keterangan;

  const TugasHarian({
    required this.prioritas,
    required this.jenis,
    required this.teks,
    required this.keterangan,
  });
}

/// Kebutuhan harian aktual menurut standar minimum SPHERE, dihitung dari
/// jumlah pengungsi yang tercatat (bukan dari kapasitas).
class KebutuhanSphere {
  final int airTotal; // liter
  final int airMinum; // liter
  final int kalori; // kkal
  final int toilet; // unit

  const KebutuhanSphere({
    required this.airTotal,
    required this.airMinum,
    required this.kalori,
    required this.toilet,
  });
}

// ============================================================

class KebutuhanService {
  KebutuhanService._();

  static const int batasMerah = 1; // < 1 hari -> kritis
  static const int batasKuning = 3; // < 3 hari -> menipis
  static const int batasPenuhPersen = 90;

  /// Stok dihitung cukup untuk sekian hari (TARGET_HARI_BANTUAN website).
  static const int targetHari = 7;

  /// Kebutuhan khusus per kelompok rentan (teks sama dengan website).
  static const Map<String, String> kebutuhanRentan = {
    'Bayi': 'susu formula / MPASI, popok, selimut bayi',
    'Ibu Hamil': 'makanan bergizi, vitamin, pemeriksaan kehamilan',
    'Lansia': 'obat-obatan rutin, alas tidur yang layak, makanan lunak',
    'Disabilitas': 'alat bantu (kursi roda, tongkat), akses toilet yang mudah',
    'Sakit': 'obat-obatan, tenaga kesehatan',
  };

  /// round() PHP ke 1 desimal (setengah dibulatkan menjauhi nol).
  /// Toleransi kecil meniru "pre-rounding" PHP, misal 0,95 -> 1,0.
  static double bulat1(double nilai) {
    final x = nilai * 10;
    final arah = x < 0 ? -1e-9 : 1e-9;
    return (x + arah).round() / 10;
  }

  /// Daya tahan stok tanpa desimal (sama dengan website):
  ///   0 -> "Sudah habis", < 1 -> "Habis hari ini", lainnya "2 hari"
  ///   (dibulatkan ke bawah). [kalimat] -> "Habis dalam 2 hari".
  static String teksHari(double? hari, {bool kalimat = false}) {
    if (hari == null) return '-';
    if (hari <= 0) return 'Sudah habis';
    if (hari < 1) return 'Habis hari ini';
    return '${kalimat ? 'Habis dalam ' : ''}${hari.floor()} hari';
  }

  // ---------------- STOK & KEBUTUHAN ----------------

  /// [stok] = hasil LogistikRepository.getStok(termasukPokok: true).
  static List<KebutuhanBarang> hitung(
      List<StokBarang> stok, int jumlahPengungsi) {
    final hasil = stok.map((s) {
      final perHari = (s.barang.kebutuhanHarian ?? 0) * jumlahPengungsi;
      final cukup = perHari > 0 ? bulat1(s.jumlah / perHari) : null;
      final status = cukup == null
          ? StatusStok.netral
          : cukup < batasMerah
              ? StatusStok.merah
              : cukup < batasKuning
                  ? StatusStok.kuning
                  : StatusStok.hijau;
      final kurang =
          perHari > 0 ? max(0, (perHari * targetHari - s.jumlah).ceil()) : null;
      return KebutuhanBarang(
        barang: s.barang,
        jumlahStok: s.jumlah,
        belumPernahMasuk: s.terakhirDiperbarui == null,
        kebutuhanHariIni: bulat1(perHari),
        cukupHari: cukup,
        status: status,
        kekurangan: kurang,
      );
    }).toList();

    // Urut nama kategori lalu nama barang (sama dengan website).
    hasil.sort((a, b) {
      final k = a.barang.kategori.compareTo(b.barang.kategori);
      return k != 0 ? k : a.barang.namaItem.compareTo(b.barang.namaItem);
    });
    return hasil;
  }

  // ---------------- KOMPOSISI ----------------

  static const String usiaBalita = 'Balita (0-4)';
  static const String usiaAnak = 'Anak (5-12)';
  static const String usiaRemaja = 'Remaja (13-17)';
  static const String usiaDewasa = 'Dewasa (18-59)';
  static const String usiaLansia = 'Lansia (60+)';

  static String kelompokUsia(int usia) {
    if (usia < 5) return usiaBalita;
    if (usia <= 12) return usiaAnak;
    if (usia <= 17) return usiaRemaja;
    if (usia <= 59) return usiaDewasa;
    return usiaLansia;
  }

  static KomposisiPengungsi komposisi(
      List<Pengungsi> pengungsi, int kapasitas) {
    final usia = {
      for (final k in [
        usiaBalita, usiaAnak, usiaRemaja, usiaDewasa, usiaLansia,
      ])
        k: 0,
    };
    final rentan = <String, int>{};
    var laki = 0, perempuan = 0;
    for (final p in pengungsi) {
      if (p.jenisKelamin == DataOptions.lakiLaki) laki++;
      if (p.jenisKelamin == DataOptions.perempuan) perempuan++;
      usia[kelompokUsia(p.usia)] = usia[kelompokUsia(p.usia)]! + 1;
      if (p.isRentan) rentan[p.kelompokRentan] = (rentan[p.kelompokRentan] ?? 0) + 1;
    }
    return KomposisiPengungsi(
      total: pengungsi.length,
      kapasitas: kapasitas,
      lakiLaki: laki,
      perempuan: perempuan,
      usia: usia,
      rentan: rentan,
    );
  }

  // ---------------- PERHATIAN MEDIS ----------------

  /// Sakit = kondisi kesehatan selain kosong, "-", "sehat", "baik".
  static bool isSakit(Pengungsi p) => !const ['', '-', 'sehat', 'baik']
      .contains(p.kondisiKesehatan.trim().toLowerCase());

  /// Pengungsi yang sakit, punya riwayat penyakit, atau kelompok rentan.
  /// Yang sakit di atas, lalu usia tertua.
  static List<Pengungsi> perhatianMedis(List<Pengungsi> pengungsi) {
    final list = pengungsi
        .where((p) =>
            isSakit(p) || p.riwayatPenyakit.trim().isNotEmpty || p.isRentan)
        .toList();
    list.sort((a, b) {
      final s = (isSakit(b) ? 1 : 0) - (isSakit(a) ? 1 : 0);
      return s != 0 ? s : b.usia.compareTo(a.usia);
    });
    return list;
  }

  // ---------------- STATUS BANTUAN ----------------

  static StatusBantuan statusBantuan(
    Posko posko,
    List<KebutuhanBarang> stok,
    KomposisiPengungsi komposisi,
  ) {
    final kebutuhan = stok.where((s) => s.perluDikirim).toList()
      ..sort((a, b) => (a.cukupHari ?? 0).compareTo(b.cukupHari ?? 0));

    final alasan = <String>[
      for (final s in stok.where((s) => s.mendesak))
        s.belumPernahMasuk
            ? '${s.barang.namaItem} belum ada stok'
            : '${s.barang.namaItem}: ${_hurufKecilAwal(teksHari(s.cukupHari, kalimat: true))}',
      if (komposisi.persenIsi >= batasPenuhPersen)
        'Kapasitas terisi ${komposisi.persenIsi}%',
    ];

    final String? tingkat;
    if (!posko.isBeroperasi) {
      tingkat = null;
    } else if (komposisi.total == 0) {
      tingkat = TingkatBantuan.cukup;
    } else if (stok.any((s) => s.status == StatusStok.merah)) {
      tingkat = TingkatBantuan.segera;
    } else if (stok.any((s) => s.status == StatusStok.kuning) ||
        komposisi.persenIsi >= batasPenuhPersen) {
      tingkat = TingkatBantuan.pantau;
    } else if (stok.isEmpty ||
        stok.every((s) => s.status == StatusStok.netral)) {
      tingkat = TingkatBantuan.belum;
    } else {
      tingkat = TingkatBantuan.cukup;
    }

    return StatusBantuan(
      tingkat: tingkat,
      alasan: alasan,
      kebutuhan: kebutuhan,
      stok: stok,
      rentan: {
        for (final e in komposisi.rentan.entries)
          if (kebutuhanRentan.containsKey(e.key))
            e.key: (e.value, kebutuhanRentan[e.key]!),
      },
      jumlahPengungsi: komposisi.total,
      persenIsi: komposisi.persenIsi,
    );
  }

  // ---------------- SPHERE ----------------

  static const int sphereAirLiter = 15; // air minum + masak + kebersihan
  static const int sphereAirMinum = 3;
  static const int sphereKalori = 2100;
  static const int sphereOrangPerToilet = 20;

  static KebutuhanSphere sphere(int jumlahPengungsi) => KebutuhanSphere(
        airTotal: jumlahPengungsi * sphereAirLiter,
        airMinum: jumlahPengungsi * sphereAirMinum,
        kalori: jumlahPengungsi * sphereKalori,
        toilet: (jumlahPengungsi / sphereOrangPerToilet).ceil(),
      );

  // ---------------- TUGAS HARI INI ----------------

  /// Daftar tugas relawan, disusun dari data yang sudah ada (sama dengan
  /// website). Urut prioritas tinggi -> sedang -> rutin; urutan di dalam
  /// prioritas yang sama dipertahankan.
  static List<TugasHarian> tugasHariIni({
    required List<KebutuhanBarang> stok,
    required KomposisiPengungsi komposisi,
    required List<Pengungsi> perhatianMedis,
    required bool adaBarangKeluarHariIni,
  }) {
    final tugas = <TugasHarian>[];

    if (komposisi.total == 0) {
      tugas.add(const TugasHarian(
        prioritas: PrioritasTugas.sedang,
        jenis: 'pengungsi',
        teks: 'Catat data pengungsi di posko ini',
        keterangan: 'Kebutuhan logistik dihitung dari jumlah pengungsi, '
            'jadi belum bisa dihitung.',
      ));
    }

    // Barang yang hampir / sudah habis, paling cepat habis dulu.
    final mendesak = stok.where((s) => s.mendesak).toList()
      ..sort((a, b) => (a.cukupHari ?? 0).compareTo(b.cukupHari ?? 0));
    for (final s in mendesak) {
      tugas.add(TugasHarian(
        prioritas: s.status == StatusStok.merah
            ? PrioritasTugas.tinggi
            : PrioritasTugas.sedang,
        jenis: 'logistik',
        teks: 'Minta kiriman ±${s.kekurangan} ${s.barang.satuan} '
            '${s.barang.namaItem}',
        keterangan: s.belumPernahMasuk
            ? 'Barang ini belum pernah ada di posko.'
            : '${teksHari(s.cukupHari, kalimat: true)}.',
      ));
    }

    // Khusus aplikasi (beberapa HP satu posko): stok minus setelah data
    // digabung = ada barang keluar yang barang masuknya belum tercatat.
    final minus = stok.where((s) => s.jumlahStok < 0).toList();
    if (minus.isNotEmpty) {
      tugas.add(TugasHarian(
        prioritas: PrioritasTugas.tinggi,
        jenis: 'logistik',
        teks: 'Periksa stok minus ${minus.length} barang',
        keterangan: '${minus.map(teksStokMinus).join(', ')}. Pastikan semua HP '
            'sudah sinkron, lalu catat koreksi bila perlu.',
      ));
    }

    final sakit = perhatianMedis.where(isSakit).length;
    if (sakit > 0) {
      tugas.add(TugasHarian(
        prioritas: PrioritasTugas.tinggi,
        jenis: 'medis',
        teks: 'Periksa kondisi $sakit pengungsi yang sedang sakit',
        keterangan:
            'Pastikan sudah ditangani tenaga kesehatan dan obatnya tersedia.',
      ));
    }

    if (komposisi.persenIsi >= batasPenuhPersen) {
      tugas.add(TugasHarian(
        prioritas: PrioritasTugas.tinggi,
        jenis: 'kapasitas',
        teks: 'Kapasitas terisi ${komposisi.persenIsi}%, koordinasikan '
            'posko cadangan',
        keterangan: 'Sisa tempat ${komposisi.sisaTempat} orang.',
      ));
    }

    final rentanKhusus = {
      for (final k in DataOptions.kelompokRentan)
        if (k != 'Sakit' && (komposisi.rentan[k] ?? 0) > 0)
          k: komposisi.rentan[k]!,
    };
    if (rentanKhusus.isNotEmpty) {
      final total = rentanKhusus.values.fold(0, (a, b) => a + b);
      tugas.add(TugasHarian(
        prioritas: PrioritasTugas.sedang,
        jenis: 'rentan',
        teks: 'Cek kebutuhan khusus $total pengungsi rentan',
        keterangan:
            '${rentanKhusus.entries.map((e) => '${e.key} ${e.value}').join(', ')}.',
      ));
    }

    if (komposisi.total > 0 && !adaBarangKeluarHariIni) {
      tugas.add(const TugasHarian(
        prioritas: PrioritasTugas.rendah,
        jenis: 'keluar',
        teks: 'Catat barang yang dibagikan / dimasak hari ini',
        keterangan: 'Belum ada catatan barang keluar hari ini, sisa stok bisa '
            'jadi tidak akurat.',
      ));
    }

    final tanpaKebutuhan =
        stok.where((s) => s.barang.kebutuhanHarian == null).toList();
    if (tanpaKebutuhan.isNotEmpty) {
      tugas.add(TugasHarian(
        prioritas: PrioritasTugas.rendah,
        jenis: 'master',
        teks: 'Atur kebutuhan harian ${tanpaKebutuhan.length} barang di '
            'Master Barang',
        keterangan:
            '${tanpaKebutuhan.take(4).map((s) => s.barang.namaItem).join(', ')}.',
      ));
    }

    // Urut prioritas, stabil (urutan asli dipertahankan bila sama).
    final berindeks = tugas.indexed.toList()
      ..sort((a, b) {
        final p = PrioritasTugas.urutan
            .indexOf(a.$2.prioritas)
            .compareTo(PrioritasTugas.urutan.indexOf(b.$2.prioritas));
        return p != 0 ? p : a.$1.compareTo(b.$1);
      });
    return berindeks.map((e) => e.$2).toList();
  }

  /// Contoh: "Beras −5 kg".
  static String teksStokMinus(KebutuhanBarang s) =>
      '${s.barang.namaItem} −${-s.jumlahStok} ${s.barang.satuan}';

  static String _hurufKecilAwal(String s) =>
      s.isEmpty ? s : s[0].toLowerCase() + s.substring(1);

  /// Urutan daftar "Posko Butuh Bantuan": segera -> pantau -> belum ->
  /// cukup, lalu hari tercepat habis.
  static int bandingkan(StatusBantuan a, StatusBantuan b) {
    int urut(String? t) {
      final i = TingkatBantuan.urutan.indexOf(t ?? '');
      return i < 0 ? 9 : i;
    }

    final t = urut(a.tingkat).compareTo(urut(b.tingkat));
    if (t != 0) return t;
    return (a.cukupHariTerkecil ?? 999999)
        .compareTo(b.cukupHariTerkecil ?? 999999);
  }
}
