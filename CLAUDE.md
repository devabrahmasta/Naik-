# HikeNav Developer Guide & Project Instructions (`CLAUDE.md`)

Selamat datang di repositori monorepo **HikeNav** (Navigasi pendakian offline berbasis GNSS untuk Android). Dokumen ini berfungsi sebagai pedoman kerja tim, aturan arsitektur, kepemilikan kode (*code ownership*), dan kontrak antar modul.

---

## 1. Arsitektur Monorepo & Struktur Direktori

Proyek ini menggunakan **Dart Pub Workspace** (Dart 3.6+ / Flutter 3.x) dalam satu repositori:

```
hikenav/
├── apps/
│   └── mobile/                  # Aplikasi Flutter + modul native Android (Kotlin)
│       ├── lib/
│       │   ├── core/            # Database (SQLite), notifikasi/getar, platform channel
│       │   └── features/        # Fitur per modul UI
│       │       ├── gnss/        # US-01 Status satelit & skyplot
│       │       ├── map/         # US-02, US-03 Peta offline MBTiles & unduh area
│       │       ├── tracking/    # US-04 Perekaman jejak
│       │       ├── route/       # US-05, US-06 Impor GPX & deteksi keluar jalur
│       │       ├── waypoint/    # US-07 Penandaan titik/pos
│       │       ├── elevation/   # US-08 Profil elevasi SRTM & Tobler ETA
│       │       └── onboarding/  # US-09 Edukasi & permintaan izin lokasi
│       ├── test/                # Widget & integration test Flutter
│       └── android/             # Native Kotlin: GnssStatus, SensorManager, Foreground Service
├── packages/
│   └── geo_core/                # Package Dart MURNI (algoritma matematika spasial)
│       ├── lib/
│       │   ├── geo_core.dart
│       │   └── src/
│       │       ├── gating/      # L1: Gating kualitas fix (A_max = 30m, V_max = 5m/s)
│       │       ├── projection/  # L2: Proyeksi bidang lokal Equirectangular
│       │       ├── cross_track/ # L3: Jarak ke polyline & deteksi keluar jalur adaptif
│       │       ├── elevation/   # L4: Interpolasi bilinear raster SRTM
│       │       └── eta/         # L4: Tobler's Hiking Function
│       └── test/                # Unit test murni & test replay log CSV lapangan
├── tools/
│   └── data_prep/               # Skrip laptop: potong tile MBTiles & siapkan SRTM .hgt
├── data/
│   ├── logs/                    # Contoh log CSV GPS untuk pengujian replay
│   └── routes/                  # Contoh rute referensi format GPX
├── docs/                        # PRD, alur UX, dan spesifikasi desain visual
├── pubspec.yaml                 # Root workspace manifest
└── CLAUDE.md                    # File panduan ini
```

---

## 2. Aturan Ketergantungan (*Dependency Rules*)

Untuk memastikan kode modular, mudah diuji, dan tidak kusut, patuhi aturan ketergantungan satu arah berikut:

1. **`packages/geo_core` HARUS murni Dart:**
   * ❌ **DILARANG KERAS** mengimpor `flutter/*`, `package:flutter`, pustaka UI, Android native, atau SQLite di `packages/geo_core`.
   * ✅ `geo_core` hanya menerima angka primitif (`lat`, `lon`, `accuracy`, `timestamp`, dll.) dan mengembalikan keputusan matematis. Semua tes di folder ini harus bisa berjalan cepat dengan `dart test` di laptop tanpa emulator/perangkat Android.
2. **`apps/mobile/android` (Kotlin) hanya bertindak sebagai produser data sensor:**
   * Kotlin tidak boleh berisi logika keputusan bisnis/navigasi (seperti status keluar jalur).
   * Peran Kotlin: membaca sensor hardware (`LocationManager`, `GnssStatus`, `SensorManager`) dan menjaga proses tetap hidup dengan Android *Foreground Service*.
3. **Arah ketergantungan UI:**
   * `features (UI) -> core (database, platform) -> geo_core`.

---

## 3. Pembagian Tugas & Penjaga Kode (*Code Owners*)

Setiap perubahan kode (*Pull Request*) wajib ditinjau/disetujui oleh penjaga folder terkait:

| Anggota | Area Tanggung Jawab Utama | Penjaga Direktori (*Code Owner*) |
|---|---|---|
| **Deva** | **US-06** Keluar jalur, **US-05** Muat GPX, **US-07** Waypoint, **US-10** Log CSV & Replay | `packages/geo_core/` |
| **Lintang** | **US-04** Perekaman & Foreground Service, **US-01** Status GNSS, **US-11** Kompas | `apps/mobile/android/` (Kotlin) & `lib/core/platform/` |
| **Ariz** | **US-08** Profil Elevasi & Tobler ETA, **US-02** Peta Offline, **US-03** Unduh Area, **US-09** Izin | `apps/mobile/lib/features/*` & `tools/` |

---

## 4. Parameter Inti Algoritma Spasial (Keputusan Tim D5)

* **Interval Sampling (L0):** 2 detik untuk deteksi; titik baru disimpan ke rekaman hanya jika perpindahan $\ge 5\text{ m}$.
* **Gating Fix (L1):**
  * $A_{max} = 30\text{ m}$ (fix dengan akurasi lebih buruk dari ini ditolak/hanya masuk log).
  * $V_{max} = 5\text{ m/s}$ (kecepatan jalan kaki/tanjakan maksimum wajar).
  * Pemulihan: jika $\ge 5$ fix berturut-turut ditolak karena $V_{max}$ dan fix terbaru $\le A_{max}$, maka fix tersebut menjadi acuan baru.
* **Proyeksi Lokal (L2):** Equirectangular sekitar titik acuan rute:
  $$x = R \cdot (\lambda - \lambda_0) \cdot \cos(\phi_0), \quad y = R \cdot (\phi - \phi_0)$$
* **Deteksi Keluar Jalur Adaptif (L3):**
  * Ambang batas: $T = \max(30\text{ m},\ 2 \times \text{akurasi})$.
  * Keluar jalur jika $d > T$ pada $\ge 5$ fix berturut-turut dan $\ge 15\text{ detik}$.
  * Kembali ke jalur jika $d < 0{,}7 \cdot T$ pada 3 fix berturut-turut.
  * Pola getaran peringatan: $3 \times 400\text{ ms}$, diulang setiap 60 detik.
* **Elevasi & Estimasi Waktu (L4):**
  * Interpolasi bilinear dari raster SRTM 1″.
  * Tobler Hiking Function: $W = 6 \cdot e^{-3{,}5 \cdot |S + 0{,}05|} \text{ km/jam}$ ($S = \text{slope}$).

---

## 5. Kontrak Platform Channel (Kotlin <-> Dart)

1. **Method Channel (`com.hikenav/gnss_control`):**
   * `startTrackingService()` $\rightarrow$ mengaktifkan foreground service tipe `location`.
   * `stopTrackingService()` $\rightarrow$ mematikan foreground service.
2. **Event Channel Fix GNSS (`com.hikenav/gnss_fix_stream`):**
   * Mengirim map: `{latitude: double, longitude: double, altitude: double, accuracy: double, speed: double, bearing: double, satellitesUsed: int, satellitesVisible: int, timestamp: int, isMock: bool}`.
3. **Event Channel Kompas (`com.hikenav/compass_stream`):**
   * Mengirim derajat azimuth: `double` (0.0 - 360.0).

---

## 6. Perintah Build, Test, dan Alur Kerja Git

### Testing & Quality Check
Jalankan perintah ini secara rutin sebelum membuat commit:

```bash
# 1. Jalankan unit test algoritma inti geo_core
dart test packages/geo_core

# 2. Jalankan widget & unit test aplikasi mobile
flutter test apps/mobile

# 3. Analisis kode (linter)
dart analyze packages/geo_core
flutter analyze apps/mobile
```

### Git Branching
* Branch `main` dilindungi (*protected*).
* Buat branch baru untuk tiap fitur: `feature/us-01-gnss-status`, `feature/us-06-off-route`, dll.
* Pastikan seluruh test lolos sebelum membuat pull request / merge.
