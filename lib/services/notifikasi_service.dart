// ============================================================
// notifikasi_service.dart
// NOTIFIKASI LOKAL: dibuat oleh aplikasi di HP ini sendiri, tanpa
// internet / server (flutter_local_notifications). Hanya aktif di
// Android; di Chrome (demo) dan tes, notifikasi tidak dikirim.
// Kalau pengguna menolak izin notifikasi, aplikasi tetap berjalan
// dan peringatan tetap tampil di dalam aplikasi (KotakPeringatan).
// ============================================================

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotifikasiService {
  NotifikasiService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _siap = false;

  /// Untuk tes: menangkap notifikasi yang akan dikirim.
  @visibleForTesting
  static void Function(int id, String judul, String isi)? tangkapUntukTes;

  static bool get _diAndroid => !kIsWeb && Platform.isAndroid;

  /// Dipanggil sekali saat aplikasi dibuka.
  static Future<void> mulai() async {
    if (!_diAndroid || _siap) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _siap = true;
    } catch (e) {
      debugPrint('Notifikasi tidak bisa disiapkan: $e');
    }
  }

  /// Meminta izin notifikasi (Android 13+). Ditolak = tidak apa-apa.
  static Future<void> mintaIzin() async {
    if (!_siap) return;
    try {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Izin notifikasi gagal diminta: $e');
    }
  }

  /// [id] tetap per posko & jenis, jadi notifikasi baru menggantikan
  /// notifikasi lama yang sejenis (tidak menumpuk).
  static Future<void> tampilkan(int id, String judul, String isi) async {
    tangkapUntukTes?.call(id, judul, isi);
    if (!_siap) return;
    try {
      await _plugin.show(
        id: id,
        title: judul,
        body: isi,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'peringatan_posko',
            'Peringatan posko',
            channelDescription:
                'Posko hampir/sudah penuh dan stok barang kurang dari 7 hari',
            importance: Importance.high,
            priority: Priority.high,
            // Isi panjang tetap terbaca utuh saat notifikasi dibuka.
            styleInformation: BigTextStyleInformation(isi),
          ),
        ),
      );
    } catch (e) {
      debugPrint('Notifikasi gagal ditampilkan: $e');
    }
  }
}
