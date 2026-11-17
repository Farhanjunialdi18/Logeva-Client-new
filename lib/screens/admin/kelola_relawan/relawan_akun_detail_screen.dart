// ============================================================
// relawan_akun_detail_screen.dart
// HALAMAN DETAIL RELAWAN (oleh admin):
// info akun, LIHAT PIN, GENERATE PIN BARU, EDIT,
// NONAKTIFKAN/AKTIFKAN, dan HAPUS relawan.
// ============================================================

import 'package:flutter/material.dart';

import '../../../core/data_options.dart';
import '../../../data/data_events.dart';
import '../../../data/repositories/posko_repository.dart';
import '../../../data/repositories/relawan_repository.dart';
import '../../../models/relawan.dart';
import '../../../services/file_service.dart';
import '../../../services/penyiapan_service.dart';
import '../../../services/session_service.dart';
import '../../../services/sinkron_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_text_styles.dart';
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
import '../../../services/perangkat_service.dart';
import '../../../widgets/dikelola_induk_banner.dart';
import '../../../widgets/status_hp_relawan.dart';
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
  bool _membagikan = false;

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

  /// Kirim akun relawan (beserta akun lain & data posko-nya) ke HP relawan
  /// lewat menu Bagikan: Bluetooth / Quick Share / WhatsApp.
  Future<void> _bagikan(Relawan relawan) async {
    final poskoId = relawan.poskoId;
    if (poskoId == null) {
      AppSnackbar.show(context, 'Tempatkan relawan di posko dulu (EDIT RELAWAN).',
          isError: true);
      return;
    }
    if (!relawan.isAktif) {
      AppSnackbar.show(context, 'Aktifkan relawan dulu supaya bisa login.',
          isError: true);
      return;
    }
    final posko = await PoskoRepository.instance.findById(poskoId);
    if (!mounted || posko == null) return;
    final rencana = await PenyiapanService.rencana(posko);
    if (!mounted) return;
    if (!rencana.bisaDibuat) {
      AppSnackbar.show(
          context,
          'Ganti dulu password bawaan admin (Settings → Keamanan) sebelum '
          'membagikan akun.',
          isError: true);
      return;
    }

    final yakin = await ConfirmDialog.show(
      context,
      title: 'Bagikan ke HP ${relawan.nama}?',
      message: 'File berisi akun posko ${posko.nama} (PIN sudah diacak) serta '
          'data pengungsi & logistik posko. Pilih Bluetooth atau Quick Share, '
          'lalu pilih HP relawan.\n\nDi HP relawan: ketuk file ZIP → Buka dengan '
          'LOGEVA → YA, SINKRONKAN → login dengan PIN.',
      confirmText: 'BAGIKAN',
    );
    if (!yakin || !mounted) return;

    setState(() => _membagikan = true);
    try {
      final waktu = DateTime.now();
      final (nama, bytes) = await SinkronService.buatFile(
        posko,
        dibuatOleh: SessionService.instance.namaPencatat,
        awalanNama: 'LOGEVA_penyiapan_',
        waktu: waktu,
      );
      final terkirim =
          await FileService.bagikan(nama, bytes, judul: 'Kirim ke HP ${relawan.nama}');
      if (terkirim) {
        // Pengingat "perlu dibagikan ulang" untuk relawan ini hilang.
        await SinkronService.tandaiDibagikan(relawan.kode, waktu);
        DataEvents.instance.notifyChanged();
      }
      if (!mounted) return;
      if (terkirim) {
        AppSnackbar.show(
          context,
          relawan.pinTerlihat
              ? 'File terkirim. Beritahukan PIN ${relawan.nama}: ${relawan.pin}'
              : 'File terkirim. Beritahukan PIN ke ${relawan.nama}.',
          duration: const Duration(seconds: 10),
        );
      }
    } on PenyiapanException catch (e) {
      if (mounted) AppSnackbar.show(context, e.message, isError: true);
    } catch (e) {
      if (mounted) AppSnackbar.show(context, 'Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _membagikan = false);
    }
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
                    child: relawan.pinTerlihat
                        ? Text(
                            _tampilkanPin ? relawan.pin : '••••••',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: p.textPrimary,
                            ),
                          )
                        : Text(
                            'Hanya terlihat di HP Induk',
                            style: AppTextStyles.body(p),
                          ),
                  ),
                  DetailRow(
                    label: 'Dibuat',
                    value: '${DateFormatter.date(relawan.dibuatPada)} '
                        '(${DateFormatter.lamaSejak(relawan.dibuatPada)})',
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

              if (PerangkatService.isAnggota)
                const DikelolaIndukBanner()
              else ...[
                StatusHpRelawanCard(relawan: relawan),
                const SizedBox(height: 16),
                PrimaryButton(
                  text: _tampilkanPin ? 'SEMBUNYIKAN PIN' : 'LIHAT PIN',
                  onPressed: () => setState(() => _tampilkanPin = !_tampilkanPin),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  text: 'BAGIKAN KE HP RELAWAN (BLUETOOTH)',
                  isLoading: _membagikan,
                  onPressed: () => _bagikan(relawan),
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
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
