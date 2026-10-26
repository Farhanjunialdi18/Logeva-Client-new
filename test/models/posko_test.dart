import 'package:flutter_application_1/models/posko.dart';
import 'package:flutter_application_1/utils/angka.dart';
import 'package:flutter_application_1/utils/kode_unik.dart';
import 'package:flutter_application_1/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('kapasitas = round(luas ÷ 3,5)', () {
    test('contoh website', () {
      expect(Posko.hitungKapasitas(1050), 300);
      expect(Posko.hitungKapasitas(1000), 286); // 285,71 -> 286
      expect(Posko.hitungKapasitas(1.75), 1); // 0,5 dibulatkan ke atas
      expect(Posko.hitungKapasitas(1.7), 0);
    });

    test('luas kosong/0 -> 0', () {
      expect(Posko.hitungKapasitas(null), 0);
      expect(Posko.hitungKapasitas(0), 0);
    });
  });

  group('status operasional', () {
    final baru = Posko.baru(nama: 'Uji');
    final t1 = DateTime.utc(2026, 10, 20, 1);

    test('posko baru: siaga, punya kode unik', () {
      expect(baru.statusOperasional, Posko.siaga);
      expect(KodeUnik.valid(baru.kode), isTrue);
      expect(baru.aksiTersedia, [AksiOperasional.mulai]);
    });

    test('siaga -> beroperasi -> selesai -> siaga', () {
      final jalan = baru.ubahStatus(AksiOperasional.mulai, t1);
      expect(jalan.statusOperasional, Posko.beroperasi);
      expect(jalan.mulaiBeroperasiAt, t1);
      expect(jalan.kode, baru.kode, reason: 'kode tidak pernah berubah');

      final t2 = t1.add(const Duration(days: 3));
      final tutup = jalan.ubahStatus(AksiOperasional.tutup, t2);
      expect(tutup.statusOperasional, Posko.selesai);
      expect(tutup.mulaiBeroperasiAt, t1);
      expect(tutup.selesaiBeroperasiAt, t2);

      final siaga = tutup.ubahStatus(AksiOperasional.siaga, t2);
      expect(siaga.statusOperasional, Posko.siaga);
      expect(siaga.mulaiBeroperasiAt, isNull);
      expect(siaga.selesaiBeroperasiAt, isNull);
    });

    test('selesai -> mulai lagi mengosongkan tanggal selesai', () {
      final selesai = baru
          .ubahStatus(AksiOperasional.mulai, t1)
          .ubahStatus(AksiOperasional.tutup, t1);
      final lagi = selesai.ubahStatus(AksiOperasional.mulai, t1);
      expect(lagi.isBeroperasi, isTrue);
      expect(lagi.selesaiBeroperasiAt, isNull);
    });

    test('aksi yang tidak boleh ditolak dengan pesan website', () {
      final jalan = baru.ubahStatus(AksiOperasional.mulai, t1);
      expect(
        () => jalan.ubahStatus(AksiOperasional.mulai),
        throwsA(isA<PoskoException>()
            .having((e) => e.message, 'pesan', 'Posko sudah beroperasi.')),
      );
      expect(() => baru.ubahStatus(AksiOperasional.tutup),
          throwsA(isA<PoskoException>()));
      expect(() => baru.ubahStatus(AksiOperasional.siaga),
          throwsA(isA<PoskoException>()));
    });

    test('hari ke-N memakai tanggal WIB', () {
      // Mulai 20 Okt 23:30 WIB (16:30 UTC).
      final jalan = baru.ubahStatus(
          AksiOperasional.mulai, DateTime.utc(2026, 10, 20, 16, 30));
      // 21 Okt 00:30 WIB sudah hari ke-2 walau baru 1 jam berlalu.
      expect(jalan.hariKe(DateTime.utc(2026, 10, 20, 17, 30)), 2);
      expect(jalan.hariKe(DateTime.utc(2026, 10, 20, 16, 40)), 1);
      expect(baru.hariKe(), isNull);
    });
  });

  test('dataBelumLengkap menyebut kolom wajib paket', () {
    expect(Posko.baru(nama: 'X').dataBelumLengkap,
        ['Nama desa', 'Alamat', 'Luas lokasi', 'Latitude', 'Longitude']);
    final lengkap = Posko.baru(
      nama: 'X',
      namaDesa: 'Desa',
      alamat: 'Jl',
      luasLokasi: 100,
      latitude: '-6.9',
      longitude: '106.1',
    );
    expect(lengkap.lengkap, isTrue);
  });

  test('toMap -> fromMap tidak mengubah data', () {
    final asli = Posko.baru(
      nama: 'X',
      namaDesa: 'Desa',
      alamat: 'Jl',
      luasLokasi: 12.5,
      latitude: '-6.9',
      longitude: '106.1',
    ).ubahStatus(AksiOperasional.mulai);
    final hasil = Posko.fromMap(asli.toMap()..['id'] = 7);
    expect(hasil.id, 7);
    expect(hasil.kode, asli.kode);
    expect(hasil.luasLokasi, 12.5);
    expect(hasil.kapasitas, 4);
    expect(hasil.statusOperasional, Posko.beroperasi);
    expect(hasil.mulaiBeroperasiAt, asli.mulaiBeroperasiAt);
  });

  group('angka format Indonesia (sama dengan NilaiImport website)', () {
    test('baca', () {
      expect(Angka.baca('1.250'), 1250);
      expect(Angka.baca('1.250,5'), 1250.5);
      expect(Angka.baca('2,5'), 2.5);
      expect(Angka.baca('12.5'), 12.5);
      expect(Angka.baca(' 1050 '), 1050);
      expect(Angka.baca(''), isNull);
      expect(Angka.baca('abc'), isNull);
    });

    test('koordinat: koma = desimal', () {
      expect(Angka.bacaKoordinat('-6,9195'), -6.9195);
      expect(Angka.bacaKoordinat('106.1297'), 106.1297);
    });

    test('tampil & ekspor', () {
      expect(Angka.tampil(1050), '1050');
      expect(Angka.tampil(12.5), '12,5');
      expect(Angka.ekspor(12.5), '12.5');
      expect(Angka.ekspor(0.3), '0.3');
    });
  });

  group('validator posko', () {
    test('luas', () {
      expect(Validators.luasLokasi(''), isNotNull);
      expect(Validators.luasLokasi('abc'), isNotNull);
      expect(Validators.luasLokasi('1'), isNotNull); // kapasitas 0
      expect(Validators.luasLokasi('1.050'), isNull);
    });

    test('koordinat boleh kosong, tapi harus di wilayah Indonesia', () {
      expect(Validators.latitude(''), isNull);
      expect(Validators.latitude('-6,9195'), isNull);
      expect(Validators.latitude('106.1'), isNotNull); // tertukar
      expect(Validators.longitude('106.1297'), isNull);
      expect(Validators.longitude('-6.9'), isNotNull);
    });
  });
}
