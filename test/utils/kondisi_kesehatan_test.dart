// Kondisi kesehatan = pilihan + keterangan, satu kolom (sama dengan website).

import 'package:flutter_application_1/core/data_options.dart';
import 'package:flutter_application_1/models/pengungsi.dart';
import 'package:flutter_application_1/services/kebutuhan_service.dart';
import 'package:flutter_application_1/utils/kondisi_kesehatan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('gabung & pisah', () {
    expect(KondisiKesehatan.gabung('Sakit ringan', ' demam  tinggi '),
        'Sakit ringan - demam tinggi');
    expect(KondisiKesehatan.gabung('Sakit berat', ''), 'Sakit berat');

    final p = KondisiKesehatan.pisah('Perlu rujukan - Patah tulang');
    expect(p.pilihan, 'Perlu rujukan');
    expect(p.keterangan, 'Patah tulang');
    expect(KondisiKesehatan.pisah('').pilihan, 'Sehat');
    expect(KondisiKesehatan.pisah('baik').pilihan, 'Sehat');
    expect(KondisiKesehatan.pisah('SAKIT RINGAN: diare').pilihan, 'Sakit ringan');
    expect(KondisiKesehatan.pisah('SAKIT RINGAN: diare').keterangan, 'diare');
  });

  test('teks lama (bukan pilihan) tetap diterima sebagai keterangan', () {
    final p = KondisiKesehatan.pisah('Demam');
    expect(p.pilihan, isNull);
    expect(p.keterangan, 'Demam');
    expect(KondisiKesehatan.rapikan('Demam'), 'Demam');
    expect(KondisiKesehatan.rapikan('sakit berat - sesak'), 'Sakit berat - sesak');
  });

  test('hitungan sakit: semua selain Sehat', () {
    Pengungsi orang(String k) => Pengungsi.baru(poskoId: 1, nama: 'A', asal: 'X',
        usia: 30, jenisKelamin: DataOptions.lakiLaki, kondisiKesehatan: k);
    expect(KebutuhanService.isSakit(orang('')), isFalse);
    expect(KebutuhanService.isSakit(orang('Sehat')), isFalse);
    expect(KebutuhanService.isSakit(orang('Sakit ringan - demam')), isTrue);
    expect(KebutuhanService.isSakit(orang('Perlu rujukan')), isTrue);
    expect(KebutuhanService.isSakit(orang('Demam')), isTrue, reason: 'teks lama');
  });

  test('perhatian medis: paling gawat di atas', () {
    Pengungsi orang(String n, String k, int u) => Pengungsi.baru(poskoId: 1, nama: n,
        asal: 'X', usia: u, jenisKelamin: DataOptions.lakiLaki, kondisiKesehatan: k);
    final urut = KebutuhanService.perhatianMedis([
      orang('Ringan', 'Sakit ringan - batuk', 80),
      orang('Rujuk', 'Perlu rujukan', 20),
      orang('Berat', 'Sakit berat', 30),
    ]).map((p) => p.nama);
    expect(urut, ['Rujuk', 'Berat', 'Ringan']);
  });
}
