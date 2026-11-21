# Graph Report - project  (2026-11-21)

## Corpus Check
- Corpus is ~11,666 words - fits in a single context window. You may not need a graph.

## Summary
- 81 nodes · 71 edges · 19 communities (11 shown, 8 thin omitted)
- Extraction: 72% EXTRACTED · 28% INFERRED · 0% AMBIGUOUS · INFERRED: 20 edges (avg confidence: 0.84)
- Token cost: 616,965 input · 0 output

## Community Hubs (Navigation)
- Desain dan data elevasi
- Dokumen dan atribusi foto
- Pipeline GPS keluar jalur
- Arsitektur Geo Core monorepo
- Foto lereng hijau Merbabu
- Alur UX dan layar
- Foto sabana Merbabu
- Foto jalur Suwanting
- Foto pemandangan Merbabu
- Foto Sindoro
- Foto Sumbing
- KPI dan evaluasi
- Sumber peta dan kebijakan OSM
- Prinsip gerak
- Tipografi

## God Nodes (most connected - your core abstractions)
1. `HikeNav PRD v0.2` - 5 edges
2. `Merbabu Green Hillside Photo` - 5 edges
3. `Geo Core (Dart murni)` - 4 edges
4. `L3 Keluar jalur (5 fix, 15 dtk, 0,7T)` - 4 edges
5. `A1 Gating kualitas fix (A_max, V_max)` - 3 edges
6. `A3 Deteksi keluar jalur adaptif dengan histeresis` - 3 edges
7. `Data elevasi SRTM` - 3 edges
8. `packages/geo_core` - 3 edges
9. `Daftar 15 layar dan prioritas` - 3 edges
10. `6 foto gunung (Merbabu, Sumbing, Sindoro)` - 3 edges

## Surprising Connections (you probably didn't know these)
- `A1 Gating kualitas fix (A_max, V_max)` --semantically_similar_to--> `L1 Gating fix`  [INFERRED] [semantically similar]
  HikeNav_PRD_v0.1.md → HikeNav_PRD_v0.2.md
- `A2 Proyeksi bidang lokal (ENU/ekuirektangular)` --semantically_similar_to--> `L2 Bidang lokal`  [INFERRED] [semantically similar]
  HikeNav_PRD_v0.1.md → HikeNav_PRD_v0.2.md
- `A3 Deteksi keluar jalur adaptif dengan histeresis` --semantically_similar_to--> `L3 Keluar jalur (5 fix, 15 dtk, 0,7T)`  [INFERRED] [semantically similar]
  HikeNav_PRD_v0.1.md → HikeNav_PRD_v0.2.md
- `A4 Elevasi SRTM bilinear dan koreksi geoid` --semantically_similar_to--> `L4 Elevasi dan ETA Tobler`  [INFERRED] [semantically similar]
  HikeNav_PRD_v0.1.md → HikeNav_PRD_v0.2.md
- `A5 ETA fungsi Tobler terkalibrasi` --semantically_similar_to--> `L4 Elevasi dan ETA Tobler`  [INFERRED] [semantically similar]
  HikeNav_PRD_v0.1.md → HikeNav_PRD_v0.2.md

## Hyperedges (group relationships)
- **Pipeline pemrosesan satu fix GNSS** — hikenav_prd_v0_1_gating_fix, hikenav_prd_v0_1_local_plane_projection, hikenav_prd_v0_1_off_route_detection [EXTRACTED 1.00]
- **Fondasi sistem desain HikeNav** — design_color_tokens, design_typography, design_components, design_map_styling [EXTRACTED 1.00]
- **Rantai dokumen PRD, UX, dan Design** — hikenav_prd_v0_1_document, hikenav_prd_v0_2_document, hikenav_ux_v0_1_document, design_document [INFERRED 0.95]

## Communities (19 total, 8 thin omitted)

### Community 0 - "Desain dan data elevasi"
Cohesion: 0.17
Nodes (6): Aksesibilitas (kontras, target sentuh), Token warna (bg, primary, accent, route, track), Komponen UI (pill button, bottom nav, banner, kompas), Gaya peta (rute titik-titik, jejak penuh), Prinsip offline-first, Data elevasi SRTM

### Community 1 - "Dokumen dan atribusi foto"
Cohesion: 0.20
Nodes (11): Lisensi CC BY-SA 4.0, Atribusi foto Wikimedia Commons, 6 foto gunung (Merbabu, Sumbing, Sindoro), HikeNav Design v0.2, Aturan foto asli, Dampak desain ke PRD (kompas, rekam cepat, galeri), HikeNav PRD v0.1.1, Temuan peninjauan Laporan Tahap 1 (Lampiran C) (+3 more)

### Community 3 - "Arsitektur Geo Core monorepo"
Cohesion: 0.29
Nodes (5): Geo Core (Dart murni), Modul native Kotlin (GnssStatus, foreground service), Uji replay log GNSS, packages/geo_core, Struktur monorepo hikenav

### Community 4 - "Foto lereng hijau Merbabu"
Cohesion: 0.47
Nodes (6): Merbabu Green Hillside Photo, Campsite Tents on Hillside, Pale Blue Sky over Ridgeline, Eroded Dirt Hiking Trail with Climbers, Steep Green Savanna Slope, Grass, Shrubs and Scattered Trees

### Community 5 - "Alur UX dan layar"
Cohesion: 0.40
Nodes (5): 12 layar Figma Screens v2, Navigasi bottom tab 4 item, Daftar 15 layar dan prioritas, Kondisi khusus (GPS, izin, baterai, penyimpanan), Alur tiga fase (sebelum berangkat, di jalur, selesai)

### Community 6 - "Foto sabana Merbabu"
Cohesion: 0.50
Nodes (4): Merbabu Sabana Photo, Open alpine grassland hiking terrain (Mount Merbabu savanna), Layered grassy ridgelines under cumulus-filled blue sky, Sunlit tussock grass savanna slope with shrubs

### Community 7 - "Foto jalur Suwanting"
Cohesion: 0.67
Nodes (4): Merbabu Suwanting Trail Photo (Mountain View with Hikers), Open grassy ridge slope with three hikers and tussock grass, Layered blue sky and cloud sea above the valley, Cloud-capped volcanic peak across the valley

### Community 8 - "Foto pemandangan Merbabu"
Cohesion: 0.67
Nodes (4): Merbabu Mountain View Photo, Clear Blue Sky (upper half of frame), Dark Forested Lower Slopes and Eroded Gullies, Grassy Ridgeline and Twin Peaks

### Community 9 - "Foto Sindoro"
Cohesion: 0.67
Nodes (4): Sindoro volcano photo from roadside, Mountain road with guardrail, street lamp, utility pole and power lines, Blue sky with altocumulus clouds and a lenticular-like cloud, Sindoro volcanic cone with truncated summit, partly wrapped in cloud

### Community 10 - "Foto Sumbing"
Cohesion: 0.67
Nodes (4): Sumbing Photo (Mount Sumbing at dusk with telecom tower), Red and white lattice telecommunication tower in foreground, Highland village with mosque gate (SJD Baiturrohman), pine tree, and Indonesian flags, Conical stratovolcano summit lit by warm sunset/sunrise light

### Community 11 - "KPI dan evaluasi"
Cohesion: 0.67
Nodes (3): Strategi evaluasi uji lapangan, KPI K1-K11, KPI K1-K5 (v0.2)

## Knowledge Gaps
- **26 isolated node(s):** `Modul native Kotlin (GnssStatus, foreground service)`, `Uji replay log GNSS`, `Strategi evaluasi uji lapangan`, `Kebijakan penggunaan tile OSM`, `Temuan peninjauan Laporan Tahap 1 (Lampiran C)` (+21 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 38 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Geo Core (Dart murni)` connect `Arsitektur Geo Core monorepo` to `Pipeline GPS keluar jalur`?**
  _High betweenness centrality (0.020) - this node is a cross-community bridge._
- **What connects `Modul native Kotlin (GnssStatus, foreground service)`, `Uji replay log GNSS`, `Strategi evaluasi uji lapangan` to the rest of the system?**
  _26 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Why does `A1 Gating kualitas fix (A_max, V_max)` connect `Pipeline GPS keluar jalur` to `Arsitektur Geo Core monorepo`?**
  _High betweenness centrality (0.019) - this node is a cross-community bridge._