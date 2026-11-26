// ============================================================
// akun_admin_screen.dart
// TAB ADMIN: AKUN ADMIN POSKO. Satu posko = satu admin/supervisor, jadi
// tidak ada tambah admin. Di sini admin melihat & membetulkan datanya
// sendiri (nama, kontak, password). Nama ini tercatat sebagai ADMIN POSKO
// (penanggung jawab) di Paket Data Posko yang diekspor ke pusat.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/admin_repository.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../models/admin.dart';
import '../../../models/posko.dart';
import '../../../services/session_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
import '../../../utils/date_formatter.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/info_card.dart';
import '../../../widgets/menu_card.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/lengkapi_posko_banner.dart';
import '../posko/posko_form_screen.dart';
import '../settings/keamanan_screen.dart';
import '../settings/profil_admin_screen.dart';

class AkunAdminScreen extends StatefulWidget {
  final VoidCallback onBack;

  const AkunAdminScreen({super.key, required this.onBack});

  @override
  State<AkunAdminScreen> createState() => _AkunAdminScreenState();
}

class _AkunAdminScreenState extends State<AkunAdminScreen> {
  Admin? _admin;
  Posko? _posko;

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
    final id = SessionService.instance.admin?.id;
    final admin = id == null ? null : await AdminRepository.instance.findById(id);
    final posko = await PoskoRepository.instance.poskoHp();
    if (!mounted) return;
    setState(() {
      _admin = admin ?? SessionService.instance.admin;
      _posko = posko;
    });
  }

  Future<void> _buka(Widget halaman) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => halaman));
    await _load();
  }

  String _isi(String t) => t.trim().isEmpty ? '-' : t;

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final a = _admin;

    return AppBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Akun Admin Posko',
            subtitle: 'Satu posko, satu admin/supervisor',
            onBack: widget.onBack,
          ),
          const SizedBox(height: 16),
          if (a != null)
            InfoCard(
              title: 'ADMIN POSKO',
              rows: {
                'Nama': a.nama,
                'Username': a.username,
                'Kontak': _isi(a.email),
                'Akun dibuat': DateFormatter.date(a.dibuatPada),
              },
              note: 'Nama ini tercatat sebagai Admin Posko (penanggung jawab) di '
                  'Paket Data Posko yang diekspor ke pusat. Salah ketik? Tekan '
                  'EDIT DATA ADMIN.',
            ),
          const SizedBox(height: 14),
          InfoCard(
            title: 'POSKO TEMPAT BERTUGAS',
            rows: {
              'Posko': _posko?.nama ?? 'Belum diatur',
              'Desa': _isi(_posko?.namaDesa ?? ''),
            },
            note: 'Relawan yang akunnya Anda bagikan otomatis bertugas di posko ini.',
          ),
          if (_posko != null) ...[
            const SizedBox(height: 12),
            LengkapiPoskoBanner(posko: _posko),
            MenuCard(
              icon: Icons.edit_location_alt_rounded,
              iconColor: AppColors.primary,
              title: 'EDIT DATA POSKO',
              description: 'Nama, desa, alamat, luas, koordinat, ketinggian',
              onTap: () => _buka(PoskoFormScreen(existing: _posko)),
            ),
          ],
          const SizedBox(height: 20),
          Text('UBAH AKUN', style: AppTextStyles.label(p)),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.edit_rounded,
            iconColor: AppColors.accentPurple,
            title: 'EDIT DATA ADMIN',
            description: 'Nama, username, dan kontak',
            onTap: () => _buka(const ProfilAdminScreen()),
          ),
          const SizedBox(height: 12),
          MenuCard(
            icon: Icons.lock_rounded,
            iconColor: AppColors.accentAmber,
            title: 'GANTI PASSWORD',
            description: 'Catat password baru di tempat aman',
            onTap: () => _buka(const KeamananScreen()),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
