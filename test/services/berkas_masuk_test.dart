// "Buka dengan LOGEVA": jenis file terkunci dikenali dari namanya
// (isinya baru terbaca setelah kata sandi diketik).

import 'package:archive/archive.dart';
import 'package:flutter_application_1/services/berkas_masuk_service.dart';
import 'package:flutter_application_1/utils/berkas_terkunci.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final zip = ZipEncoder().encode(Archive()..addFile(ArchiveFile.string('a.txt', 'x')));
  final terkunci = BerkasTerkunci.kunci(zip, 'SandiPosko2026', iterasi: 1000);

  test('file terkunci dikenali dari nama', () {
    JenisBerkas k(String n) => BerkasMasukService.kenali(n, terkunci);
    expect(k('LOGEVA_cadangan_20261116-1630.zip'), JenisBerkas.cadangan);
    expect(k('cadangan_logeva_20261020-0800.zip'), JenisBerkas.cadangan);
    expect(k('LOGEVA_paket_pusat_balai_desa_20261116-1630.zip'), JenisBerkas.paketWebsite);
    expect(k('LOGEVA_paket_BalaiDesa_20261116-1630.zip'), JenisBerkas.paketAplikasi);
    expect(k('DOC-20261116-WA0003.zip'), JenisBerkas.terkunciLain);
  });

  test('zip biasa yang bukan file LOGEVA ditolak', () {
    expect(BerkasMasukService.kenali('foto.zip', zip), JenisBerkas.tidakDikenal);
  });

  test('file menunggu hanya diambil oleh halaman yang jenisnya cocok', () {
    BerkasMasukService.simpan('x.zip', terkunci, JenisBerkas.cadangan);
    expect(BerkasMasukService.ambil(JenisBerkas.sinkron), isNull);
    expect(BerkasMasukService.ambil(JenisBerkas.cadangan)?.name, 'x.zip');
    expect(BerkasMasukService.ambil(JenisBerkas.cadangan), isNull); // sekali pakai
  });
}
