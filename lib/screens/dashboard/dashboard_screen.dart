// ============================================================
// dashboard_screen.dart
// DASHBOARD GRAFIK (admin & relawan): infografis data posko.
//  - angka utama: pengungsi, rentan, perlu perhatian medis, posko
//  - keterisian posko (pengungsi / kapasitas)
//  - komposisi: jenis kelamin, kelompok usia, kelompok rentan, kesehatan
//  - tren 7 hari: pengungsi baru, catatan barang masuk & keluar
//  - stok: status barang pokok & berapa hari stok cukup (satu posko)
//  - status bantuan posko beroperasi
// Admin bisa memilih "Semua posko" atau satu posko; relawan hanya
// melihat posko tugasnya ([poskoId] diisi).
// ============================================================

import 'package:flutter/material.dart';

import '../../core/data_options.dart';
import '../../data/data_events.dart';
import '../../data/repositories/posko_repository.dart';
import '../../models/posko.dart';
import '../../services/dashboard_service.dart';
import '../../services/kebutuhan_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_text_styles.dart';
import '../../widgets/app_background.dart';
import '../../widgets/app_dropdown_field.dart';
import '../../widgets/grafik.dart';
import '../../widgets/page_header.dart';
import '../../widgets/secondary_button.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/status_bantuan_widgets.dart';
import '../laporan/laporan_harian_screen.dart';

class DashboardScreen extends StatefulWidget {
  /// Diisi untuk relawan: dashboard dikunci ke posko ini.
  final int? poskoId;

  const DashboardScreen({super.key, this.poskoId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const String _semua = 'Semua posko';
  static const Color _warnaPerempuan = Color(0xFFF472B6);

  List<Posko> _daftarPosko = [];
  int? _poskoId;
  DataDashboard? _data;

  bool get _terkunci => widget.poskoId != null;

  @override
  void initState() {
    super.initState();
    _poskoId = widget.poskoId;
    _load();
    DataEvents.instance.addListener(_load);
  }

  @override
  void dispose() {
    DataEvents.instance.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final posko = await PoskoRepository.instance.getAll();
    final data = await DashboardService.muat(poskoId: _poskoId);
    if (!mounted) return;
    setState(() {
      _daftarPosko = posko;
      _data = data;
    });
  }

  void _pilihPosko(String? label) {
    final dipilih = _daftarPosko.where((p) => p.label == label);
    setState(() {
      _poskoId = dipilih.isEmpty ? null : dipilih.first.id;
      _data = null;
    });
    _load();
  }

  static const List<String> _bulan = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];

  String _labelHari(DateTime d) => '${d.day} ${_bulan[d.month - 1]}';

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);
    final data = _data;

    return Scaffold(
      body: AppBackground(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Dashboard Grafik',
              subtitle: _terkunci
                  ? (data?.posko?.label ?? 'Posko tugas')
                  : 'Ringkasan data posko dalam grafik',
              showOfflineBadge: true,
              onBack: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 16),
            if (!_terkunci && _daftarPosko.length > 1) ...[
              AppDropdownField(
                value: data?.posko?.label ??
                    (_poskoId == null ? _semua : null),
                items: [_semua, for (final p in _daftarPosko) p.label],
                onChanged: _pilihPosko,
              ),
              const SizedBox(height: 16),
            ],
            SecondaryButton(
              text: 'LAPORAN HARIAN (TEKS)',
              icon: Icons.summarize_rounded,
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LaporanHarianScreen(poskoId: _poskoId),
              )),
            ),
            const SizedBox(height: 16),
            if (data == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (data.jumlahPosko == 0)
              Text(
                'Belum ada posko. Grafik tampil setelah posko dan pengungsi dicatat.',
                style: AppTextStyles.small(p),
              )
            else
              ..._isi(data, p),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  List<Widget> _isi(DataDashboard d, AppPalette p) {
    final k = d.komposisi;
    const jarak = SizedBox(height: 14);

    return [
      // ---- Angka utama ----
      Row(
        children: [
          Expanded(
            child: StatCard(
              icon: Icons.groups_rounded,
              iconColor: AppColors.accentPurple,
              label: 'PENGUNGSI',
              value: '${k.total} Orang',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.person_add_alt_1_rounded,
              iconColor: AppColors.accentBlue,
              label: 'BARU 7 HARI',
              value: '${d.pengungsiBaru7Hari} Orang',
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: StatCard(
              icon: Icons.accessible_rounded,
              iconColor: AppColors.accentAmber,
              label: 'KELOMPOK RENTAN',
              value: '${k.totalRentan} Orang',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              icon: Icons.medical_services_rounded,
              iconColor: AppColors.error,
              label: 'PERLU PERHATIAN',
              value: '${d.sakit} Orang',
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),

      // ---- Keterisian posko ----
      KartuGrafik(
        judul: 'Keterisian Posko',
        keterangan: k.kapasitas > 0
            ? 'Terisi ${k.total} dari ${k.kapasitas} orang (${k.persenIsi}%), '
                'sisa ${k.sisaTempat} tempat.'
            : 'Kapasitas belum bisa dihitung (luas lokasi belum diisi).',
        child: GrafikBatang(
          maks: 100,
          items: [
            for (final i in d.isiPosko)
              ItemGrafik(
                i.posko.nama,
                i.persen ?? 0,
                _warnaIsi(i.persen),
                teks: i.persen == null
                    ? '${i.jumlah} orang'
                    : '${i.jumlah}/${i.posko.kapasitas} · ${i.persen}%',
              ),
          ],
        ),
      ),
      jarak,

      // ---- Komposisi ----
      KartuGrafik(
        judul: 'Jenis Kelamin',
        child: k.total == 0
            ? const GrafikKosong()
            : GrafikTumpuk(items: [
                ItemGrafik('Laki-laki', k.lakiLaki, AppColors.accentBlue),
                ItemGrafik('Perempuan', k.perempuan, _warnaPerempuan),
              ]),
      ),
      jarak,
      KartuGrafik(
        judul: 'Kelompok Usia',
        child: k.total == 0
            ? const GrafikKosong()
            : GrafikBatang(items: [
                for (final (i, e) in k.usia.entries.indexed)
                  ItemGrafik(e.key, e.value, _warnaUsia[i % _warnaUsia.length]),
              ]),
      ),
      jarak,
      KartuGrafik(
        judul: 'Kelompok Rentan',
        keterangan: '${k.totalRentan} dari ${k.total} pengungsi termasuk kelompok rentan.',
        child: k.rentan.isEmpty
            ? const GrafikKosong(pesan: 'Tidak ada pengungsi kelompok rentan.')
            : GrafikBatang(items: [
                for (final e in (k.rentan.entries.toList()
                  ..sort((a, b) => b.value.compareTo(a.value))))
                  ItemGrafik(e.key, e.value, AppColors.accentPurple),
              ]),
      ),
      jarak,
      KartuGrafik(
        judul: 'Kondisi Kesehatan',
        child: k.total == 0
            ? const GrafikKosong()
            : GrafikTumpuk(items: [
                ItemGrafik('Sehat', d.sehat, AppColors.success),
                ItemGrafik('Perlu perhatian medis', d.sakit, AppColors.error),
              ]),
      ),
      jarak,
      if (d.jumlahKeluar > 0) ...[
        KartuGrafik(
          judul: 'Sudah Keluar dari Posko',
          keterangan: '${d.jumlahKeluar} orang tidak lagi dihitung untuk '
              'kapasitas & kebutuhan.',
          child: GrafikBatang(items: [
            for (final (st, warna) in [
              (DataOptions.pulang, AppColors.success),
              (DataOptions.pindah, AppColors.accentBlue),
              (DataOptions.dirujuk, AppColors.error),
            ])
              if ((d.keluarPosko[st] ?? 0) > 0)
                ItemGrafik(DataOptions.statusKeberadaan[st]!, d.keluarPosko[st]!, warna),
          ]),
        ),
        jarak,
      ],

      // ---- Tren 7 hari ----
      KartuGrafik(
        judul: 'Pengungsi Baru (7 Hari)',
        keterangan: 'Jumlah pengungsi yang dicatat per hari.',
        child: GrafikKolom(
          seri: const [ItemGrafik('Pengungsi baru', 0, AppColors.accentPurple)],
          kolom: [
            for (final h in d.tren)
              KolomGrafik(_labelHari(h.tanggal), [h.pengungsiBaru]),
          ],
        ),
      ),
      jarak,
      KartuGrafik(
        judul: 'Barang Masuk & Keluar (7 Hari)',
        keterangan: 'Jumlah catatan per hari (bukan jumlah barang, '
            'karena satuannya berbeda-beda).',
        child: GrafikKolom(
          seri: const [
            ItemGrafik('Masuk', 0, AppColors.success),
            ItemGrafik('Keluar', 0, AppColors.accentAmber),
          ],
          kolom: [
            for (final h in d.tren)
              KolomGrafik(_labelHari(h.tanggal), [h.barangMasuk, h.barangKeluar]),
          ],
        ),
      ),
      jarak,

      // ---- Stok ----
      KartuGrafik(
        judul: 'Status Stok Barang Pokok',
        keterangan: d.posko == null
            ? 'Dihitung per barang di setiap posko.'
            : 'Dihitung dari stok & kebutuhan harian pengungsi.',
        child: _donatStok(d, p),
      ),
      if (d.posko != null) ...[
        jarak,
        KartuGrafik(
          judul: 'Stok Cukup Untuk Berapa Hari',
          keterangan: 'Batang penuh = 7 hari. Merah/kuning perlu segera dikirim.',
          child: d.ketahanan.isEmpty
              ? const GrafikKosong(
                  pesan: 'Belum bisa dihitung (belum ada pengungsi atau '
                      'kebutuhan harian barang belum diisi).')
              : GrafikBatang(
                  maks: 7,
                  items: [
                    for (final s in d.ketahanan)
                      ItemGrafik(
                        s.barang.namaItem,
                        s.cukupHari!,
                        warnaStatusStok(s.status, p),
                        teks: KebutuhanService.teksHari(s.cukupHari),
                      ),
                  ],
                ),
        ),
      ],
      if (d.posko == null && d.poskoBeroperasi > 0) ...[
        jarak,
        KartuGrafik(
          judul: 'Status Bantuan Posko',
          keterangan: '${d.poskoBeroperasi} posko sedang beroperasi.',
          child: GrafikTumpuk(items: [
            for (final t in TingkatBantuan.urutan)
              if ((d.tingkatPosko[t] ?? 0) > 0)
                ItemGrafik(
                  TingkatBantuan.label(t),
                  d.tingkatPosko[t]!,
                  t == TingkatBantuan.belum ? p.textSecondary : warnaTingkat(t, p),
                ),
          ]),
        ),
      ],
    ];
  }

  Widget _donatStok(DataDashboard d, AppPalette p) {
    final s = d.statusStok;
    final total = s.values.fold(0, (a, b) => a + b);
    if (total == 0) return const GrafikKosong();
    final mendesak = (s[StatusStok.merah] ?? 0) + (s[StatusStok.kuning] ?? 0);
    return GrafikDonat(
      tengah: '$mendesak',
      subTengah: 'perlu dikirim',
      items: [
        for (final st in [
          StatusStok.merah,
          StatusStok.kuning,
          StatusStok.hijau,
          StatusStok.netral,
        ])
          if ((s[st] ?? 0) > 0)
            ItemGrafik(
              StatusStok.label(st),
              s[st]!,
              st == StatusStok.netral ? p.textSecondary : warnaStatusStok(st, p),
            ),
      ],
    );
  }

  static const List<Color> _warnaUsia = [
    Color(0xFF38BDF8), // balita
    AppColors.accentBlue, // anak
    AppColors.accentPurple, // remaja
    AppColors.accentAmber, // dewasa
    AppColors.primary, // lansia
  ];

  static Color _warnaIsi(int? persen) {
    if (persen == null) return AppColors.accentBlue;
    if (persen >= 100) return AppColors.error;
    if (persen >= 80) return AppColors.sun;
    return AppColors.success;
  }
}
