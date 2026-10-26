// ============================================================
// logistik_screen.dart
// HALAMAN LOGISTIK (relawan): stok & catatan barang masuk/keluar
// untuk posko tugas relawan yang sedang login.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../models/posko.dart';
import '../../../services/session_service.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/page_header.dart';
import 'logistik_posko_panel.dart';

class LogistikScreen extends StatefulWidget {
  final VoidCallback onBack;

  const LogistikScreen({super.key, required this.onBack});

  @override
  State<LogistikScreen> createState() => _LogistikScreenState();
}

class _LogistikScreenState extends State<LogistikScreen> {
  Posko? _posko;
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
    final id = SessionService.instance.poskoId;
    final posko = id == null ? null : await PoskoRepository.instance.findById(id);
    if (!mounted) return;
    setState(() {
      _posko = posko;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final posko = _posko;

    return AppBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Logistik',
            subtitle: SessionService.instance.poskoLabel,
            showOfflineBadge: true,
            onBack: widget.onBack,
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (posko == null)
            const EmptyState(
              icon: Icons.home_work_outlined,
              message: 'Akun belum ditempatkan di posko. Hubungi admin.',
            )
          else
            LogistikPoskoPanel(posko: posko),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
