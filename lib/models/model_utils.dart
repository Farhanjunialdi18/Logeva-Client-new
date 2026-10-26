// ============================================================
// model_utils.dart
// Fungsi bantu kecil untuk membaca nilai dari database / CSV.
// ============================================================

/// Ubah nilai apa pun jadi teks (null -> '').
String asText(Object? value) => value?.toString().trim() ?? '';

/// Ubah nilai jadi angka bulat (gagal -> null).
int? asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(asText(value));
}

/// Ubah teks tanggal jadi DateTime (gagal -> sekarang).
DateTime asDate(Object? value) {
  return DateTime.tryParse(asText(value)) ?? DateTime.now();
}

/// Ubah teks tanggal jadi DateTime (kosong/gagal -> null).
DateTime? asDateOrNull(Object? value) => DateTime.tryParse(asText(value));
