// ============================================================
// beranda_screen.dart
// HALAMAN BERANDA RELAWAN:
// sapaan, info posko, ringkasan data, status bantuan posko, menu utama.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/app_constants.dart';
import '../../../data/data_events.dart';
import '../../../data/repositories/logistik_repository.dart';
import '../../../data/repositories/pengungsi_repository.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../services/ringkasan_posko_service.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/kotak_peringatan.dart';
import '../../../widgets/menu_card.dart';
import '../../../widgets/offline_badge.dart';
import '../../../widgets/stat_card.dart';
import '../../../widgets/status_bantuan_widgets.dart';
import '../../../widgets/theme_toggle_button.dart';
import '../../../services/perangkat_service.dart';
import '../../dashboard/dashboard_screen.dart';
import '../../ringkasan/ringkasan_posko_screen.dart';

class BerandaScreen extends StatefulWidget {
  /// Dipanggil saat kartu menu diketuk (1=Pengungsi, 2=Logistik, 3=Riwayat).
  final ValueChanged<int> onOpenMenu;

  const BerandaScreen({super.key, required this.onOpenMenu});

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  int? _jumlahPengungsi;
  int? _jumlahLogistik;
  RingkasanPosko? _ringkasan;

  @override
  void initState() {
    super.initState();
    _load();
    DataEvents.instance.addListener(_load);
  }

  @override
  void dispose() {
    DataEvents.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final poskoId = SessionService.instance.poskoId;
    final pengungsi = poskoId == null
        ? 0
        : await PengungsiRepository.instance.count(poskoId: poskoId);
    // Jenis barang yang masih ada stoknya di posko ini.
    final logistik = poskoId == null
        ? 0
        : (await LogistikRepository.instance.getStok(poskoId))
            .where((s) => s.jumlah > 0)
            .length;
    final posko =
        poskoId == null ? null : await PoskoRepository.instance.findById(poskoId);
    final ringkasan =
        posko == null ? null : await RingkasanPoskoService.muat(posko);
    if (!mounted) return;
    setState(() {
      _jumlahPengungsi = pengungsi;
      _jumlahLogistik = logistik;
      _ringkasan = ringkasan;
    });
  }

  void _bukaRingkasan() {
    final r = _ringkasan;
    if (r == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RingkasanPoskoScreen(posko: r.posko)),
    );
  }

  String _angka(int? n, String satuan) => n == null ? '...' : '$n $satuan';

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final session = SessionService.instance;

    return AppBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Logo kecil + nama aplikasi + tombol tema ----
          Row(
            children: [
              const AppLogo(size: 38, glow: false),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppConstants.appName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const ThemeToggleButton(),
            ],
          ),
          const SizedBox(height: 24),

          // ---- Sapaan ----
          Text('Selamat datang,', style: AppTextStyles.body(p)),
          const SizedBox(height: 2),
          Text(
            session.namaRelawan,
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w700,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text('Relawan', style: AppTextStyles.small(p)),
          Text(session.poskoLabel, style: AppTextStyles.small(p)),
          const SizedBox(height: 12),
          const OfflineBadge(),
          const SizedBox(height: 8),
          Text('Data tersimpan di perangkat', style: AppTextStyles.small(p)),
          const SizedBox(height: 24),

          // ---- Ringkasan data ----
          Text('RINGKASAN DATA POSKO', style: AppTextStyles.label(p)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  icon: Icons.groups_rounded,
                  iconColor: AppColors.accentPurple,
                  label: 'Pengungsi',
                  value: _angka(_jumlahPengungsi, 'Orang'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatCard(
                  icon: Icons.inventory_2_rounded,
                  iconColor: AppColors.accentAmber,
                  label: 'Barang tersedia',
                  value: _angka(_jumlahLogistik, 'Jenis'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ---- Peringatan: posko hampir/sudah penuh, stok < 7 hari ----
          if (session.poskoId != null) KotakPeringatan(poskoId: session.poskoId),

          // ---- Status bantuan posko (hanya saat beroperasi) ----
          if (_ringkasan?.posko.isBeroperasi ?? false) ...[
            KartuStatusBantuan(ringkasan: _ringkasan!, onTap: _bukaRingkasan),
            const SizedBox(height: 16),
            Text('TUGAS HARI INI', style: AppTextStyles.label(p)),
            const SizedBox(height: 10),
            DaftarTugas(tugas: _ringkasan!.tugas, batas: 3),
            if (_ringkasan!.tugas.length > 3)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _bukaRingkasan,
                  child: Text(
                    'Lihat semua (${_ringkasan!.tugas.length} tugas)',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
            const SizedBox(height: 16),
          ],

          // ---- Menu ----
          MenuCard(
            icon: Icons.groups_rounded,
            iconColor: AppColors.accentPurple,
            title: 'DATA PENGUNGSI',
            description: 'Catat dan kelola data pengungsi',
            onTap: () => widget.onOpenMenu(1),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.inventory_2_rounded,
            iconColor: AppColors.accentAmber,
            title: 'DATA LOGISTIK',
            description: 'Catat barang masuk & keluar, lihat stok',
            onTap: () => widget.onOpenMenu(2),
          ),
          // HP Anggota: relawan mengirim/menerima data ke/dari HP Induk.
          if (PerangkatService.isAnggota) ...[
            const SizedBox(height: 12),
            MenuCard(
              icon: Icons.sync_alt_rounded,
              iconColor: AppColors.accentBlue,
              title: 'SINKRON DENGAN HP INDUK',
              description: 'Kirim & terima data lewat Bluetooth / Quick Share',
              onTap: () => widget.onOpenMenu(3),
            ),
          ],
          if (_ringkasan != null) ...[
            const SizedBox(height: 12),
            MenuCard(
              icon: Icons.health_and_safety_rounded,
              iconColor: AppColors.success,
              title: 'KEBUTUHAN & KOMPOSISI',
              description: 'Kebutuhan bantuan, komposisi, perhatian medis',
              onTap: _bukaRingkasan,
            ),
          ],
          if (SessionService.instance.poskoId != null) ...[
            const SizedBox(height: 12),
            MenuCard(
              icon: Icons.insights_rounded,
              iconColor: AppColors.accentBlue,
              title: 'DASHBOARD GRAFIK',
              description: 'Grafik pengungsi, tren 7 hari, dan stok posko',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      DashboardScreen(poskoId: SessionService.instance.poskoId),
                ),
              ),
            ),
          ],
          // Di HP Anggota tab ke-4 adalah Sinkron (kartu di atas).
          if (!PerangkatService.isAnggota) ...[
            const SizedBox(height: 12),
            MenuCard(
              icon: Icons.history_rounded,
              iconColor: AppColors.accentBlue,
              title: 'RIWAYAT TRANSAKSI',
              description: 'Lihat riwayat import dan export data',
              onTap: () => widget.onOpenMenu(3),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
