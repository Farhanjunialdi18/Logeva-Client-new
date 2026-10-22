// ============================================================
// kelola_relawan_screen.dart
// HALAMAN KELOLA RELAWAN (tab "Relawan"):
// jumlah relawan, tombol tambah, pencarian, filter posko, daftar relawan.
// ============================================================

import 'package:flutter/material.dart';

import '../../../data/data_events.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../data/repositories/relawan_repository.dart';
import '../../../models/relawan.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/account_tile.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/app_dropdown_field.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/search_field.dart';
import '../../../widgets/summary_card.dart';
import 'relawan_akun_detail_screen.dart';
import 'relawan_akun_form_screen.dart';

class KelolaRelawanScreen extends StatefulWidget {
  final VoidCallback onBack;

  const KelolaRelawanScreen({super.key, required this.onBack});

  @override
  State<KelolaRelawanScreen> createState() => _KelolaRelawanScreenState();
}

class _KelolaRelawanScreenState extends State<KelolaRelawanScreen> {
  static const String _semuaPosko = 'Semua';
  static const String _belumDitempatkan = 'Belum ditempatkan';

  List<Relawan> _semua = [];
  List<String> _daftarPosko = [];
  bool _loading = true;
  String _kataCari = '';
  String _filterPosko = _semuaPosko;

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
    final relawan = await RelawanRepository.instance.getAll();
    // Pilihan filter = semua posko terdaftar + posko yang dipakai relawan.
    final posko = {
      ...await PoskoRepository.instance.getNames(),
      ...relawan.where((r) => r.sudahDitempatkan).map((r) => r.posko),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    if (!mounted) return;
    setState(() {
      _semua = relawan;
      _daftarPosko = posko;
      _loading = false;
    });
  }

  List<Relawan> get _hasilFilter {
    final q = _kataCari.trim().toLowerCase();
    return _semua.where((r) {
      final bool cocokPosko;
      if (_filterPosko == _semuaPosko) {
        cocokPosko = true;
      } else if (_filterPosko == _belumDitempatkan) {
        cocokPosko = !r.sudahDitempatkan;
      } else {
        cocokPosko = r.posko == _filterPosko;
      }
      final cocokCari = q.isEmpty || r.nama.toLowerCase().contains(q);
      return cocokPosko && cocokCari;
    }).toList();
  }

  void _tambah() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RelawanAkunFormScreen()),
    );
  }

  void _bukaDetail(Relawan relawan) {
    if (relawan.id == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RelawanAkunDetailScreen(relawanId: relawan.id!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _hasilFilter;
    final adaFilter = _kataCari.isNotEmpty || _filterPosko != _semuaPosko;

    return AppBackground(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Kelola Relawan',
            subtitle: 'Kelola akun dan akses relawan',
            onBack: widget.onBack,
          ),
          const SizedBox(height: 16),

          SummaryCard(
            label: 'Jumlah relawan',
            value: _loading ? '...' : '${_semua.length} Relawan',
          ),
          const SizedBox(height: 16),

          PrimaryButton(text: '+ TAMBAH RELAWAN', onPressed: _tambah),
          const SizedBox(height: 14),

          SearchField(
            hint: 'Cari nama relawan...',
            onChanged: (v) => setState(() => _kataCari = v),
          ),
          const SizedBox(height: 14),

          AppDropdownField(
            value: _filterPosko,
            items: [_semuaPosko, ..._daftarPosko, _belumDitempatkan],
            onChanged: (v) => setState(() => _filterPosko = v ?? _semuaPosko),
          ),
          const SizedBox(height: 14),

          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (list.isEmpty)
            EmptyState(
              icon: Icons.volunteer_activism_rounded,
              message: adaFilter
                  ? 'Tidak ada relawan yang cocok.'
                  : 'Belum ada relawan.\nTekan "+ TAMBAH RELAWAN" untuk membuat akun.',
            )
          else
            for (final relawan in list) ...[
              AccountTile(
                icon: Icons.volunteer_activism_rounded,
                iconColor: AppColors.primary,
                title: relawan.nama,
                lines: [relawan.poskoLabel, 'PIN: ••••••'],
                aktif: relawan.isAktif,
                onTap: () => _bukaDetail(relawan),
              ),
              const SizedBox(height: 12),
            ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
