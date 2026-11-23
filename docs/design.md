# HikeNav: Design (v0.2)

Platform: Android, mobile saja, mode terang saja. Acuan alur: `HikeNav_UX_v0.1.md`. Acuan gaya: aplikasi camp (referensi gambar 1) untuk semua layar, dan tata letak layar navigasi dari referensi gambar 2 dengan gaya terang gambar 1. Ilustrasi diganti foto asli.

Figma: halaman **Screens v2** (aktif) dan **Screens** (v1, arsip).

## 1. Prinsip

1. **Foto membawa suasana, peta dan angka membawa informasi.** Foto asli tampil di header dan kartu. Saat mendaki, layar berisi peta, kompas, dan angka.
2. **Satu aksi utama per layar.** Satu tombol pil terisi. Aksi lain berupa pil tonal, tombol ikon bulat, atau teks.
3. **Tanpa garis tepi.** Kartu dipisahkan dengan warna permukaan dan bayangan lembut, bukan garis.
4. **Saat keluar jalur, layar menampilkan satu banner, satu panah kompas, dan satu tombol.** Pendaki yang baru sadar salah jalan sedang tegang.
5. **Offline adalah keadaan normal.** Tidak ada spinner menunggu jaringan setelah paket diunduh.

## 2. Foto

| Aturan | Nilai |
|---|---|
| Header layar (Jelajah, Detail gunung, Detail jalur, Persiapan, Ringkasan) | Foto penuh lebar, tinggi 280 sampai 350, dengan lembar konten krem yang menumpuk di atasnya (radius atas 28) |
| Kartu (Gunung terdekat, rekomendasi, riwayat, baris jalur) | Foto dengan radius 14 sampai 24 |
| Lingkaran gunung lain | Foto bulat 64 dp |
| Galeri | Penghitung foto "1 / 3" di Detail jalur |
| Teks di atas foto | Gradien gelap 40 sampai 70% di belakang teks putih. Kontras diperiksa per foto |
| Sumber saat desain | 6 foto Wikimedia Commons, CC BY-SA 4.0, di `assets/photos/`, atribusi di `assets/photos/ATTRIBUTION.md` |
| Sumber di aplikasi | Belum diputuskan. Foto per jalur sebaiknya foto tim sendiri agar sesuai jalur aslinya |
| Format dan ukuran | WebP, maksimal 300 KB per foto, maksimal 3 foto per jalur, ikut paket offline |
| Foto belum tersedia | Blok warna `tonal` dengan ikon gunung |

## 3. Warna

| Token | Hex | Pemakaian | Kontras |
|---|---|---|---|
| `bg` | `#F6F4EE` | Latar layar dan lembar konten | |
| `surface` | `#FFFFFF` | Kartu, tombol ikon, bottom nav | |
| `ink` | `#1F2A1C` | Teks utama, pil gelap ("Lihat jalur", "Peta") | 13,8:1 pada `bg` |
| `ink-2` | `#5B6555` | Teks sekunder | 5,6:1 pada `bg` |
| `primary` | `#5A7834` | Pil utama, FAB, latar ikon aktif | Putih di atasnya 5,0:1 |
| `primary-text` | `#4E6B2F` | Teks hijau di atas `tonal` atau `bg` | Dipakai karena `primary` di atas `tonal` hanya 4,1:1 |
| `tonal` | `#E4EBD3` | Kartu Gunung terdekat, pil tonal, lingkaran ikon | `ink` di atasnya 12,2:1 |
| `accent` | `#B8570F` | Pil dan ikon peringatan keluar jalur | Putih di atasnya 4,8:1 |
| `accent-text` | `#8A3F08` | Teks oranye, tautan "Baca selengkapnya" | 6,3:1 pada `warn-bg` |
| `warn-bg` | `#FCE9D2` | Banner keluar jalur | |
| `danger` | `#B3261E` | Hapus, galat | Putih di atasnya 6,5:1 |
| `route` | `#3E8E3A` | Rute referensi di peta (garis titik-titik) | Grafik |
| `track` | `#2563C9` | Jejak aktual di peta (garis penuh) | Grafik |
| `divider` | `#E3E1D6` | Pegangan sheet dan garis grafik saja | |

`accent` tidak dipakai sebagai teks di atas `bg` (4,4:1). Warna tidak membawa makna sendirian: peringatan memakai ikon dan teks, tab aktif memakai warna dan huruf tebal.

## 4. Tipografi

Plus Jakarta Sans, mengikuti kesan ramah gambar 1. Font ikut terbundel di aplikasi (menambah ukuran) dan harus bisa dimuat offline.

| Gaya | Ukuran / baris | Berat | Tracking |
|---|---|---|---|
| Display | 32 / 38 | Bold | -2% |
| Title | 24 / 30 | Bold | -1,5% |
| Headline | 17 / 24 | SemiBold | -0,5% |
| Body | 16 / 24 | Regular | 0 |
| Label | 14 / 20 | SemiBold | 0 |
| Caption | 12 / 16 | Medium | 0 |

Angka statistik memakai angka tabular. Teks bisa diperbesar sampai 200% tanpa terpotong.

## 5. Bentuk, jarak, kedalaman

| Aspek | Nilai |
|---|---|
| Grid jarak | 4 dp; langkah umum 8, 12, 16, 20, 24 |
| Margin layar | 16 dp (20 dp di Detail jalur) |
| Radius | Lembar konten 28, kartu 20 sampai 24, foto kecil 14, pil dan tombol ikon 999 |
| Garis tepi | Tidak ada |
| Bayangan `card` | y 6, blur 20, hitam kehijauan 7% |
| Bayangan `float` | y 10, blur 28, 12%: kolom cari, pil "Peta", tombol Jelajah, banner |
| Bayangan `up` | y -6, blur 24, 8%: bottom nav |
| Target sentuh | Minimal 48 × 48 dp. Tombol ikon tampil 44 dp dengan area sentuh 48 dp |
| Ikon | Satu keluarga ikon garis, tebal 2, ukuran 16 sampai 24 dp. Tidak memakai emoji |

## 6. Komponen

| Komponen | Spesifikasi |
|---|---|
| **Pill button** | Tinggi 52, radius penuh. Varian: Primary, Tonal, Accent, Dark |
| **Icon button** | Lingkaran putih 44 dp, bayangan `card`. Varian: kembali, simpan, bagikan, peta, pusatkan, GPS |
| **Bottom nav** | 5 tujuan: Beranda, Unduhan, **Jelajah** (tombol bulat hijau di tengah dengan ikon kompas dan label), Riwayat, Pengaturan. Radius atas 24, bayangan `up`. Tab aktif: ikon dan label `ink` tebal |
| **Kolom cari** | Pil putih 52 dp di atas foto header, ikon cari dan ikon filter |
| **Kartu Gunung terdekat** | Latar `tonal`, radius 24, judul, jarak dari posisi, pil gelap "Lihat jalur", foto 92 dp |
| **Info tile** | Lingkaran `tonal` 40 dp dengan ikon, label kecil, nilai tebal. Grid 2 × 2 di Detail jalur |
| **Trail row** | Kartu putih radius 20: foto 72 dp, nama, jarak dan waktu dan tanjakan, chip kesulitan, chevron |
| **Badge angka** | Kotak `tonal` radius 14: angka besar dan satuan ("3.145 mdpl", "9,2 km") |
| **Banner keluar jalur** | Latar `warn-bg`, radius 20, ikon di lingkaran `accent`, judul `accent-text`, satu kalimat |
| **Sheet detail pendakian** | Lembar krem radius 28: dua tile (Durasi, Jarak, masing-masing dengan sisa), kartu kompas, dua pil |
| **Kompas** | Lingkaran dengan tanda tiap 10°, huruf U T S B, arah hadap di tengah. Saat keluar jalur, panah oranye menunjuk arah ke titik terdekat di rute |

## 7. Peta

- Rute referensi: garis titik-titik `route`. Jejak aktual: garis penuh `track` dengan tepi putih.
- Posisi pengguna: titik `track` bercincin putih dengan lingkaran akurasi transparan.
- Layar navigasi mengikuti gambar 2: peta di atas, sheet detail di bawah. Tombol kembali, judul jalur, dan status GPS melayang di atas peta.
- Atribusi OpenStreetMap contributors tampil di layar Tentang dan di sudut peta.

## 8. Layar (Figma, Screens v2)

| # | Layar | Isi utama |
|---|---|---|
| 1 | Izin | Foto header memudar ke krem, judul, penjelasan, pil "Izinkan lokasi" |
| 2 | Beranda | Foto header, sapaan, kolom cari, Gunung terdekat, lingkaran gunung lain, rekomendasi jalur, pil "Peta", bottom nav |
| 3 | Detail gunung | Foto header, badge tinggi, daftar trail row |
| 4 | Detail jalur | Foto dan penghitung galeri, badge jarak, deskripsi, grid info tile, pil "Unduh paket" dan tombol peta |
| 5 | Unduh paket | Kartu foto paket, daftar isi paket, progres, pil "Jeda unduhan" |
| 6 | Persiapan mulai | Foto header, status GPS, daftar periksa, pil "Mulai pendakian" |
| 7 | Navigasi | Peta, sheet detail pendakian dengan kompas, pil "Jeda" dan "Tandai titik" |
| 8 | Navigasi, keluar jalur | Banner, kompas dengan panah ke jalur, pil "Mengerti" |
| 9 | Tandai titik | Peta dengan scrim, sheet nama titik dan koordinat |
| 10 | Ringkasan | Foto header, dua tile besar, tiga statistik, profil elevasi, ekspor CSV dan GPX |
| 11 | Riwayat | Kartu foto per pendakian, bottom nav |
| 12 | Pengaturan dan Tentang | Grup Umum dan Tentang (atribusi peta, data tinggi, foto), bottom nav |

## 9. Gerak

- Durasi 150 sampai 300 ms. Keluar lebih singkat daripada masuk (sekitar 65%).
- Pegas teredam penuh sebagai bawaan. Pantulan kecil hanya untuk sheet yang dilempar.
- Semua gerak bisa diinterupsi. Sheet mengikuti jari dan melanjutkan dengan kecepatan lepasan.
- Foto header bergeser sedikit lebih lambat daripada konten saat digulir (paralaks halus), dan berhenti bila pengguna memilih kurangi gerak.
- Getar hanya untuk: mulai, akhiri, tandai titik, dan peringatan keluar jalur. Keluar jalur memakai pola 3 × 400 ms, diulang tiap 60 dtk selama masih di luar jalur (catatan di bawah layar 08 di Figma).
- Kurangi gerak: transisi pudar singkat, kamera peta berpindah tanpa animasi terbang.

## 10. Aksesibilitas

- Kontras teks ≥ 4,5:1, grafik dan ikon ≥ 3:1 (Bagian 3).
- Target sentuh ≥ 48 dp. Ikon tanpa teks punya label bacaan.
- Peringatan keluar jalur dibacakan otomatis oleh pembaca layar.
- Layar Navigasi bisa dipakai dengan tangan basah atau bersarung: pil besar, tidak ada aksi yang hanya lewat gestur.

## 11. Dampak ke PRD (perlu diputuskan)

Desain v2 menambah hal yang belum ada di `HikeNav_PRD_v0.2.md`:

1. **Gunung terdekat:** dihitung offline dari posisi GPS dan katalog gunung di ponsel. Belum masuk PRD.
2. **Kompas dan getar keluar jalur:** disetujui, sudah masuk PRD sebagai US-11 dan tambahan di US-06.
3. **Rekam cepat:** dibatalkan. Tombol tengah sekarang Jelajah.
4. **Galeri foto per jalur dan font terbundel:** dibiarkan dulu, dievaluasi saat implementasi apakah ukuran aplikasi dan paket masih wajar.

## 12. Yang belum diputuskan

1. Sumber foto per jalur untuk aplikasi (foto tim atau sumber berlisensi).
2. Keluarga ikon untuk implementasi (harus satu keluarga garis).
3. Angka ambang baterai rendah.
4. Hal-hal di Bagian 11.

## 13. Catatan implementasi Flutter

- Daftar panjang memakai `ListView.builder`.
- Navigasi memakai `go_router` dengan argumen rute bertipe.
- Titik peta yang rapat digabung menjadi kluster pada zoom jauh.
