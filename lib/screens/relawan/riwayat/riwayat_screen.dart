// ============================================================
// riwayat_screen.dart
// HALAMAN RIWAYAT TRANSAKSI: daftar proses import & export CSV.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/riwayat_repository.dart';
import '../../../models/riwayat_transaksi.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/riwayat_tile.dart';

class RiwayatScreen extends StatefulWidget {
  final VoidCallback onBack;

  const RiwayatScreen({super.key, required this.onBack});

  @override
  State<RiwayatScreen> createState() => _RiwayatScreenState();
}

class _RiwayatScreenState extends State<RiwayatScreen> {
  List<RiwayatTransaksi> _items = [];
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
    final data = await RiwayatRepository.instance.getAll();
    if (!mounted) return;
    setState(() {
      _items = data;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Riwayat Transaksi',
            subtitle: 'Riwayat import dan export data',
            onBack: widget.onBack,
          ),
          const SizedBox(height: 16),

          if (_loading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_items.isEmpty)
            const EmptyState(
              icon: Icons.history_rounded,
              message: 'Belum ada riwayat.\nImport atau export CSV akan tercatat di sini.',
            )
          else
            for (final item in _items) ...[
              RiwayatTile(item: item),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}
