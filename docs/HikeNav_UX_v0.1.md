# HikeNav: Alur UX dan Fitur (v0.1)

Dokumen ini melengkapi `HikeNav_PRD_v0.2.md`. Fokus: mobile (Android), alur dari cari gunung sampai selesai mendaki, dan fitur yang harus ada di tiap layar. Belum ada desain visual. Itu tahap berikutnya (`design.md`).

---

## 1. Temuan riset singkat

| Temuan | Dampak ke desain | Sumber |
|---|---|---|
| Alur aplikasi sejenis: pilih jalur, unduh peta, mulai rekam. Rute rencana tampil hijau, jejak yang sudah ditempuh biru | Pakai pola dua garis ini: rute referensi dan jejak aktual | [AllTrails Support](https://support.alltrails.com/hc/en-us/articles/37213942810132-How-to-use-your-downloaded-maps-for-navigation) |
| Unduh peta butuh internet dan harus dilakukan sebelum berangkat. Peta terunduh bisa dibuka tanpa sinyal | Fase "sebelum berangkat" dan "di jalur" harus terpisah jelas | AllTrails Support (sama) |
| Saat pendaki sadar salah jalan, beban kognitif naik. Alur harus offline secara bawaan | Peringatan keluar jalur: satu pesan, huruf besar, satu aksi | [DEV Community](https://dev.to/sonia_bobrik_1939cdddd79d/building-digital-adventure-guides-how-developers-can-help-people-explore-the-outdoors-smarter-382m) |
| Pengguna mengeluh aplikasi mengabaikan tanjakan saat memberi estimasi waktu | ETA berbasis kemiringan (Tobler) harus terlihat di detail jalur | Ulasan HiiKER di [App Store](https://apps.apple.com/us/app/hiiker/id1470810597) |
| Studi kasus aplikasi trekking menempatkan unduhan offline dan navigasi peta sebagai inti | Sama dengan arah PRD | [UX Planet: TrekMate](https://uxplanet.org/ux-case-study-trekmate-a-mobile-experience-for-diy-trekkers-5c1b76b51147) |
| Di Indonesia, ulasan peta jalur Gunung Guntur di Avenza menyebut jalur di peta tidak sama dengan jalur sebenarnya | Tampilkan sumber dan tanggal data jalur; jangan klaim jalur pasti benar | [Avenza](https://www.avenzamaps.com/maps/851050/jalur-pendakian-gunung-guntur) |
| Prototipe aplikasi pendakian Indonesia memuat jalur, galeri foto, dan pos pendakian | Detail jalur memuat foto dan daftar pos. Koordinat dan ketinggian pos adalah tambahan dari kita | [Jurnal Nusa Mandiri](https://ejournal.nusamandiri.ac.id/index.php/inti/article/download/5601/1240) |

Catatan: ringkasan riset ini dari hasil pencarian, belum dari pemakaian langsung semua aplikasi. Tidak ada sumber yang saya temukan tentang pola peringatan keluar jalur (ambang, getar, perilaku offline). Bagian itu rancangan kita sendiri.

---

## 2. Alur utama

Tiga fase. Fase A butuh internet. Fase B dan C berjalan tanpa internet.

```
FASE A: SEBELUM BERANGKAT (online)
 Cari gunung -> Pilih jalur -> Lihat detail jalur -> Unduh paket gunung

FASE B: DI JALUR (offline, layar penuh)
 Mulai -> Navigasi di peta -> [Keluar jalur?] -> Tandai titik -> Istirahat/jeda

FASE C: SELESAI
 Akhiri -> Ringkasan -> Simpan atau ekspor -> Riwayat
```

### Fase A: Sebelum berangkat

| Langkah | Layar | Yang pengguna lakukan | Fitur |
|---|---|---|---|
| 1 | **Jelajah** | Mengetik nama gunung di kolom cari, atau memilih dari daftar | Cari gunung; daftar gunung dengan foto, ketinggian, jumlah jalur |
| 2 | **Detail gunung** | Melihat jalur yang tersedia | Daftar jalur: nama, jarak, estimasi waktu, tingkat kesulitan, total tanjakan |
| 3 | **Detail jalur** | Menilai apakah cocok | Foto jalur, peta mini, profil elevasi, basecamp, daftar pos (nama, ketinggian), sumber dan tanggal data |
| 4 | **Unduh paket** | Mengunduh peta dan elevasi gunung | Ukuran paket tampil sebelum unduh; progres; status "siap offline" |
| 5 | Kembali ke detail jalur | Tombol **Mulai** aktif | Tombol Mulai hanya aktif penuh bila paket sudah diunduh |

### Fase B: Di jalur

| Langkah | Layar | Yang terjadi | Fitur |
|---|---|---|---|
| 6 | **Persiapan mulai** | Cek cepat sebelum jalan | Status GPS (satelit, akurasi), paket siap, baterai, tombol **Mulai pendakian** |
| 7 | **Navigasi** (layar penuh, tanpa tab bar) | Peta dengan posisi, rute hijau, jejak biru | Statistik berjalan (jarak, waktu, tinggi, sisa jarak, ETA), tombol jeda, tombol tandai titik, status GPS ringkas |
| 8 | **Peringatan keluar jalur** | Muncul bila menyimpang | Banner besar, getar, notifikasi; arah dan jarak ke titik terdekat di jalur; tombol "Mengerti" |
| 9 | **Tandai titik** | Menyimpan posisi | Satu ketukan, nama otomatis, bisa diubah nanti |
| 10 | **Jeda** | Istirahat | Waktu bergerak terpisah dari waktu istirahat; lanjutkan atau akhiri |

### Fase C: Selesai

| Langkah | Layar | Yang terjadi | Fitur |
|---|---|---|---|
| 11 | **Akhiri** | Konfirmasi | Dialog konfirmasi satu langkah, bisa batal |
| 12 | **Ringkasan** | Hasil pendakian | Jarak, durasi (total dan bergerak), total naik dan turun, profil elevasi dengan jejak aktual, peta jejak, daftar titik |
| 13 | **Simpan atau ekspor** | Menyimpan | Simpan otomatis ke riwayat; ekspor GPX dan CSV |
| 14 | **Riwayat** | Membuka pendakian lama | Daftar rekaman; buka ringkasan lagi |

---

## 3. Navigasi aplikasi

Bottom nav 5 tujuan (batas aman 5), Jelajah di tengah sebagai tombol utama. Layar Navigasi saat mendaki dibuka penuh tanpa bottom nav, supaya peta lega dan tidak ada ketukan yang tidak sengaja.

| Tab | Isi |
|---|---|
| **Beranda** | Sapaan, kolom cari, Gunung terdekat, gunung lain, rekomendasi jalur |
| **Jelajah** (tengah) | Cari dan daftar semua gunung, peta sebaran gunung, detail gunung dan jalur |
| **Unduhan** | Paket yang sudah diunduh, ukuran, hapus |
| **Riwayat** | Pendakian yang sudah direkam, titik tersimpan |
| **Pengaturan** | Izin, satuan, atribusi data, tentang |

Aturan: tombol kembali selalu memulihkan posisi gulir dan filter. Dari layar Navigasi, kembali tidak menutup rekaman; pengguna harus memilih **Akhiri** secara sadar.

---

## 4. Daftar layar dan prioritas

| # | Layar | Prioritas | Cakupan PRD |
|---|---|---|---|
| 1 | Onboarding dan izin | P0 | US-09 |
| 2 | Jelajah (cari dan daftar gunung) | P0 | **Baru** |
| 3 | Detail gunung | P0 | **Baru** |
| 4 | Detail jalur (foto, profil, pos, ETA) | P0 | US-08 + baru |
| 5 | Unduh paket | P0 | US-03 |
| 6 | Persiapan mulai (status GNSS) | P0 | US-01 |
| 7 | Navigasi | P0 | US-02, US-04, US-05 |
| 8 | Peringatan keluar jalur | P0 | US-06 |
| 9 | Tandai titik dan daftar titik | P0 | US-07 |
| 10 | Ringkasan pendakian | P0 | **Baru** |
| 11 | Riwayat | P0 | **Baru** |
| 12 | Unduhan (kelola paket) | P1 | US-03 |
| 13 | Skyplot dan detail satelit | P1 | US-01 |
| 14 | Pengaturan dan tentang (atribusi) | P0 | PRD 4 (atribusi) |
| 15 | Impor GPX manual | P1 | US-05 |

---

## 5. Celah antara PRD dan UX

PRD v0.2 punya mesin GPS, tetapi belum punya **katalog**. Alur "cari gunung, pilih jalur" butuh data yang belum ada di PRD.

| Celah | Kenapa penting | Usulan |
|---|---|---|
| Katalog gunung dan jalur | Tanpa ini tidak ada yang bisa dicari | Berkas JSON ikut dalam paket, diisi manual untuk 1 sampai 2 gunung (contoh: Merbabu dengan jalur Selo, Suwanting, Thekelan, Wekas; data tim harus dicek ulang) |
| Rute referensi per jalur | Deteksi keluar jalur butuh polyline | Satu berkas GPX per jalur, ikut dalam paket |
| Basecamp dan pos | Dipakai di detail jalur dan arah pulang | Daftar titik di JSON jalur: nama, koordinat, ketinggian |
| Foto per jalur | Permintaan desain: foto asli, bukan ilustrasi | 1 foto utama dan 2 sampai 3 foto galeri per jalur, ikut dalam paket |
| Layar ringkasan dan riwayat | Alur selesai belum ada | Tambah ke PRD sebagai US baru, P0 |
| Tombol Mulai tanpa paket | Pengguna bisa lupa unduh | Mulai tetap bisa, dengan peringatan "peta tidak tersedia, hanya posisi dan jejak" |

### Keputusan data baru (TBD)

1. **Sumber foto asli.** Foto harus legal dan ikut paket offline. Pilihan: foto sendiri dari tim, Wikimedia Commons (cek lisensi dan atribusi tiap foto), atau Unsplash dan Pexels (cek lisensi tiap foto). Foto berukuran besar, jadi kompres ke WebP dan batasi jumlahnya. Belum diverifikasi.
2. **Siapa yang mengisi data jalur.** Jalur tidak boleh dikarang. Data harus berasal dari rekaman tim sendiri atau sumber yang berlisensi jelas.
3. **Jumlah gunung untuk MVP.** Usulan: satu gunung, dua sampai tiga jalur.

---

## 6. Kondisi khusus yang harus dirancang

| Kondisi | Perilaku yang diharapkan |
|---|---|
| GPS belum dapat fix | Layar Persiapan menampilkan "mencari satelit" dan tombol Mulai tetap bisa ditekan setelah ada konfirmasi |
| Izin lokasi ditolak | Layar kosong dengan penjelasan dan tombol ke pengaturan |
| Penyimpanan penuh saat unduh | Pesan jelas, unduhan tidak dimulai |
| Sinyal GPS lemah di hutan | Banner "sinyal GPS lemah"; peringatan keluar jalur ditunda |
| Aplikasi dimatikan sistem saat mendaki | Rekaman yang sudah tersimpan tidak hilang; saat dibuka lagi, tawarkan melanjutkan |
| Baterai di bawah 15% | Banner saran menghemat baterai (angka *Usulan*, belum dibahas) |
| Pengguna menekan kembali saat mendaki | Rekaman tetap jalan; ada dialog sebelum mengakhiri |
| Tiba di akhir rute | Tawarkan "Akhiri pendakian" |

---

## 7. Langkah berikutnya

1. Kamu menyetujui alur dan daftar fitur ini, atau mengubahnya.
2. Aku menulis `design.md`: palet terang bertema camp dari referensimu, tipografi, komponen, aturan foto asli, dan prinsip gerak. Skill yang dipakai: ui-ux-pro-max, apple-design (minimalis), dan stop-slop untuk menyunting teksnya.
3. Kamu menyetujui `design.md`.
4. Baru setelah itu desain di Figma.
