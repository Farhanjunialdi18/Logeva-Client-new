// ============================================================
// data_events.dart
// "Pengumuman" setiap kali data berubah (tambah/edit/hapus/import),
// supaya Beranda, tabel, dan Riwayat otomatis memuat ulang.
// ============================================================

import 'package:flutter/foundation.dart';

class DataEvents extends ChangeNotifier {
  DataEvents._();
  static final DataEvents instance = DataEvents._();

  void notifyChanged() => notifyListeners();
}
