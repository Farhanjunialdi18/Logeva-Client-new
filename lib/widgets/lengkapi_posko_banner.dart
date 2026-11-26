// ============================================================
// lengkapi_posko_banner.dart
// PENGINGAT DATA POSKO BELUM LENGKAP (HP admin/Induk), misal latitude &
// longitude belum diisi saat membuat posko. Tombol LENGKAPI DATA POSKO
// langsung membuka form edit posko. Data posko wajib lengkap sebelum
// Paket Data Posko bisa diekspor ke pusat.
// Tanpa [posko]: memakai posko HP ini (Beranda, Akun Admin).
// ============================================================

import 'package:flutter/material.dart';

import '../data/data_events.dart';
import '../data/repositories/posko_repository.dart';
import '../models/posko.dart';
import '../screens/admin/posko/posko_form_screen.dart';
import '../services/perangkat_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'secondary_button.dart';

class LengkapiPoskoBanner extends StatefulWidget {
  /// null = posko HP ini.
  final Posko? posko;

  const LengkapiPoskoBanner({super.key, this.posko});

  @override
  State<LengkapiPoskoBanner> createState() => _LengkapiPoskoBannerState();
}

class _LengkapiPoskoBannerState extends State<LengkapiPoskoBanner> {
  Posko? _posko;

  @override
  void initState() {
    super.initState();
    _posko = widget.posko;
    if (widget.posko == null) {
      _load();
      DataEvents.instance.addListener(_load);
    }
  }

  @override
  void didUpdateWidget(LengkapiPoskoBanner old) {
    super.didUpdateWidget(old);
    if (widget.posko != null) _posko = widget.posko;
  }

  @override
  void dispose() {
    if (widget.posko == null) DataEvents.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final p = await PoskoRepository.instance.poskoHp();
    if (mounted) setState(() => _posko = p);
  }

  @override
  Widget build(BuildContext context) {
    final posko = _posko;
    if (posko == null || posko.lengkap || PerangkatService.isAnggota) {
      return const SizedBox.shrink();
    }
    final p = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.sun.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.sun.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppColors.sun),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Data posko ${posko.nama} belum lengkap: '
                    '${posko.dataBelumLengkap.join(', ')}. Lengkapi supaya Paket '
                    'Data Posko bisa diekspor ke pusat.',
                    style: AppTextStyles.small(p).copyWith(color: p.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SecondaryButton(
              text: 'LENGKAPI DATA POSKO',
              icon: Icons.edit_location_alt_rounded,
              height: 46,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PoskoFormScreen(existing: posko)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
