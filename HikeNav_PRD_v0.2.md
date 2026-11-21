# PRD HikeNav (nama kerja)
**Navigasi pendakian offline untuk Android, berbasis GNSS**

**Versi:** 0.2 (Draft) | **Tanggal:** 2026-11-20 | **Platform:** Android, Flutter + modul Kotlin | **Backend:** tidak ada
**Status semua fitur:** ⬜ Planned (belum ada kode). `v0.1` tetap sebagai arsip dan tidak diubah.
**Dasar angka:** *Usulan* = ditetapkan tim, belum terukur. *TBD* = belum ada dasar, diputuskan tim.

---

## 1. Executive Summary

**Problem Statement.** Pendaki sering berada di area tanpa sinyal, dan aplikasi peta yang bergantung internet tidak berfungsi di sana. Di hutan dan lembah, posisi GNSS ponsel juga meleset, sehingga peringatan keluar jalur yang naif memberi alarm palsu.

**Proposed Solution.** Aplikasi Android yang menyimpan peta dan elevasi di perangkat, membaca lokasi dan status satelit tanpa internet, lalu memberi peringatan keluar jalur yang memperhitungkan akurasi fix, profil elevasi, dan estimasi waktu tempuh.

**Success Criteria.**

| ID | KPI | Target | Dasar |
|---|---|---|---|
| K1 | Latensi peringatan keluar jalur | ≤ 20 dtk setelah jarak ke jalur melewati ambang | Usulan (15 dtk konfirmasi di L3 + margin 5 dtk) |
| K2 | Alarm palsu di rekaman bawah kanopi | ≤ 1 per 5 km | Usulan |
| K3 | Fitur inti berjalan dalam mode pesawat (di luar unduhan area) | 100% | Usulan |
| K4 | Perekaman dengan layar mati selama 30 menit | Tidak ada celah > 10 dtk antar fix saat sinyal baik | Usulan (5 × interval 2 dtk) |
| K5 | Galat estimasi waktu tempuh | ≤ 20% pada ≥ 2 rute uji | Usulan |

---

## 2. User Experience & Functionality

### Persona
- **Pendaki mahasiswa:** anggaran terbatas, ponsel Android kelas menengah, butuh peta yang jalan tanpa sinyal.
- **Pendaki di jalur bercabang atau berkabut:** butuh peringatan bila salah jalur.

### User Stories & Acceptance Criteria

**US-01 Status GNSS (P0).** *Sebagai pendaki, saya ingin melihat status satelit dan akurasi agar tahu seberapa bisa dipercaya posisi saya.*
- Menampilkan jumlah satelit terlihat dan terpakai, konstelasi, C/N0, akurasi horizontal, dan skyplot.
- GPS mati atau belum ada fix: tampil "mencari satelit" dan tombol ke pengaturan lokasi.

**US-02 Posisi di peta offline (P0).** *Sebagai pendaki, saya ingin melihat posisi saya di peta tanpa internet.*
- Peta tampil dalam mode pesawat; lingkaran akurasi mengikuti akurasi fix.
- Di luar area terunduh: tampil posisi dan koordinat di kanvas kosong; tidak memuat dari internet.

**US-03 Unduh area (P0).** *Sebagai pendaki, saya ingin mengunduh peta dan elevasi satu area sebelum berangkat.*
- Pilih area, unduh, tersimpan lokal. Penyimpanan penuh: pesan jelas, unduhan tidak dimulai.
- P1: estimasi ukuran sebelum unduh dan unduhan dapat dilanjutkan.

**US-04 Rekam jalur (P0).** *Sebagai pendaki, saya ingin merekam jalur saya.*
- Jalan terus saat layar mati lewat *foreground service* dengan notifikasi permanen (K4).
- Fix yang gagal gating tidak dihitung ke jarak tetapi tetap tercatat di log.
- Aplikasi dimatikan sistem: data terekam tidak hilang.

**US-05 Muat rute referensi (P0).** *Sebagai pendaki, saya ingin memuat jalur yang harus diikuti.*
- Impor berkas GPX lokal. Berkas rusak atau kosong: pesan galat, tidak crash.

**US-06 Peringatan keluar jalur (P0).** *Sebagai pendaki, saya ingin diperingatkan saat menyimpang agar segera kembali.*
- Aturan keputusan ada di Bagian 4 (logika L3).
- Peringatan: notifikasi lokal, getar, dan banner, semuanya offline; izin notifikasi ditolak: banner dan getar tetap bekerja.
- Getar: pola 3 × 400 ms (*Usulan*), diulang bersama alarm tiap 60 dtk selama masih di luar jalur.
- Menampilkan arah dan jarak ke titik terdekat di jalur.
- Sinyal lemah (akurasi > A_max): tampil "sinyal GPS lemah", tidak ada alarm.

**US-07 Waypoint (P0).** *Sebagai pendaki, saya ingin menandai titik penting.*
- Satu ketukan menyimpan fix terakhir yang lolos gating; belum ada fix: tombol memberi pesan.
- Daftar waypoint menampilkan jarak dan arah dari posisi saat ini.

**US-08 Profil elevasi dan ETA (P0).** *Sebagai pendaki, saya ingin tahu tanjakan dan waktu tempuh.*
- Profil elevasi dari SRTM; total naik, total turun, tinggi minimum dan maksimum.
- ETA per segmen dengan fungsi Tobler (logika L4); tile SRTM belum diunduh: pesan dan tawaran unduh.
- P1: kalibrasi ETA dari kecepatan aktual.

**US-09 Izin dan penggunaan pertama (P0).** *Sebagai pengguna baru, saya ingin tahu kenapa izin diminta.*
- Penjelasan sebelum dialog izin lokasi. Izin ditolak: keadaan kosong dengan tombol ke pengaturan, tidak crash.
- Tidak memakai posisi bawaan diam-diam bila lokasi tidak tersedia.

**US-10 Log dan ekspor (P0).** *Sebagai pengembang, saya ingin mengekspor log fix agar algoritma bisa disetel dan diuji ulang.*
- Tiap fix: waktu, lat, lon, tinggi, akurasi, kecepatan, jumlah satelit terpakai, status lolos/gagal gating.
- Ekspor CSV dan GPX; tidak ada unggahan.

**US-11 Kompas dan arah ke jalur (P0).** *Sebagai pendaki, saya ingin melihat arah hadap dan arah kembali ke jalur agar tahu harus berjalan ke mana saat tersesat.*
- Kompas di sheet Navigasi menampilkan arah hadap ponsel dalam derajat dan mata angin (U, T, S, B), dari sensor magnetometer, tanpa internet.
- Saat keluar jalur (US-06), panah kompas menunjuk titik terdekat di rute (bearing dari posisi ke titik itu) beserta jaraknya.
- Ponsel tanpa magnetometer: kompas disembunyikan, arah ke jalur tetap tampil sebagai teks bearing.
- Akurasi sensor rendah: tampil ajakan kalibrasi (gerakan angka 8).

**Prioritas P1:** koordinat UTM, penghalusan Kalman, HDOP/GDOP hitung sendiri dari data satelit, koreksi geoid untuk tinggi GNSS. **P2:** penyederhanaan jejak (RDP) untuk tampilan.

### Non-Goals
- Komunikasi darurat, SOS, atau pelacakan oleh pihak lain.
- iOS dan web; akun pengguna, komunitas, dan *backend*.
- Navigasi belokan demi belokan di jalur setapak.
- Barometer, *dead reckoning*, dan pengukuran GNSS mentah (`GnssMeasurement`).
- Peta seluruh Pulau Jawa; cakupan awal satu area uji.

---

## 3. AI System Requirements

Tidak berlaku. Aplikasi tidak memakai AI/ML.

---

## 4. Technical Specifications

### Architecture Overview

```
[Satelit GNSS] -> [Chipset] -> GPS_PROVIDER + GnssStatus
                                   |
        [Kotlin: platform channel + foreground service]
                                   |
   [Flutter Geo Core (Dart murni): gating -> bidang lokal -> cross-track,
    elevasi, ETA]  <->  [SQLite: rute, rekaman, waypoint, log]
                                   |
                      [UI: peta offline, status GNSS, profil]
[Internet hanya saat unduh] -> [tile peta + tile SRTM] -> berkas lokal
```

| Lapisan | Teknologi | Peran |
|---|---|---|
| UI | Flutter | Layar peta, status GNSS, profil, daftar rekaman dan waypoint |
| Native | Kotlin (`LocationManager`, `GnssStatus`, `SensorManager`, foreground service tipe lokasi) | Lokasi GPS non-fused, status satelit, arah hadap kompas, perekaman layar mati |
| Geo Core | Dart murni, tanpa dependensi UI | Algoritma di bawah; dapat diuji unit dan diputar ulang dari log |
| Data | SQLite + berkas tile peta dan `.hgt` | Penyimpanan lokal |

### Struktur Monorepo

Satu repositori untuk seluruh proyek. Alasannya: tim 3 orang, dan aplikasi serta algoritma berubah bersamaan, jadi satu commit bisa mengubah keduanya. Geo Core juga bisa diuji di laptop tanpa ponsel.

```
hikenav/
├── apps/
│   └── mobile/                  # aplikasi Flutter
│       ├── lib/
│       │   ├── core/            # db (SQLite), notifikasi, jembatan ke Kotlin
│       │   └── features/        # satu folder per fitur
│       │       ├── gnss/        # US-01 status satelit
│       │       ├── map/         # US-02, US-03 peta offline dan unduh area
│       │       ├── tracking/    # US-04 rekam jalur
│       │       ├── route/       # US-05, US-06 rute referensi dan keluar jalur
│       │       ├── waypoint/    # US-07
│       │       ├── elevation/   # US-08 profil dan ETA
│       │       └── onboarding/  # US-09 izin
│       ├── test/
│       └── android/             # Kotlin: GnssChannel, TrackingService
├── packages/
│   └── geo_core/                # Dart murni, tanpa Flutter
│       ├── lib/src/             # gating, projection, cross_track, elevation, eta
│       └── test/                # uji unit + uji putar ulang (replay)
├── tools/
│   └── data_prep/               # skrip di laptop: siapkan tile peta dan berkas .hgt
├── data/
│   ├── logs/                    # contoh log CSV untuk uji putar ulang (kecil)
│   └── routes/                  # contoh GPX
├── docs/                        # PRD ini
└── pubspec.yaml                 # workspace akar (atau melos.yaml)
```

**Aturan ketergantungan** (satu arah, supaya mudah diuji):
```
features (UI) -> core (db, platform) -> geo_core
android/Kotlin  -> hanya mengirim data ke core lewat platform channel
geo_core        -> tidak boleh mengimpor Flutter, Android, atau SQLite
```

- `geo_core` hanya menerima angka (lat, lon, akurasi, waktu) dan mengembalikan keputusan. Karena itu ia bisa dites dengan `dart test` di laptop.
- Kotlin tidak berisi logika keputusan; ia hanya membaca GNSS dan menjalankan *foreground service*.
- `tools/data_prep` tidak ikut masuk aplikasi; ia hanya menghasilkan berkas yang disalin ke ponsel.
- Pengelola paket: Dart *pub workspace* (Dart 3.6 ke atas), tanpa Melos (D6).
- Satu `main` dilindungi, kerja lewat cabang per fitur; CI sederhana menjalankan `dart test` pada `geo_core` dan `flutter test` pada `apps/mobile`.

### Alur Data Satu Fix

```
GPS_PROVIDER (Kotlin) -> platform channel -> core/GnssService
   -> geo_core.gating -> ditolak? simpan di log saja
   -> lolos: geo_core.projection -> geo_core.cross_track(rute)
   -> status keluar jalur (L3) -> notifikasi + banner
   -> core/db: simpan titik rekaman dan log
```

### Logika Inti (Geo Core)

Algoritma inti ditulis sendiri; pustaka dipakai untuk render peta, SQLite, notifikasi, dan konversi UTM. Semua parameter berdasar *Usulan* dan disetel dari log nyata.

| ID | Logika | Aturan |
|---|---|---|
| L0 | Interval sampel | 2 dtk untuk deteksi; titik rekaman disimpan bila sudah bergerak ≥ 5 m |
| L1 | Gating fix | Tolak bila akurasi > A_max (30 m); atau kecepatan implisit > V_max (5 m/dtk) **dan** jarak implisit > jumlah akurasi kedua fix; atau sumber *mock*. Bila ≥ 5 fix berturut-turut ditolak karena V_max, fix terbaru berakurasi ≤ A_max jadi referensi baru. Fix ditolak tetap masuk log |
| L2 | Bidang lokal | Lat/lon ke meter: x = R·Δλ·cos φ0, y = R·Δφ di sekitar titik acuan rute; divalidasi terhadap Haversine di uji unit |
| L3 | Keluar jalur | d = jarak titik ke polyline rute (L2). Ambang T = max(30 m, 2 × akurasi). Keluar jalur bila d > T pada ≥ 5 fix lolos berturut-turut dan ≥ 15 dtk; kembali bila d < 0,7·T pada 3 fix berturut-turut. Alarm diulang tiap 60 dtk; ditunda saat sinyal lemah |
| L4 | Elevasi dan ETA | Tinggi dari SRTM 1″ (interpolasi bilinear, sampel tiap 30 m). Naik/turun dihitung dari SRTM dengan ambang histeresis 3 m. ETA per segmen: W = 6·exp(−3,5·\|S+0,05\|) km/jam (Tobler), S = kemiringan |

**Catatan teknis.** Tinggi GNSS Android mengacu ke ellipsoid WGS84, sedangkan SRTM ke geoid EGM96; koreksi geoid hanya untuk tinggi GNSS (P1). SRTM adalah model permukaan, jadi di bawah kanopi yang terukur adalah puncak pohon. Aplikasi tidak boleh membunyikan alarm keluar jalur saat sinyal lemah dan tidak boleh menghitung statistik dari titik hasil RDP.

### Integration Points

| Integrasi | Catatan |
|---|---|
| Android `LocationManager` dan `GnssStatus` | Offline; butuh izin lokasi. Perilaku bisa berbeda antar chipset dan versi Android |
| Sumber peta offline | **TBD, rekomendasi raster MBTiles (D1).** Server tile OSM publik tidak boleh dipakai untuk unduhan massal |
| Sumber tile SRTM | **TBD, rekomendasi AWS Terrain Tiles lewat laptop (D3)** |
| Notifikasi lokal | Offline; Android 13 ke atas butuh izin notifikasi |
| Sensor magnetometer dan getar | Offline; untuk kompas (US-11) dan pola getar keluar jalur (US-06). Tidak semua ponsel punya magnetometer |

### Security & Privacy
- Lokasi, rekaman, dan waypoint hanya di perangkat; tidak ada unggahan.
- Tidak ada kunci API di dalam aplikasi; unduhan lewat HTTPS dengan validasi sertifikat standar.
- Layar "Tentang" memuat atribusi OpenStreetMap contributors (ODbL) dan sumber SRTM.
- Peringatan sekali di awal bahwa aplikasi adalah alat bantu.

### Strategi Pengujian
- **Uji unit** Geo Core: cross-track, gating, Tobler, interpolasi bilinear, dengan hasil hitungan manual.
- **Uji putar ulang (replay):** log CSV (US-10) dimasukkan ulang ke pipeline untuk memeriksa keputusan keluar jalur dan menyetel A_max, T_min, k tanpa kembali ke lapangan. Ini seam tertinggi.
- **Uji UI minimal:** izin ditolak dan GPS mati.
- **Uji perangkat:** K1 sampai K5 di ≥ 2 ponsel Android berbeda.

---

## 5. Risks & Roadmap

### Pembagian Kerja

Dibagi per fitur dengan beban sama rata. Bobot 1 sampai 5 adalah perkiraan tim (Usulan), bukan hasil ukur. Tiap orang mendapat tepat satu fitur berat. Setup repo, `CLAUDE.md`, dan CI di minggu 0 dikerjakan bertiga.

| Orang | Fitur berat | Fitur lain | Total bobot |
|---|---|---|---|
| **Deva** | US-06 Keluar jalur (5) | US-05 Muat GPX (1), US-07 Waypoint (2), US-10 Log dan ekspor (2) | 10 |
| **Lintang** | US-04 Rekam jalur (5) | US-01 Status GNSS (3), US-11 Kompas (2) | 10 |
| **Ariz** | US-08 Elevasi dan ETA (4) | US-02 Peta offline (3), US-03 Unduh area (3), US-09 Izin (1) | 11 |

Bobot per fitur: US-04 = 5, US-06 = 5, US-08 = 4, US-01 = 3, US-02 = 3, US-03 = 3, US-07 = 2, US-10 = 2, US-11 = 2, US-05 = 1, US-09 = 1 (total 31).

**Penjaga folder** (mereview setiap perubahan di folder itu, siapa pun boleh mengubah):

| Folder | Penjaga |
|---|---|
| `packages/geo_core` | Deva |
| `apps/mobile/android` (Kotlin) | Lintang |
| `apps/mobile/lib/features/*`, `tools/` | Ariz |

**Ketergantungan dan cara menghindari tunggu-tungguan:**
- Lintang menyediakan aliran data fix lebih dulu, versi palsu yang memutar ulang log CSV, karena semua fitur memakainya.
- Deva mengerjakan US-05 (GPX) di awal karena dibutuhkan untuk menguji US-06 dan US-08.
- Ariz memakai GPX contoh sampai rute dan posisi asli siap.
- Kontrak (tanda tangan fungsi dan format pesan platform channel) disepakati dan di-merge dulu sebelum implementasi.

### Phased Rollout

| Fase | Isi |
|---|---|
| **MVP** | US-01 sampai US-11 |
| **v1.1** | UTM, Kalman, HDOP/GDOP, koreksi geoid, estimasi ukuran dan *resume* unduhan, kalibrasi ETA, *resume* rekaman |
| **v2.0** | RDP untuk tampilan |

Urutan kerja MVP: (1) pembaca GNSS via platform channel, (2) Geo Core dengan uji unit dan *replay*, (3) peta offline satu area, (4) perekaman layar mati, (5) layar-layar lainnya.

### Technical Risks

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Flutter butuh kode native untuk `GnssStatus` dan foreground service | Waktu tambahan | Kerjakan paling awal |
| Sumber peta offline terhambat lisensi atau ukuran | Tidak ada peta | Putuskan di awal; cakup satu area |
| Multipath di kanopi memicu alarm palsu | K2 gagal | Ambang adaptif, histeresis, tunda alarm saat sinyal lemah, setel lewat *replay* |
| OS menghentikan foreground service (penghemat baterai vendor) | Rekaman putus | Uji di ≥ 2 merek; arahkan pengguna mengecualikan optimasi baterai |
| Cakupan melebar | MVP tidak rampung | P1/P2 hanya setelah MVP selesai |

### Keputusan Terbuka dan Perbandingan Opsi

Rekomendasi di bawah adalah usulan; tim yang memutuskan. Tanda: ✔ = dicek advisor lewat web, ? = belum dicek, tolong cek sendiri sebelum dipakai di laporan.

**D1. Sumber peta offline**

| Opsi | Bagusnya | Jeleknya | Cocok untuk pemula? |
|---|---|---|---|
| **a. Raster MBTiles** (`flutter_map` + `flutter_map_mbtiles`) | Paling sederhana; paket MBTiles untuk flutter_map ada dan aktif ✔ | Berkas besar (puluhan sampai ratusan MB per gunung) ?; gaya peta tidak bisa diubah; tile harus dibuat sendiri | Ya |
| **b. Vektor PMTiles** (`maplibre_gl`) | Berkas kecil (beberapa MB) ?; PMTiles jalan di Android ✔ | Pakai *platform view* native; gaya JSON, font, dan ikon juga harus offline; lebih sulit di-debug | Sedang |
| **c. Vektor Mapsforge** (`mapsforge_flutter`) | Berkas siap pakai (OpenAndroMaps) dan ringkas ? | Komunitas kecil; rendering lebih lambat ?; syarat lisensi sumber belum dicek | Kurang |

**Rekomendasi: a.** Bagian yang bisa rusak paling sedikit, sisa waktu dipakai untuk fitur GPS. Cara membuat: QGIS (data OSM) lalu ekspor XYZ tiles ke MBTiles untuk satu area, zoom 12 sampai 16 ?. Jangan unduh massal dari server tile OSM (dilarang kebijakan mereka ?), dan cantumkan atribusi OpenStreetMap contributors.

**D2. Sumber rute referensi**

| Opsi | Bagusnya | Jeleknya |
|---|---|---|
| **a. Impor GPX** | Paling mudah, cukup satu pembaca file | Kualitas rute tergantung GPX yang didapat |
| **b. Jalur dari data OSM** | Tidak perlu cari GPX | Jalur setapak di Indonesia sering belum lengkap atau terputus ?; perlu olah data |
| **c. Gambar manual di peta** | Tidak butuh file | Perlu UI tambahan; hasil kurang akurat |

**Rekomendasi: a.** Jalur OSM bisa menyusul lewat skrip di `tools/data_prep` yang mengekspor ke GPX, sehingga aplikasi tetap hanya membaca GPX.

**D3. Sumber data elevasi SRTM**

| Opsi | Bagusnya | Jeleknya |
|---|---|---|
| **a. Resmi USGS / NASA Earthdata** | Sumber asli, 1 detik busur (sekitar 30 m), mencakup Indonesia ✔ | Butuh akun login gratis ? |
| **b. AWS Terrain Tiles (format skadi)** | Bisa diunduh tanpa akun ✔; sumber utamanya SRTM 30 m | Wajib atribusi; teks lisensi lengkap belum dibaca |
| **c. Siapkan di laptop, salin ke HP** | Aplikasi tidak butuh internet atau login sama sekali | Ini cara pemindahan, bukan sumber; bukan fitur untuk pengguna akhir |

**Rekomendasi: b + c.** Unduh dari AWS tanpa login, potong sesuai area di `data_prep`, salin ke HP. Sebut sumbernya SRTM di laporan.

**D4. Versi Android minimum (minSdk)**

| Opsi | Bagusnya | Jeleknya |
|---|---|---|
| **API 26** | Cakupan ponsel paling luas | Perlu cabang kode untuk fitur Android baru |
| **API 29** | Sedikit lebih sederhana | Beberapa ponsel lama tidak kebagian |
| **API 31 ke atas** | Kode paling sederhana | Membuang ponsel murah lama yang masih umum ? |

Catatan: kewajiban tipe *foreground service* lokasi ditentukan oleh `targetSdk` (API 34 ke atas), bukan minSdk ✔. Altitude MSL bawaan baru ada di API 34 ✔, di bawah itu koreksi geoid hitung sendiri atau cukup pakai SRTM.

**Keputusan tim: minSdk 29 (Android 10), targetSdk terbaru.** Aplikasi tetap bisa dipasang di Android 10, tetapi dibangun mengikuti aturan Android terbaru (izin notifikasi, tipe *foreground service* lokasi). Fitur yang hanya ada di Android baru (mis. altitude MSL, API 34) diberi cabang kode atau cadangan.

**Status keputusan:** D1 sampai D6 disetujui tim (D5 dengan nilai di kolom "Dipakai sekarang").

**D5. Angka awal (Usulan) yang disesuaikan**

| Parameter | Awal v0.2 | Saran advisor | Dipakai sekarang |
|---|---|---|---|
| A_max (batas akurasi fix) | 30 m | Wajar; jangan buang dari rekaman, cukup beri tanda | 30 m |
| T_min (jarak minimum dianggap keluar jalur) | 25 m | Terlalu ketat di hutan; 30 sampai 40 m | 30 m |
| k | 2 | Wajar | 2 |
| Konfirmasi keluar jalur | 3 fix (sekitar 6 dtk) | Terlalu cepat, memicu alarm palsu; 5 fix dan minimal 15 dtk | 5 fix dan ≥ 15 dtk |
| Syarat kembali ke jalur | d < 0,8·T pada 2 fix | d < 0,7·T | d < 0,7·T pada 3 fix |
| Interval sampel | 2 dtk | Wajar untuk deteksi; simpan titik rekaman hanya bila bergerak ≥ 5 m | 2 dtk, simpan bila ≥ 5 m |

Semua tetap *Usulan*; disetel ulang lewat *replay* log nyata. Akibatnya K1 menjadi ≤ 20 dtk (15 dtk konfirmasi + margin 5 dtk).

**Alasan.** Di bawah kanopi, posisi GNSS bisa meloncat 10 sampai 30 m selama beberapa detik (perkiraan advisor, belum diukur). Aturan awal (3 fix, sekitar 6 dtk) akan menganggap loncatan itu sebagai keluar jalur dan memicu alarm palsu. Konfirmasi lebih lama dan jarak minimum lebih besar menekan alarm palsu (K2). Harganya alarm lebih lambat: 15 dtk × sekitar 1,4 m/dtk (kecepatan jalan kaki, perkiraan) ≈ 20 m tambahan sebelum alarm bunyi, yang dinilai masih wajar untuk jalur pendakian. Ambang kembali (0,7·T pada 3 fix) lebih rendah dari ambang keluar agar alarm tidak hidup-mati di sekitar batas.

**D6. Pengelola monorepo**

| Opsi | Bagusnya | Jeleknya |
|---|---|---|
| **Dart pub workspace** | Bawaan SDK (Dart 3.6 ke atas) ✔; satu lockfile untuk semua paket | Perlu `resolution: workspace` di tiap paket |
| **Melos** | Skrip lintas paket; versi 7 berjalan di atas pub workspace ✔ | Alat tambahan yang belum perlu untuk 2 paket |
| **Path dependency biasa** | Paling sederhana | Lockfile terpisah per paket |

**Rekomendasi: pub workspace tanpa Melos.**
