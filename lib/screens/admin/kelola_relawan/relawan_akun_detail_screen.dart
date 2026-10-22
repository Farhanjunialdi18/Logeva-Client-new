// ============================================================
// relawan_akun_detail_screen.dart
// HALAMAN DETAIL RELAWAN (oleh admin):
// info akun, LIHAT PIN, GENERATE PIN BARU, EDIT,
// NONAKTIFKAN/AKTIFKAN, dan HAPUS relawan.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/data_options.dart';
import '../../../data/data_events.dart';
import '../../../data/repositories/relawan_repository.dart';
import '../../../models/relawan.dart';
import '../../../theme/app_colors.dart';
import '../../../utils/app_snackbar.dart';
import '../../../utils/date_formatter.dart';
import '../../../widgets/app_background.dart';
import '../../../widgets/confirm_dialog.dart';
import '../../../widgets/detail_info_card.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/initials_avatar.dart';
import '../../../widgets/page_header.dart';
import '../../../widgets/primary_button.dart';
import '../../../widgets/secondary_button.dart';
import '../../../widgets/status_dot.dart';
import 'relawan_akun_form_screen.dart';

class RelawanAkunDetailScreen extends StatefulWidget {
  final int relawanId;

  const RelawanAkunDetailScreen({super.key, required this.relawanId});

  @override
  State<RelawanAkunDetailScreen> createState() =>
      _RelawanAkunDetailScreenState();
}

class _RelawanAkunDetailScreenState extends State<RelawanAkunDetailScreen> {
  Relawan? _relawan;
  bool _loading = true;
  bool _tampilkanPin = false;
  bool _generating = false;
  bool _busy = false;

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
    final data = await RelawanRepository.instance.findById(widget.relawanId);
    if (!mounted) return;
    setState(() {
      _relawan = data;
      _loading = false;
    });
  }

  Future<void> _generatePinBaru(Relawan relawan) async {
    final yakin = await ConfirmDialog.show(
      context,
      title: 'Buat PIN baru?',
      message: 'PIN lama ${relawan.nama} tidak bisa dipakai lagi. '
          'Berikan PIN baru ke relawan yang bersangkutan.',
      confirmText: 'BUAT PIN',
    );
    if (!yakin || !mounted) return;

    setState(() => _generating = true);
    final baru = await RelawanRepository.instance.regeneratePin(relawan);
    if (!mounted) return;
    setState(() {
      _generating = false;
      _tampilkanPin = true; // langsung tampilkan PIN barunya
    });
    AppSnackbar.show(context, 'PIN baru: ${baru.pin}');
  }

  void _edit(Relawan relawan) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RelawanAkunFormScreen(existing: relawan),
      ),
    );
  }

  Future<void> _ubahStatus(Relawan relawan) async {
    final yakin = await ConfirmDialog.show(
      context,
      title: relawan.isAktif ? 'Nonaktifkan relawan?' : 'Aktifkan relawan?',
      message: relawan.isAktif
          ? '${relawan.nama} tidak akan bisa login sampai diaktifkan lagi.'
          : '${relawan.nama} akan bisa login kembali dengan PIN-nya.',
      confirmText: relawan.isAktif ? 'NONAKTIFKAN' : 'AKTIFKAN',
    );
    if (!yakin || !mounted) return;

    setState(() => _busy = true);
    await RelawanRepository.instance.update(
      relawan.copyWith(
        status: relawan.isAktif
            ? DataOptions.statusNonaktif
            : DataOptions.statusAktif,
      ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    AppSnackbar.show(
      context,
      relawan.isAktif ? 'Relawan dinonaktifkan.' : 'Relawan diaktifkan.',
    );
  }

  Future<void> _hapus(Relawan relawan) async {
    final yakin = await ConfirmDialog.show(
      context,
      title: 'Hapus relawan?',
      message: 'Akun ${relawan.nama} akan dihapus permanen. '
          'Data pengungsi & logistik yang sudah dicatat tetap tersimpan.',
      confirmText: 'HAPUS',
    );
    if (!yakin || !mounted || relawan.id == null) return;

    await RelawanRepository.instance.delete(relawan.id!);
    if (!mounted) return;
    AppSnackbar.show(context, 'Relawan dihapus.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final relawan = _relawan;

    // Bukan Scaffold: halaman ini dibuka di dalam tab admin (Scaffold
    // utama sudah ada di AdminShellScreen), supaya keyboard tidak
    // menggeser halaman dua kali.
    return Material(
      type: MaterialType.transparency,
      child: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Detail Relawan',
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),

            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (relawan == null)
              const EmptyState(
                icon: Icons.person_off_rounded,
                message: 'Akun relawan tidak ditemukan.',
              )
            else ...[
              Center(child: InitialsAvatar(nama: relawan.nama)),
              const SizedBox(height: 16),

              DetailInfoCard(
                nama: relawan.nama,
                rows: [
                  const DetailRow(label: 'Role', value: 'Relawan'),
                  DetailRow(
                    label: 'Kontak',
                    value: relawan.kontak.isEmpty ? '-' : relawan.kontak,
                  ),
                  DetailRow(label: 'Posko', value: relawan.poskoLabel),
                  DetailRow(
                    label: 'Status',
                    child: StatusDot(aktif: relawan.isAktif, fontSize: 13),
                  ),
                  DetailRow(
                    label: 'PIN',
                    child: Text(
                      _tampilkanPin ? relawan.pin : '••••••',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  DetailRow(
                    label: 'Dibuat',
                    value: DateFormatter.date(relawan.dibuatPada),
                  ),
                  DetailRow(
                    label: 'Terakhir digunakan',
                    value: relawan.terakhirLogin == null
                        ? 'Belum pernah login'
                        : DateFormatter.full(relawan.terakhirLogin!),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              PrimaryButton(
                text: _tampilkanPin ? 'SEMBUNYIKAN PIN' : 'LIHAT PIN',
                onPressed: () => setState(() => _tampilkanPin = !_tampilkanPin),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                text: 'GENERATE PIN BARU',
                icon: Icons.autorenew_rounded,
                height: 54,
                isLoading: _generating,
                onPressed: () => _generatePinBaru(relawan),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                text: 'EDIT RELAWAN',
                height: 54,
                onPressed: () => _edit(relawan),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                text: relawan.isAktif
                    ? 'NONAKTIFKAN RELAWAN'
                    : 'AKTIFKAN RELAWAN',
                height: 54,
                isLoading: _busy,
                onPressed: () => _ubahStatus(relawan),
              ),
              const SizedBox(height: 12),
              SecondaryButton(
                text: 'HAPUS RELAWAN',
                icon: Icons.delete_outline_rounded,
                height: 54,
                onPressed: () => _hapus(relawan),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
