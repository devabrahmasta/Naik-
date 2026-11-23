# Tools: Data Preparation (Laptop)

Folder ini berisi skrip persiapan data spasial offline yang dijalankan di laptop (bukan di dalam aplikasi Android). Hasil berkas kemudian dipindahkan/disalin ke penyimpanan ponsel sesuai kebutuhan.

## 1. Peta Raster MBTiles (D1)
- **Sumber:** OpenStreetMap (OSM) via QGIS.
- **Tingkat Zoom:** Zoom level 12 hingga 16 untuk area gunung target (mis. Merbabu).
- **Format:** SQLite Raster MBTiles (`.mbtiles`).
- **Peringatan Kebijakan:** Jangan melakukan *bulk download* massal langsung dari server OSM publik (melanggar Tile Usage Policy OSM). Buat tile secara lokal atau gunakan ekstrak regional. Wajib menyertakan atribusi `© OpenStreetMap contributors`.

## 2. Data Elevasi SRTM (D3)
- **Sumber:** AWS Terrain Tiles (format Skadi) atau NASA/USGS SRTM 1″ (~30m).
- **Format:** Berkas `.hgt` (1x1 derajat) mencakup area koordinat target.
- **Penggunaan:** Disalin ke perangkat untuk dibaca oleh modul elevasi dan kalkulasi fungsi Tobler ETA offline.
