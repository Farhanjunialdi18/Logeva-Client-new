// ============================================================
// admin_logistik_screen.dart
// DATA LOGISTIK versi ADMIN: pilih posko, lalu lihat stok & catatan
// barang masuk/keluar posko itu (admin juga boleh mencatat, sama
// seperti website). Master barang dikelola di menu Master Barang.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../models/posko.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/page_header.dart';
import '../../relawan/logistik/logistik_posko_panel.dart';

class AdminLogistikScreen extends StatefulWidget {
  const AdminLogistikScreen({super.key});

  @override
  State<AdminLogistikScreen> createState() => _AdminLogistikScreenState();
}

class _AdminLogistikScreenState extends State<AdminLogistikScreen> {
  List<Posko> _daftarPosko = [];
  int? _poskoId;
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
    final posko = await PoskoRepository.instance.getAll()
      ..sort((a, b) => a.nama.toLowerCase().compareTo(b.nama.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _daftarPosko = posko;
      // Posko pertama terpilih otomatis; pilihan lama dipertahankan.
      if (!posko.any((p) => p.id == _poskoId)) {
        _poskoId = posko.isEmpty ? null : posko.first.id;
      }
      _loading = false;
    });
  }

  Posko? get _posko {
    for (final p in _daftarPosko) {
      if (p.id == _poskoId) return p;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final posko = _posko;

    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Data Logistik',
              subtitle: 'Stok & catatan barang per posko',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_daftarPosko.isEmpty)
              const EmptyState(
                icon: Icons.home_work_outlined,
                message: 'Belum ada posko. Tambahkan posko di menu Data Posko.',
              )
            else ...[
              AppDropdownField(
                label: 'POSKO',
                value: posko?.nama,
                items: _daftarPosko.map((p) => p.nama).toList(),
                onChanged: (v) => setState(() {
                  for (final p in _daftarPosko) {
                    if (p.nama == v) _poskoId = p.id;
                  }
                }),
              ),
              const SizedBox(height: 16),
              if (posko != null) LogistikPoskoPanel(posko: posko),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
