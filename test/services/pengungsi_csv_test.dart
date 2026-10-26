import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/services/csv_service.dart';
import 'package:flutter_application_1/services/pengungsi_csv.dart';
import 'package:flutter_application_1/utils/tanggal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final hariIni = DateTime(2026, 10, 23);

  /// Satu baris CSV dengan judul kolom template website.
  BarisPengungsi baca(Map<String, String> isi) {
    final semua = {
      'Nama': 'Siti Aminah',
      'Asal': 'Desa Cikaret',
      'Tanggal Lahir': '1958-03-12',
      'Nomor KK': '3602011203580001',
      'Usia': '68',
      'Jenis Kelamin': 'Perempuan',
      'Kondisi Kesehatan': 'Sehat',
      'Kelompok Rentan': 'Lansia',
      'Riwayat Penyakit': 'Hipertensi',
      ...isi,
    };
    final csv = CsvService.encode(semua.keys.toList(), [semua.values.toList()]);
    return PengungsiCsv.baca(CsvService.decode(csv).single, hariIni: hariIni);
  }

  test('contoh template website terbaca valid', () {
    final b = baca({});
    expect(b.error, isEmpty);
    expect(b.nama, 'Siti Aminah');
    expect(b.tanggalLahir, DateTime(1958, 3, 12));
    expect(b.jenisKelamin, DataOptions.perempuan);
    expect(b.kelompokRentan, 'Lansia');
    expect(b.nomorKk, '3602011203580001');
  });

  test('nomor KK boleh kosong (keputusan pemilik proyek)', () {
    final b = baca({'Nomor KK': ''});
    expect(b.error, isEmpty);
    expect(b.nomorKk, isNull);
  });

  test('nomor KK salah / rusak oleh Excel ditolak', () {
    expect(baca({'Nomor KK': '12345'}).error.single, contains('16 digit'));
    expect(baca({'Nomor KK': '3.60201E+15'}).error.single, contains('Excel'));
    expect(baca({'Nomor KK': '3602-0112-0358-0001'}).nomorKk,
        '3602011203580001');
  });

  test('tanggal lahir wajib & harus masuk akal', () {
    expect(baca({'Tanggal Lahir': ''}).error, contains('Tanggal lahir kosong'));
    expect(baca({'Tanggal Lahir': '12 Maret 1958'}).error.single,
        contains('tidak dikenali'));
    expect(baca({'Tanggal Lahir': '2027-01-01', 'Usia': ''}).error.single,
        contains('tidak masuk akal'));
    expect(baca({'Tanggal Lahir': '12/03/1958'}).tanggalLahir,
        DateTime(1958, 3, 12));
    expect(baca({'Tanggal Lahir': '31-02-2000', 'Usia': ''}).error,
        isNotEmpty, reason: 'tanggal tidak ada di kalender');
  });

  test('usia boleh kosong, kalau diisi harus sesuai (±1 tahun)', () {
    expect(baca({'Usia': ''}).error, isEmpty);
    expect(baca({'Usia': '67'}).error, isEmpty);
    expect(baca({'Usia': '60'}).error.single,
        'Usia (60) tidak sesuai tanggal lahir (seharusnya 68 tahun)');
  });

  test('jenis kelamin & kelompok rentan memakai pilihan website', () {
    expect(baca({'Jenis Kelamin': 'L'}).jenisKelamin, DataOptions.lakiLaki);
    expect(baca({'Jenis Kelamin': 'wanita'}).jenisKelamin,
        DataOptions.perempuan);
    expect(baca({'Jenis Kelamin': 'X'}).error.single, contains('tidak dikenali'));
    expect(baca({'Kelompok Rentan': 'ibu hamil'}).kelompokRentan, 'Ibu Hamil');
    expect(baca({'Kelompok Rentan': '-'}).kelompokRentan, 'Tidak');
    expect(baca({'Kelompok Rentan': ''}).kelompokRentan, isNull);
    expect(baca({'Kelompok Rentan': 'Anak'}).error.single,
        contains('tidak dikenali'));
  });

  test('file format aplikasi lama (kolom domisili) tetap terbaca', () {
    final b = PengungsiCsv.baca(
      {
        'nama': 'Budi',
        'domisili': 'Desa X',
        'tanggal_lahir': '1990-07-25',
        'jenis_kelamin': 'L',
      },
      hariIni: hariIni,
    );
    expect(b.error, isEmpty);
    expect(b.asal, 'Desa X');
  });

  test('ekspor -> impor menghasilkan data yang sama', () {
    final asli = Pengungsi.baru(
      poskoId: 1,
      nama: 'Mak Iyah, "Uti"',
      asal: 'Desa Cikaret',
      tanggalLahir: DateTime(1952, 1, 5),
      jenisKelamin: DataOptions.perempuan,
      kondisiKesehatan: 'Demam',
      kelompokRentan: 'Lansia',
      riwayatPenyakit: 'Hipertensi',
    );
    final csv = CsvService.encode(PengungsiCsv.headers, [PengungsiCsv.toRow(asli)]);
    expect(csv.split('\r\n').first,
        'Nama,Asal,Tanggal Lahir,Nomor KK,Usia,Jenis Kelamin,'
        'Kondisi Kesehatan,Kelompok Rentan,Riwayat Penyakit');

    final b = PengungsiCsv.baca(CsvService.decode(csv).single);
    expect(b.error, isEmpty);
    final hasil = b.keBaru(1, '');
    expect(hasil.nama, asli.nama);
    expect(hasil.tanggalLahir, asli.tanggalLahir);
    expect(hasil.kondisiKesehatan, 'Demam');
    expect(hasil.kelompokRentan, 'Lansia');
    expect(hasil.nomorKk, '');
  });

  test('memperbarui: kolom opsional kosong tidak menghapus data lama', () {
    final lama = Pengungsi.baru(
      poskoId: 1,
      nama: 'Siti Aminah',
      asal: 'Lama',
      tanggalLahir: DateTime(1958, 3, 12),
      jenisKelamin: DataOptions.perempuan,
      nomorKk: '3602011203580001',
      riwayatPenyakit: 'Asma',
    );
    final b = baca({
      'Asal': 'Baru',
      'Nomor KK': '',
      'Riwayat Penyakit': '',
      'Kelompok Rentan': '',
    });
    final hasil = b.perbarui(lama);
    expect(hasil.kode, lama.kode);
    expect(hasil.asal, 'Baru');
    expect(hasil.nomorKk, '3602011203580001');
    expect(hasil.riwayatPenyakit, 'Asma');
  });

  group('Tanggal', () {
    test('usia = tahun penuh', () {
      final lahir = DateTime(1990, 7, 25);
      expect(Tanggal.usia(lahir, DateTime(2026, 7, 24)), 35);
      expect(Tanggal.usia(lahir, DateTime(2026, 7, 25)), 36);
    });

    test('format & tampil', () {
      expect(Tanggal.format(DateTime(1990, 7, 5)), '1990-07-05');
      expect(Tanggal.tampil(DateTime(1990, 7, 5)), '05-07-1990');
      expect(Tanggal.baca('1990-07-05 00:00:00'), DateTime(1990, 7, 5));
      expect(Tanggal.baca('1990-7-5'), isNull, reason: 'harus 2 digit');
    });
  });
}
