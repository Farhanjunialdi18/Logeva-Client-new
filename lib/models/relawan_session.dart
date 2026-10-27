// ============================================================
// relawan_session.dart
// Data relawan yang sedang login (nama & posko tugas).
// ============================================================

class RelawanSession {
  final String nama;
  final int? poskoId; // null hanya untuk PIN demo
  final String posko; // contoh: 'Desa Panggarangan'
  final String kontak; // nomor HP / email relawan
  final int? relawanId; // null hanya untuk PIN demo

  const RelawanSession({
    required this.nama,
    this.poskoId,
    required this.posko,
    this.kontak = '',
    this.relawanId,
  });

  String get poskoLabel => 'Posko $posko';
}
