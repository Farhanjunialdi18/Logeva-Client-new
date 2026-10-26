// Tes rumus kebutuhan bantuan & komposisi. Angka harapan dihitung
// dengan rumus website (OperasionalLokasiService.php).

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/models/barang.dart';
import 'package:flutter_application_1/models/catatan_logistik.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/services/kebutuhan_service.dart';
import 'package:flutter_test/flutter_test.dart';

Barang barang(String nama, double? kebutuhan,
        {String satuan = 'kg', String kategori = 'Makanan'}) =>
    Barang(
      id: nama.hashCode,
      kategoriId: 1,
      kategori: kategori,
      namaItem: nama,
      satuan: satuan,
      kebutuhanHarian: kebutuhan,
      dibuatPada: DateTime(2026),
      diubahPada: DateTime(2026),
    );

StokBarang stok(Barang b, int jumlah, {bool pernahMasuk = true}) => StokBarang(
      barang: b,
      jumlah: jumlah,
      terakhirDiperbarui: pernahMasuk ? DateTime(2026) : null,
    );

Pengungsi orang({
  int usia = 30,
  String jk = DataOptions.lakiLaki,
  String kondisi = '',
  String rentan = DataOptions.bukanRentan,
  String riwayat = '',
}) =>
    Pengungsi(
      kode: 'x',
      nama: 'P$usia',
      usia: usia,
      jenisKelamin: jk,
      kondisiKesehatan: kondisi.isEmpty ? 'Sehat' : kondisi,
      kelompokRentan: rentan,
      riwayatPenyakit: riwayat,
      dibuatPada: DateTime(2026),
      diubahPada: DateTime(2026),
    );

void main() {
  final beras = barang('Beras', 0.3);
  final air = barang('Air Mineral', 3, satuan: 'liter', kategori: 'Minuman');
  final selimut = barang('Selimut', null, satuan: 'buah');

  group('hitung per barang', () {
    test('contoh: 100 orang, beras 0,3 kg -> 30 kg/hari', () {
      final k = KebutuhanService.hitung([stok(beras, 45)], 100).single;
      expect(k.kebutuhanHariIni, 30);
      expect(k.cukupHari, 1.5);
      expect(k.status, StatusStok.kuning);
      expect(k.kekurangan, 165); // ceil(30 × 7 − 45)
      expect(k.mendesak, isTrue);
    });

    test('batas status: < 1 merah, < 3 kuning, lainnya hijau', () {
      String status(int jumlah) =>
          KebutuhanService.hitung([stok(beras, jumlah)], 100).single.status;
      expect(status(0), StatusStok.merah);
      expect(status(29), StatusStok.kuning, reason: '0,97 dibulatkan 1,0');
      expect(status(28), StatusStok.merah, reason: '0,93 -> 0,9');
      expect(status(89), StatusStok.hijau, reason: '2,97 -> 3,0');
      expect(status(88), StatusStok.kuning, reason: '2,93 -> 2,9');
    });

    test('barang tanpa kebutuhan harian / tanpa pengungsi = netral', () {
      final s = KebutuhanService.hitung([stok(selimut, 10)], 100).single;
      expect(s.status, StatusStok.netral);
      expect(s.cukupHari, isNull);
      expect(s.kekurangan, isNull);
      final kosong = KebutuhanService.hitung([stok(beras, 10)], 0).single;
      expect(kosong.status, StatusStok.netral);
    });

    test('stok berlebih -> kekurangan 0, tidak perlu dikirim', () {
      final k = KebutuhanService.hitung([stok(beras, 1000)], 100).single;
      expect(k.kekurangan, 0);
      expect(k.perluDikirim, isFalse);
    });

    test('urutan float sama dengan website (ceil tidak meleset)', () {
      // 0,3 × 7 orang × 7 hari = 14,7 -> ceil 15
      expect(KebutuhanService.hitung([stok(beras, 0)], 7).single.kekurangan, 15);
      // 3 liter × 1 orang × 7 = 21 tepat
      expect(KebutuhanService.hitung([stok(air, 0)], 1).single.kekurangan, 21);
    });

    test('urut nama kategori lalu nama barang', () {
      final hasil = KebutuhanService.hitung(
          [stok(beras, 1), stok(air, 1), stok(selimut, 1)], 10);
      expect(hasil.map((k) => k.barang.namaItem),
          ['Beras', 'Selimut', 'Air Mineral']); // Makanan < Minuman
    });
  });

  test('teks hari tanpa desimal (dibulatkan ke bawah)', () {
    expect(KebutuhanService.teksHari(null), '-');
    expect(KebutuhanService.teksHari(0), 'Sudah habis');
    expect(KebutuhanService.teksHari(0.5), 'Habis hari ini');
    expect(KebutuhanService.teksHari(2.7), '2 hari');
    expect(KebutuhanService.teksHari(2.7, kalimat: true), 'Habis dalam 2 hari');
  });

  test('bulat1 meniru round() PHP', () {
    expect(KebutuhanService.bulat1(0.95), 1.0);
    expect(KebutuhanService.bulat1(0.94), 0.9);
    expect(KebutuhanService.bulat1(2.25), 2.3);
    expect(KebutuhanService.bulat1(1 / 3), 0.3);
  });

  group('komposisi', () {
    test('jenis kelamin, kelompok usia, rentan, keterisian', () {
      final k = KebutuhanService.komposisi([
        orang(usia: 0, rentan: 'Bayi'),
        orang(usia: 4),
        orang(usia: 5, jk: DataOptions.perempuan),
        orang(usia: 12),
        orang(usia: 13),
        orang(usia: 17),
        orang(usia: 18, jk: DataOptions.perempuan, rentan: 'Ibu Hamil'),
        orang(usia: 59),
        orang(usia: 60, rentan: 'Lansia'),
      ], 10);
      expect(k.total, 9);
      expect(k.lakiLaki, 7);
      expect(k.perempuan, 2);
      expect(k.usia, {
        KebutuhanService.usiaBalita: 2,
        KebutuhanService.usiaAnak: 2,
        KebutuhanService.usiaRemaja: 2,
        KebutuhanService.usiaDewasa: 2,
        KebutuhanService.usiaLansia: 1,
      });
      expect(k.rentan, {'Bayi': 1, 'Ibu Hamil': 1, 'Lansia': 1});
      expect(k.totalRentan, 3);
      expect(k.persenIsi, 90);
      expect(k.sisaTempat, 1);
    });

    test('keterisian maksimal 100%, kapasitas 0 -> 0%', () {
      final banyak = List.generate(15, (_) => orang());
      expect(KebutuhanService.komposisi(banyak, 10).persenIsi, 100);
      expect(KebutuhanService.komposisi(banyak, 10).sisaTempat, 0);
      expect(KebutuhanService.komposisi(banyak, 0).persenIsi, 0);
    });
  });

  test('perhatian medis: sakit di atas, lalu usia tertua', () {
    final list = KebutuhanService.perhatianMedis([
      orang(usia: 30), // sehat, tidak masuk
      orang(usia: 40, kondisi: 'baik'), // dianggap sehat, tidak masuk
      orang(usia: 70, rentan: 'Lansia'),
      orang(usia: 20, kondisi: 'Demam'),
      orang(usia: 50, riwayat: 'Asma'),
      orang(usia: 45, kondisi: 'Luka ringan'),
    ]);
    expect(list.map((p) => p.usia), [45, 20, 70, 50]);
    expect(KebutuhanService.isSakit(list.first), isTrue);
  });

  test('SPHERE: 15 L air, 3 L minum, 2.100 kkal per orang, 1 toilet / 20',
      () {
    final s = KebutuhanService.sphere(41);
    expect(s.airTotal, 615);
    expect(s.airMinum, 123);
    expect(s.kalori, 86100);
    expect(s.toilet, 3); // ceil(41 / 20)
    expect(KebutuhanService.sphere(0).toilet, 0);
  });

  group('tugas hari ini', () {
    List<TugasHarian> tugas(
      List<StokBarang> s,
      List<Pengungsi> orangList, {
      bool keluar = true,
      int kapasitas = 100,
    }) {
      final k = KebutuhanService.komposisi(orangList, kapasitas);
      return KebutuhanService.tugasHariIni(
        stok: KebutuhanService.hitung(s, orangList.length),
        komposisi: k,
        perhatianMedis: KebutuhanService.perhatianMedis(orangList),
        adaBarangKeluarHariIni: keluar,
      );
    }

    test('belum ada pengungsi -> catat pengungsi', () {
      final t = tugas([], []);
      expect(t.single.teks, 'Catat data pengungsi di posko ini');
      expect(t.single.prioritas, PrioritasTugas.sedang);
    });

    test('urut prioritas tinggi -> sedang -> rutin', () {
      final orangList = [
        ...List.generate(9, (_) => orang()),
        orang(kondisi: 'Demam', rentan: 'Lansia'),
      ];
      final t = tugas(
        [stok(beras, 0, pernahMasuk: false), stok(air, 50), stok(selimut, 3)],
        orangList,
        keluar: false,
        kapasitas: 10,
      );
      expect(t.map((e) => e.teks), [
        'Minta kiriman ±21 kg Beras', // merah
        'Periksa kondisi 1 pengungsi yang sedang sakit',
        'Kapasitas terisi 100%, koordinasikan posko cadangan',
        'Minta kiriman ±160 liter Air Mineral', // kuning (1,7 hari)
        'Cek kebutuhan khusus 1 pengungsi rentan',
        'Catat barang yang dibagikan / dimasak hari ini',
        'Atur kebutuhan harian 1 barang di Master Barang',
      ]);
      expect(t.first.keterangan, 'Barang ini belum pernah ada di posko.');
      expect(t[3].keterangan, 'Habis dalam 1 hari.');
      expect(t.first.prioritas, PrioritasTugas.tinggi);
      expect(t.last.prioritas, PrioritasTugas.rendah);
    });

    test('kondisi aman -> tidak ada tugas', () {
      expect(tugas([stok(beras, 1000)], [orang()]), isEmpty);
    });
  });

  group('status bantuan posko', () {
    final jalan = Posko.baru(nama: 'A', luasLokasi: 350)
        .ubahStatus(AksiOperasional.mulai); // kapasitas 100

    StatusBantuan status(List<StokBarang> s, int pengungsi, {Posko? posko}) {
      final orangList = List.generate(pengungsi, (_) => orang());
      final k = KebutuhanService.komposisi(orangList, 100);
      return KebutuhanService.statusBantuan(
          posko ?? jalan, KebutuhanService.hitung(s, pengungsi), k);
    }

    test('tidak beroperasi -> null', () {
      expect(status([stok(beras, 0)], 10, posko: Posko.baru(nama: 'B')).tingkat,
          isNull);
    });

    test('belum ada pengungsi -> cukup', () {
      expect(status([stok(beras, 0)], 0).tingkat, TingkatBantuan.cukup);
    });

    test('ada barang merah -> segera, dengan alasan', () {
      final b = status([stok(beras, 0, pernahMasuk: false), stok(air, 10)], 10);
      expect(b.tingkat, TingkatBantuan.segera);
      expect(b.alasan, ['Beras belum ada stok', 'Air Mineral: habis hari ini']);
      expect(b.kebutuhan.first.barang.namaItem, 'Beras',
          reason: 'urut dari yang paling cepat habis');
    });

    test('kuning atau keterisian >= 90% -> pantau', () {
      expect(status([stok(beras, 6)], 10).tingkat, TingkatBantuan.pantau);
      final penuh = status([stok(beras, 1000)], 95);
      expect(penuh.tingkat, TingkatBantuan.pantau);
      expect(penuh.alasan, ['Kapasitas terisi 95%']);
    });

    test('semua netral / tidak ada barang -> belum', () {
      expect(status([], 10).tingkat, TingkatBantuan.belum);
      expect(status([stok(selimut, 5)], 10).tingkat, TingkatBantuan.belum);
    });

    test('semua aman -> cukup', () {
      expect(status([stok(beras, 100)], 10).tingkat, TingkatBantuan.cukup);
    });

    test('kebutuhan khusus kelompok rentan ikut', () {
      final k = KebutuhanService.komposisi(
          [orang(rentan: 'Bayi'), orang(rentan: 'Bayi')], 100);
      final b = KebutuhanService.statusBantuan(jalan, [], k);
      expect(b.rentan['Bayi'],
          (2, 'susu formula / MPASI, popok, selimut bayi'));
    });

    test('urutan posko: segera -> pantau -> belum -> cukup, lalu hari', () {
      final list = [
        status([stok(beras, 100)], 10), // cukup
        status([stok(beras, 2)], 10), // segera 0,7 hari
        status([], 10), // belum
        status([stok(beras, 0)], 10), // segera 0 hari
        status([stok(beras, 6)], 10), // pantau
      ]..sort(KebutuhanService.bandingkan);
      expect(list.map((b) => b.tingkat), [
        TingkatBantuan.segera,
        TingkatBantuan.segera,
        TingkatBantuan.pantau,
        TingkatBantuan.belum,
        TingkatBantuan.cukup,
      ]);
      expect(list.first.cukupHariTerkecil, 0);
    });
  });
}
