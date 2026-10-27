// ============================================================
// info_posko_screen.dart
// INFO POSKO & AKUN (relawan), setara halaman detail posko & profil
// relawan di website:
//  - data posko: alamat, desa, luas, kapasitas, koordinat
//  - status operasi + hari ke-N (mulai/tutup operasi oleh supervisor)
//  - akun relawan yang login
//  - siapa yang bisa dihubungi: supervisor (admin) & rekan relawan
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/pengungsi_repository.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../data/repositories/relawan_repository.dart';
import '../../../models/admin.dart';
import '../../../models/posko.dart';
import '../../../models/relawan.dart';
import '../../../services/perangkat_service.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/angka.dart';
import '../../../utils/tanggal.dart';
import '../../../utils/waktu_wib.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/page_header.dart';

class InfoPoskoScreen extends StatefulWidget {
  final int poskoId;

  const InfoPoskoScreen({super.key, required this.poskoId});

  @override
  State<InfoPoskoScreen> createState() => _InfoPoskoScreenState();
}

class _InfoPoskoScreenState extends State<InfoPoskoScreen> {
  Posko? _posko;
  int _jumlah = 0;
  List<Admin> _supervisor = [];
  List<Relawan> _rekan = [];
  bool _loading = true;

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
    final posko = await PoskoRepository.instance.findById(widget.poskoId);
    final jumlah = await PengungsiRepository.instance.count(poskoId: widget.poskoId);
    final admin = (await AdminRepository.instance.getAll()).where((a) => a.isAktif).toList();
    final rekan = (await RelawanRepository.instance.getAll())
        .where((r) => r.isAktif && r.poskoId == widget.poskoId)
        .toList()
      ..sort((a, b) => a.nama.compareTo(b.nama));
    if (!mounted) return;
    setState(() {
      _posko = posko;
      _jumlah = jumlah;
      _supervisor = admin;
      _rekan = rekan;
      _loading = false;
    });
  }

  String _isi(String teks) => teks.trim().isEmpty ? '-' : teks;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final posko = _posko;
    final sesi = SessionService.instance.relawan;

    return Scaffold(
      body: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Info Posko & Akun',
              subtitle: posko?.label ?? SessionService.instance.poskoLabel,
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (posko == null)
              Text('Posko tidak ditemukan di HP ini. Hubungi supervisor.',
                  style: AppTextStyles.small(p).copyWith(color: AppColors.sun))
            else ...[
              InfoCard(
                title: 'STATUS OPERASI',
                rows: {
                  'Status': posko.statusLabel,
                  if (posko.hariKe() != null) 'Hari operasi': 'Hari ke-${posko.hariKe()}',
                  if (posko.mulaiBeroperasiAt != null)
                    'Mulai': '${WaktuWib.tanggalWaktu(posko.mulaiBeroperasiAt!).substring(0, 16)} WIB',
                  'Pengungsi di posko': posko.kapasitas > 0
                      ? '$_jumlah dari ${posko.kapasitas} orang'
                      : '$_jumlah orang',
                },
                note: 'Mulai / tutup operasi dilakukan supervisor (admin) di HP Induk, '
                    'sama seperti di website hanya admin yang mengubah status posko. '
                    'Hubungi supervisor di bawah bila posko perlu dibuka atau ditutup.',
              ),
              const SizedBox(height: 14),
              InfoCard(
                title: 'DATA POSKO',
                rows: {
                  'Nama': posko.nama,
                  'Desa': _isi(posko.namaDesa),
                  'Alamat': _isi(posko.alamat),
                  'Luas': posko.luasLokasi == null
                      ? '-'
                      : '${Angka.tampil(posko.luasLokasi!)} m²',
                  'Kapasitas': posko.kapasitas > 0 ? '${posko.kapasitas} orang' : '-',
                  'Koordinat': posko.latitude.isEmpty
                      ? '-'
                      : '${posko.latitude}, ${posko.longitude}',
                  'Dicatat sejak': Tanggal.tampil(posko.dibuatPada),
                },
              ),
              const SizedBox(height: 14),
              InfoCard(
                title: 'AKUN SAYA',
                rows: {
                  'Nama': sesi?.nama ?? '-',
                  'Kontak': _isi(sesi?.kontak ?? ''),
                  'Peran': 'Relawan posko',
                  'HP ini': PerangkatService.isAnggota ? 'HP Anggota' : 'HP Induk',
                },
                note: 'PIN dibuat dan diganti oleh supervisor di HP Induk. '
                    'Lupa PIN? Minta PIN baru ke supervisor.',
              ),
              const SizedBox(height: 14),
              InfoCard(
                title: 'SUPERVISOR (ADMIN)',
                rows: {
                  for (final a in _supervisor) a.nama: _isi(a.email),
                  if (_supervisor.isEmpty) 'Belum ada': '-',
                },
              ),
              const SizedBox(height: 14),
              InfoCard(
                title: 'RELAWAN POSKO INI (${_rekan.length})',
                rows: {
                  for (final r in _rekan)
                    r.id == sesi?.relawanId ? '${r.nama} (saya)' : r.nama: _isi(r.kontak),
                  if (_rekan.isEmpty) 'Belum ada': '-',
                },
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
