# Decision Log — ASTRANUSA

Dokumen ini mencatat seluruh keputusan teknis beserta statusnya. Setiap keputusan memiliki identifikasi, konteks, konsekuensi, dan tahap batas penyelesaiannya. Perubahan status keputusan memerlukan persetujuan pemilik proyek.

Status yang digunakan:

- `Accepted`: keputusan final dan mengikat.
- `Proposed`: rekomendasi arsitek, menunggu persetujuan pemilik proyek.
- `Open`: keputusan belum dibuat; tidak boleh diimplementasikan sebelum diputuskan.

## Bagian 1: Keputusan Diterima (berasal dari kebutuhan proyek)

### D-001 — Game engine: Godot 4

- Status: Accepted.
- Konteks: Proyek membutuhkan engine open source, mendukung export Android, dan dapat berjalan headless untuk CI.
- Konsekuensi: Seluruh pengembangan menggunakan Godot 4; versi minor dikunci pada SDD-01 (terkait O-001).

### D-002 — Bahasa pemrograman: GDScript

- Status: Accepted.
- Konteks: Iterasi cepat, integrasi engine langsung, ukuran APK lebih kecil untuk Android dibanding C#.
- Konsekuensi: Tidak ada kode C# dalam proyek; logika inti berbasis kelas GDScript yang dapat diuji headless.

### D-003 — Rendering: Mobile Renderer

- Status: Accepted.
- Konteks: Dioptimalkan untuk perangkat seluler sesuai target Android.
- Konsekuensi: Fitur visual dibatasi pada kemampuan Mobile Renderer; opsi Compatibility Renderer untuk perangkat kelas bawah dicatat pada O-017.

### D-004 — Platform: Android

- Status: Accepted.
- Konteks: Sesuai target rilis proyek.
- Konsekuensi: Desain UI berorientasi layar sentuh; versi Android minimum ditetapkan pada SDD-01 (terkait O-008).

### D-005 — Version control dan CI/CD: Git, GitHub, GitHub Actions

- Status: Accepted.
- Konteks: GitHub sebagai pusat source code; Actions untuk validasi dan build APK; tanpa layanan berbayar.
- Konsekuensi: Seluruh validasi berjalan di CI; kredensial hanya melalui GitHub Secrets.

### D-006 — Data konfigurasi: JSON dan Godot Resources

- Status: Accepted (prinsip; pembagian rinci melalui O-005).
- Konteks: JSON untuk data balance yang mudah diperiksa dan divalidasi; Godot Resources untuk definisi terikat aset.
- Konsekuensi: Validator data wajib ada dan berjalan pada CI (terkait O-006).

## Bagian 2: Keputusan yang Diusulkan pada SDD-00 (disetujui pemilik proyek pada 2026-10-30)

### P-001 — Root proyek Godot pada subdirektori `game/`

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: Repository memuat dokumentasi SDD dan proyek Godot. Menempatkan proyek pada subdirektori menjaga root repository tetap terstruktur dan memungkinkan dokumentasi berkembang terpisah dari runtime game.
- Konsekuensi: Workflow CI menggunakan `working-directory: game`; struktur root seperti yang tercantum pada README.

### P-002 — Struktur dokumentasi SDD seperti pada `docs/sdd/README.md`

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: Struktur dokumentasi ditetapkan pada tahap SDD-00 agar setiap tahap berikutnya memiliki tempat yang konsisten.
- Konsekuensi: Seluruh dokumen tahap mengikuti konvensi penamaan pada dokumen tersebut.

## Bagian 2B: Keputusan yang Diusulkan pada Batch Spesifikasi Update System & Data Persistence (disetujui pemilik proyek pada 2026-10-30)

### P-003 — applicationId dikunci pada `com.ndolzz.astranusa`

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: Identitas paket Android menentukan kepemilikan data aplikasi. Mengubah `applicationId` membuat Android memperlakukan APK sebagai aplikasi baru sehingga data pemain lama tidak dapat diakses.
- Konsekuensi: Nilai dikunci pada konfigurasi export dan divalidasi oleh CI; perubahan hanya melalui rencana migrasi khusus yang disetujui pemilik proyek.

### P-004 — Sumber kebenaran versi: `game/version.json`

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: `versionCode` harus meningkat setiap rilis dan tidak boleh bergantung pada nomor eksekusi CI agar dapat diaudit pada repository.
- Konsekuensi: Setiap rilis mengubah berkas ini melalui commit yang terdokumentasi; CI memvalidasi `versionCode` baru lebih tinggi dari rilis sebelumnya dan menyuntik nilainya ke export.

### P-005 — versionName mengikuti semantic versioning

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: Skema `MAJOR.MINOR.PATCH` sederhana, dapat dibaca pemain, dan selaras dengan praktik umum; pra-rilis memakai segmen `0.x.y`.
- Konsekuensi: `versionName` konsisten antara berkas versi, changelog, dan penanda rilis; divalidasi oleh CI. Keputusan ini menyelesaikan O-016.

### P-006 — Store data pemain berformat JSON dengan amplop versi dan checksum

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: Amplop `schema_version`, `app_version_written`, checksum SHA-256, dan penulisan atomik memberi fondasi migrasi dan pemulihan yang aman tanpa kompleksitas format binary.
- Konsekuensi: Data pemain mudah diperiksa dan diuji; checksum mendeteksi kerusakan; sisa lingkup proteksi anti-manipulasi tingkat lanjut tetap pada O-009.

## Bagian 3: Keputusan Terbuka

Setiap keputusan terbuka mencantumkan tahap batas: keputusan harus dibuat sebelum tahap tersebut dimulai. Tidak boleh ada asumsi yang menggantikan keputusan terbuka.

| ID | Keputusan yang Harus Dibuat | Pilihan yang Dipertimbangkan | Batas |
| --- | --- | --- | --- |
| O-001 | Versi Godot 4 spesifik yang dikunci untuk pengembangan dan CI. | Versi stabil terbaru saat SDD-01 versus versi yang sudah teruji untuk export Android. | SDD-01 |
| O-002 | Framework pengujian GDScript. | GUT, gdUnit4, atau test harness kustom berbasis skrip headless. | SDD-01 |
| O-003 | Tooling lint dan format kode GDScript. | godot-gdscript-toolkit (gdlint, gdformat) atau pemeriksaan kustom. | SDD-01 |
| O-004 | Komposisi workflow CI (dipisah per tujuan atau digabung dengan jobs). | Lima workflow terpisah versus satu workflow multi-job. | SDD-01 |
| O-005 | Pembagian rinci format data: data mana yang JSON dan data mana yang Godot Resources. | JSON untuk seluruh data balance versus pembagian per jenis entitas. | SDD-03 |
| O-006 | Mekanisme validasi skema konfigurasi. | Validator GDScript headless versus JSON Schema dengan tool eksternal. | SDD-03 |
| O-007 | Teknik inti AI: behavior tree, utility system, atau hibrida berlapis. | Behavior tree, utility AI, atau kombinasi keduanya per lapisan. | SDD-08 |
| O-008 | Versi Android minimum dan kelas perangkat target beserta definisi perangkat kelas bawah. | Android 8.0 sebagai kandidat minimum; kelas menengah sebagai target utama. | SDD-01 |
| O-009 | Sisa lingkup: proteksi anti-manipulasi tingkat lanjut untuk data rank (format penyimpanan diselesaikan oleh P-006). | Checksum SHA-256 (P-006) versus penandatanganan lokal; cakupan dievaluasi pada SDD-10. | SDD-10 |
| O-010 | Pipeline aset 3D: sumber, format, standar penamaan, dan kebijakan lisensi aset. | Aset orisinal versus aset berlisensi; format glTF sebagai kandidat utama. | SDD-04 |
| O-011 | Implementasi mekanisme concealment rumput. | Deteksi area berbasis shape versus grid; aturan visibilitas per unit. | SDD-07 |
| O-012 | Teknik pathfinding unit. | NavigationRegion Godot versus grid A* kustom. | SDD-05 |
| O-013 | Bahasa antarmuka UI rilis awal. | Indonesia, Inggris, atau keduanya; announcer sudah ditetapkan berbahasa Inggris. | SDD-04 |
| O-014 | Kebijakan dan tooling keseimbangan (balance) konten 15 hero. | Data terpusat dengan simulasi otomatis versus penyeimbangan manual. | SDD-11 |
| O-015 | Sumber audio announcer dan dataset nickname bot. | Rekaman original versus synthesizer; kebijakan lisensi nama. | SDD-09 |
| O-016 | Skema penomoran versi rilis dan artifact APK. Diselesaikan oleh P-005 (semantic versioning). | — | Selesai |
| O-017 | Opsi fallback Compatibility Renderer untuk perangkat kelas bawah. | Tetap Mobile Renderer saja versus menyediakan preset fallback. | SDD-12 |
| O-018 | Provisioning keystore produksi: pembuatan, penyimpanan cadangan aman, kepemilikan, dan kebijakan rotasi key. | Keystore lokal milik pemilik proyek versus dibuat saat pertama kali di CI; rotasi memakai mekanisme key rotation Android. | SDD-13 |
| O-019 | Batas retensi riwayat pertandingan (jumlah entri maksimum sebelum entri terlama dipangkas). | Batas tetap (misalnya 100 entri) versus tanpa batas dengan pemangkasan bertahap. | SDD-10 |
| O-020 | Cakupan aset tambahan yang dapat diperbarui pada rilis awal: seluruh aset dalam APK versus menyediakan paket aset opsional. | Seluruh aset di dalam APK (mekanisme manifest tetap disiapkan) versus paket aset opsional sejak rilis awal. | SDD-11 |
| O-021 | Kebijakan fallback referensi konten lama pada data pemain ketika konten versi baru berubah atau dihapus. | Referensi tidak valid dipetakan ke pengganti terdefinisi versus ditandai tidak valid dan disembunyikan dari UI. | SDD-11 |

## Aturan Pemutusan Keputusan

1. Keputusan terbuka diputuskan pada tahap requirement atau technical design dari tahap batasnya, bukan pada tahap implementation.
2. Setiap keputusan yang dipilih dipromosikan ke Bagian 1, 2, atau 2B dengan konteks dan konsekuensi.
3. Keputusan yang dibatalkan tidak dihapus; statusnya diubah menjadi `Rejected` dengan alasan.
