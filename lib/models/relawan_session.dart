// ============================================================
// relawan_session.dart
// Data relawan yang sedang login (nama & posko tugas).
// ============================================================

class RelawanSession {
  final String nama;
  final int? poskoId; // null hanya untuk PIN demo
  final String posko; // contoh: 'Desa Panggarangan'

  const RelawanSession({required this.nama, this.poskoId, required this.posko});

  String get poskoLabel => 'Posko $posko';
}
