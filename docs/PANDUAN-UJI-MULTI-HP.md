# Panduan Uji di HP Sungguhan: Beberapa HP Satu Posko

Untuk menguji fitur yang **tidak bisa diuji otomatis**: pengiriman file lewat Bluetooth / Quick Share,
pemakaian di HP Android sungguhan, dan alur lengkap sampai website pusat.
Semua logika (penyiapan, sinkron, stok, dobel, impor website) sudah diuji otomatis; panduan ini memastikan
semuanya juga berjalan di tangan pengguna.

Centang setiap **Hasil yang benar**. Kalau ada yang tidak sesuai, catat nomor langkah + foto layar.

---

## Persiapan

| Yang dibutuhkan | Keterangan |
|---|---|
| **HP 1 = HP Induk** | dipegang penguji sebagai admin / supervisor |
| **HP 2 = HP Anggota A** | dipegang penguji sebagai relawan Andi |
| **HP 3 = HP Anggota B** (opsional) | untuk skenario dobel; bisa diganti HP 2 jika hanya punya 2 HP |
| APK | `build/app/outputs/flutter-apk/app-release.apk` (hasil `flutter build apk --release`) |
| Website | sudah di-upload & migrate (`/_deploy/<token>/migrate`), punya 1 akun relawan yang disetujui |

1. Pasang APK di semua HP. Kalau aplikasi lama sudah terpasang di HP 2/3, **hapus dulu** (HP Anggota harus kosong).
2. Pastikan **tanggal & jam** di semua HP benar (Pengaturan → Tanggal & waktu → otomatis, lalu cek).
3. **Matikan data seluler & Wi-Fi** di semua HP selama skenario 1–7. Bluetooth tetap menyala.

---

## Skenario 1: HP Induk pertama kali dipakai

1. HP Induk: buka aplikasi → **ADMIN** → login `admin` / `admin123`.
   - [ ] Muncul layar **GANTI PASSWORD DULU** (tombol back tidak bisa melewatinya).
2. Isi password baru, misal `posko2026` (min. 8 karakter, huruf + angka) → **SIMPAN PASSWORD**.
   - [ ] Masuk ke beranda admin. `admin123` sekarang ditolak saat login ulang.
3. Settings → **Profil Admin**: ganti email ke email yang bisa dihubungi → **SIMPAN PROFIL**.
4. Tab **Data** → **DATA POSKO** → **+ TAMBAH POSKO**: isi nama, desa (sama dengan nama desa di website),
   alamat, luas (misal 1050), latitude & longitude → **SIMPAN POSKO**.
   - [ ] Kapasitas terhitung otomatis (1050 m² → 300 orang).
5. Buka posko → **MULAI OPERASI**.
6. Tab **Relawan** → **+ TAMBAH RELAWAN**: nama `Andi`, kontak nomor HP, posko tadi → **SIMPAN RELAWAN**.
   Catat PIN-nya. (Tambah juga `Budi` untuk HP 3 jika ada.)

## Skenario 2: Menyiapkan HP Anggota lewat Bluetooth

1. HP Induk: Data → Data Posko → posko → **SIAPKAN HP ANGGOTA**.
   - [ ] Terlihat daftar relawan & admin yang ikut. Tidak ada tulisan PIN/password asli.
2. **BAGIKAN (BLUETOOTH / QUICK SHARE)** → konfirmasi → pilih **Bluetooth** (atau Quick Share) → pilih HP 2.
3. HP 2: terima file. Buka aplikasi → **Siapkan HP ini dari HP Induk** → **PILIH FILE PENYIAPAN** →
   pilih `penyiapan_....zip` (biasanya di folder Download / Bluetooth).
   - [ ] Terlihat isi file: nama posko, jumlah relawan & admin.
4. **TERAPKAN**.
   - [ ] Pesan "HP ini siap sebagai HP Anggota …". Layar awal menulis "HP Anggota · login dengan akun dari HP Induk".
5. HP 2: **RELAWAN** → masukkan PIN Andi.
   - [ ] Login berhasil, beranda menampilkan posko yang benar.
6. HP 2: logout → **ADMIN** → login `admin` / `posko2026`.
   - [ ] Login berhasil. `admin123` ditolak.
   - [ ] Di Data Posko / Relawan / Master Barang tidak ada tombol tambah/ubah/hapus; muncul kotak biru
         "Dikelola di HP Induk".
7. Hapus file `penyiapan_....zip` dari kedua HP.

## Skenario 3: Sinkron dua arah

1. HP 2 (relawan Andi): **Pengungsi** → tambah `Siti Aminah`, tanggal lahir 12/03/1958, kelompok rentan Lansia.
   **Logistik** → **+ MASUK** → Beras 50 kg, sumber BPBD.
2. HP Induk (admin): Logistik posko → **+ MASUK** → Air Mineral 100 liter. Pengungsi → tambah `Budi Santoso`.
3. HP 2: beranda → **SINKRON DENGAN HP INDUK** → **KIRIM KE HP INDUK** → konfirmasi → Bluetooth → HP 1.
4. HP Induk: Data → **SINKRON ANTAR-HP** → **PILIH FILE SINKRON** → pilih `sinkron_..._dari-anggota_....zip`.
   - [ ] Pratinjau: dari Andi, Pengungsi "1 baru", Barang masuk "1 baru".
5. **GABUNGKAN**.
   - [ ] Siti Aminah muncul di Data Pengungsi HP Induk; stok beras 50.
6. HP Induk: **KIRIM KE HP ANGGOTA** → Bluetooth → HP 2.
7. HP 2: Sinkron dengan HP Induk → **PILIH FILE SINKRON** → file `..._dari-induk_....zip` → **GABUNGKAN**.
   - [ ] Budi Santoso & Air Mineral 100 liter sekarang ada di HP 2.
8. Ulangi langkah 3–5 dengan file yang sama.
   - [ ] Muncul "Semua data di file ini sudah ada di HP ini" (tidak dobel).

## Skenario 4: Perubahan akun ikut terbawa

1. HP Induk: Relawan → Andi → **GENERATE PIN BARU** (catat PIN baru). Tambah relawan `Rina`.
2. HP Induk: Sinkron Antar-HP → **KIRIM KE HP ANGGOTA** → HP 2 → di HP 2 gabungkan.
   - [ ] Pratinjau di HP 2 menyebut akun relawan diperbarui.
3. HP 2: logout → login dengan **PIN lama** Andi → [ ] ditolak. PIN baru → [ ] berhasil. PIN Rina → [ ] berhasil.

## Skenario 5: Barang keluar melebihi stok di HP Anggota

1. HP Induk: **+ MASUK** Beras 30 kg (jangan sinkron dulu).
2. HP 2: Logistik → **− KELUAR** → Beras → jumlah lebih besar dari stok di HP itu (misal 70).
   - [ ] Muncul konfirmasi **Melebihi stok di HP ini** → **TETAP CATAT**.
   - [ ] Layar Logistik HP 2 menampilkan kotak merah "Stok minus: Beras …".
3. Sinkron HP 2 → HP Induk, lalu HP Induk → HP 2 (seperti skenario 3).
   - [ ] Stok beras di kedua HP sama: 50 + 30 − 70 = **10 kg**, kotak "Stok minus" hilang.
4. (Opsional) Di HP Induk, coba **− KELUAR** melebihi stok → [ ] ditolak (HP Induk tetap ketat).

## Skenario 6: Pengungsi dobel dari 2 HP

1. HP 2 dan HP 3 (atau HP Induk): masing-masing tambah pengungsi **nama & tanggal lahir sama**, misal
   `Rahmat` 01/01/1980; di salah satunya isi Nomor KK.
2. Sinkron semua HP Anggota → HP Induk.
   - [ ] Di HP Induk, Data → **DATA PENGUNGSI** muncul kotak kuning "1 kemungkinan pengungsi dobel".
3. Ketuk kotak → tekan **PAKAI DATA …** pada data yang Nomor KK-nya "belum diketahui" → **GABUNGKAN**.
   - [ ] Tersisa 1 Rahmat, Nomor KK terisi dari data lainnya.
4. Sinkron HP Induk → HP Anggota.
   - [ ] Di HP Anggota juga tinggal 1 Rahmat.

## Skenario 7: Ekspor ke pusat

1. HP Induk: Data → **EKSPOR PAKET DATA POSKO** → pilih posko.
   - [ ] Terlihat isi paket & daftar petugas (admin + relawan, beserta kontak). Tidak ada peringatan merah.
2. **EKSPOR PAKET (ZIP)** → konfirmasi data pribadi → simpan ke flashdisk / folder.
3. (Opsional) Lakukan juga dari HP 2 untuk menguji paket dari HP Anggota.

## Skenario 8: Impor di website pusat (boleh pakai internet)

1. Website → login admin → sidebar **Import Paket Posko** → upload `paket_....zip` → **Lihat Pratinjau**.
   - [ ] Tertulis "dari HP Induk (supervisor)". Posko baru meminta **Pilih relawan**.
2. Pilih relawan website → **Konfirmasi Gabung**.
   - [ ] Lokasi baru muncul; detail Lokasi menampilkan **Petugas Lapangan (Aplikasi Offline)** dengan
         admin & relawan, masing-masing satu kali.
   - [ ] Jumlah pengungsi & stok sama dengan di HP Induk.
3. Upload paket yang sama lagi (atau paket dari HP 2).
   - [ ] Pratinjau: data "Tidak berubah" / "Dilewati"; setelah konfirmasi tidak ada data dobel, stok tidak bertambah.
4. Hapus file paket dari flashdisk.

---

## Jika ada masalah

| Gejala | Kemungkinan penyebab |
|---|---|
| Opsi Bluetooth tidak ada di menu Bagikan | Nyalakan Bluetooth dulu; atau pakai Quick Share / **SIMPAN KE FILE** lalu kirim dari aplikasi File |
| File tidak ditemukan di HP penerima | Cek folder Download, Bluetooth, atau Quick Share di aplikasi File |
| "HP ini sudah berisi data…" saat penyiapan | HP Anggota harus baru dipasang (hapus & pasang ulang aplikasi) |
| "Posko di paket ini tidak ada di HP ini" | HP pengirim belum disiapkan dari HP Induk posko ini |
| Peringatan "lebih maju dari jam HP ini" | Tanggal/jam salah satu HP salah; perbaiki sebelum menggabungkan |
| Perubahan tidak terbawa padahal sudah sinkron | Pastikan file yang dipilih file terbaru (lihat waktu di nama file) |
