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
- Konsekuensi: Seluruh pengembangan menggunakan Godot 4; versi minor dikunci pada SDD-01 (terkait O-001, diselesaikan oleh P-007).

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
- Konsekuensi: Desain UI berorientasi layar sentuh; baseline perangkat ditetapkan pada P-009.

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

## Bagian 2C: Keputusan yang Diusulkan pada SDD-01 (disetujui pemilik proyek pada 2026-10-30)

### P-007 — Versi Godot dikunci pada 4.7.2-stable

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: O-001 mengharuskan versi stabil terbaru yang sudah teruji untuk pipeline Android. Godot 4.7.2-stable (18 Agustus 2026) adalah rilis pemeliharaan kedua seri 4.7; Godot 4.8 masih berstatus beta sehingga tidak dipakai untuk produksi.
- Konsekuensi: Editor dan export template 4.7.2 dikunci pada CI dan dokumentasi; `config/features` memuat `4.7`; perubahan versi berikutnya melewati Decision Log. Keputusan ini menyelesaikan O-001.

### P-008 — Test harness kustom headless untuk pengujian fondasi

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: O-002 menimbang GUT, gdUnit4, atau harness kustom. Pada tahap fondasi, assertion berbasis skrip headless tanpa addon cukup, menghindari dependensi vendored dan menjaga repository ringan.
- Konsekuensi: `game/tests/foundation_tests.gd` menjadi harness dengan assertion nyata dan kode keluar bukan nol saat gagal; kebutuhan framework pengujian dievaluasi ulang pada requirement SDD-02. Keputusan ini menyelesaikan O-002.

### P-009 — Baseline perangkat Android: minSdk 24, kelas QA Android 8.0+, dua arsitektur

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: O-008 menimbang Android 8.0 sebagai kandidat minimum. Batas bawaan export template Godot 4.7 adalah minSdk 24 (Android 7.0) dan targetSdk 36; menetapkan minSdk di bawah kemampuan template memerlukan gradle build yang memperberat CI pada tahap fondasi.
- Konsekuensi: Kelas perangkat yang dijamin dan diuji adalah Android 8.0 (API 26) kelas menengah ke atas; perangkat Android 7 dapat memasang aplikasi tetapi tidak dijamin. APK debug memuat arm64-v8a dan armeabi-v7a agar dapat diuji pada berbagai perangkat yang tersedia. Keputusan ini menyelesaikan O-008.

### P-010 — Orientasi landscape dengan viewport 1280x720 dan stretch canvas_items/expand

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: MOBA memerlukan bidang pandang horizontal yang lebar; 1280x720 adalah basis desain UI yang lazim untuk perangkat kelas menengah; mode `canvas_items` dengan aspek `expand` menoleransi rasio layar dan notch yang berbeda.
- Konsekuensi: Seluruh UI dirancang pada basis 1280x720 landscape; pengujian rasio non-16:9 dimulai pada tahap UI (SDD-04).

### P-011 — Tooling lint: gdtoolkit 4.5.0

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: O-003 menimbang godot-gdscript-toolkit atau pemeriksaan kustom. gdtoolkit adalah standar de facto lint dan format GDScript Godot 4, berjalan tanpa editor, dan versinya dapat dikunci tepat pada CI.
- Konsekuensi: `gdlint` 4.5.0 dijalankan pada CI untuk `src`, `tools`, dan `tests`; konfigurasi pada `game/.gdlintrc`. Keputusan ini menyelesaikan O-003.

### P-012 — Komposisi CI: dua workflow terpisah sesuai tanggung jawab

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: O-004 menimbang lima workflow terpisah atau satu workflow multi-job. Validasi harus cepat pada setiap perubahan, sementara build APK hanya dijalankan saat diminta agar riwayat Actions ringkas dan artifact terkendali.
- Konsekuensi: `validation.yml` berjalan pada push dan pull request ke `main` (lint, import, test harness, validasi versi); `android-build.yml` berjalan pada dispatch manual dan tag `v*` (export APK debug, verifikasi identitas, artifact). Validasi data konfigurasi bergabung ke Validation mulai SDD-03. Keputusan ini menyelesaikan O-004.

## Bagian 2D: Keputusan yang Diusulkan pada Verifikasi Akhir SDD-01

### P-013 — Penerimaan lisensi SDK Android oleh action setup-android, bukan pipeline `yes`

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: Tinjauan statis verifikasi akhir SDD-01 menemukan `yes | sdkmanager --licenses` exit 141 (SIGPIPE) di bawah `set -euo pipefail` pada langkah instalasi komponen SDK workflow Android Build: `yes` menerima SIGPIPE ketika `sdkmanager` menutup stdin, sehingga pipefail menggagalkan langkah meskipun penerimaan lisensi berhasil. Pola kegagalan ini terdokumentasi pada berbagai proyek CI Android. `android-actions/setup-android` v3 telah menerima lisensi SDK secara bawaan (input `accept-android-sdk-licenses`), sehingga pipeline tersebut redundan sekaligus rapuh.
- Konsekuensi: Langkah `Install pinned Android SDK components` pada `android-build.yml` tidak lagi memuat pipeline `yes`; penerimaan lisensi dibuat eksplisit melalui input `accept-android-sdk-licenses: true`. Tidak ada perubahan versi toolchain maupun konfigurasi teknis lain.

### P-014 — Upgrade android-actions/setup-android v3 ke v4 pada workflow Android Build

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: Eksekusi pertama workflow Android Build (run `41003932265`, 2026-10-30) gagal pada langkah setup SDK dalam 13 detik sebelum kode proyek tersentuh. Penyebab: upstream `android-actions/setup-android` v3 secara bawaan memasang paket legacy `tools` yang telah dihapus Google dari repositori SDK (pola kegagalan terdokumentasi luas sejak September-Oktober 2026), dan v3 masih menarget Node 20 yang kini dipaksa berjalan pada Node 24 oleh runner GitHub. v4 (v4.0.4, dirilis 2026-09-17) tidak lagi memasang paket `tools` (default `platform-tools`), berjalan native pada Node 24, dan tetap menyediakan input `accept-android-sdk-licenses`.
- Konsekuensi: Referensi action pada `android-build.yml` naik dari v3 ke v4; input `accept-android-sdk-licenses: true` (P-013) dipertahankan. Tidak ada perubahan versi Godot, JDK, build-tools, maupun platform Android.

### P-015 — Pembuatan direktori output sebelum ekspor APK pada workflow Android Build

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: Eksekusi kedua workflow Android Build (dispatch manual pemilik proyek, 2026-10-30) gagal pada langkah Export debug APK: Godot tidak membuat direktori tujuan ekspor secara otomatis sehingga perintah gagal dengan `Target folder does not exist or is inaccessible: "build"`. Seluruh langkah sebelumnya (setup SDK v4, instalasi komponen SDK, unduh editor dan template, import, keystore debug, sinkronisasi versi) lolos, sehingga perbaikan P-014 terbukti memperbaiki kegagalan setup SDK. Pesan `cannot connect to daemon at tcp:5037` dari adb bersifat non-fatal karena tidak ada perangkat terhubung pada runner.
- Konsekuensi: Langkah Export debug APK pada `android-build.yml` menjalankan `mkdir -p build` sebelum `--export-debug`. Tidak ada perubahan versi toolchain, preset export, ataupun langkah lain. Commit ini juga memulihkan format berkas ini ke Markdown murni setelah commit P-014 tanpa sengaja menyimpan lapisan enkode JSON pada berkas tersebut; tidak ada isi keputusan yang berubah.

### P-016 — Verifikasi APK memakai aapt2 alih-alih aapt legacy

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: Eksekusi ketiga workflow Android Build (dispatch manual pemilik proyek, 2026-10-30) berhasil mengekspor APK — perbaikan P-015 terbukti bekerja — namun gagal pada langkah Verify APK identity and version: `aapt` legacy tidak dapat membaca manifest biner Android buatan Godot (`failed to read attribute 'android:required': attribute is not an integer value`) karena aapt legacy membaca atribut tersebut sebagai integer. Kegagalan berpola identik pada APK Godot terdokumentasi di proyek lain dan diperbaiki dengan beralih ke `aapt2 dump badging`.
- Konsekuensi: Langkah verifikasi memakai `aapt2` bawaan build-tools 35.0.1 yang terkunci, dengan kegagalan eksplisit jika aapt2 tidak tersedia. Tidak ada perubahan daftar pemeriksaan (applicationId, versionCode, versionName, arsitektur) maupun langkah lain.

### P-017 — Kunci arsitektur preset export sesuai skema Godot 4

- Status: Accepted (disetujui pemilik proyek pada 2026-10-30).
- Konteks: Eksekusi keempat workflow Android Build (dispatch manual pemilik proyek, 2026-10-30) lolos seluruh verifikasi kecuali arsitektur: APK memuat arm64-v8a namun tidak memuat armeabi-v7a. `export_presets.cfg` memakai kunci gaya lama (`architectures/ARM64`, `architectures/ARMEABI_V7A`, `architectures/X86_64`) yang tidak dikenali Godot 4.7 — Godot 4.2 ke atas memakai nama ABI huruf kecil — sehingga editor mengabaikan nilai tersebut dan mengekspor armeabi-v7a dengan bawaan nonaktif. Harness TF-03 selama ini memvalidasi kunci lama yang sama sehingga lolos secara false positive.
- Konsekuensi: Kunci arsitektur preset diganti menjadi `architectures/arm64-v8a=true`, `architectures/armeabi-v7a=true`, `architectures/x86=false`, `architectures/x86_64=false`; assertion harness TF-03 diarahkan ke kunci baru. Kebutuhan arsitektur P-009 (kedua ABI aktif) tidak berubah; tidak ada perubahan versi Godot, workflow, maupun nilai versi.

## Bagian 3: Keputusan Terbuka

Setiap keputusan terbuka mencantumkan tahap batas: keputusan harus dibuat sebelum tahap tersebut dimulai. Tidak boleh ada asumsi yang menggantikan keputusan terbuka.

| ID | Keputusan yang Harus Dibuat | Pilihan yang Dipertimbangkan | Batas |
| --- | --- | --- | --- |
| O-001 | Versi Godot 4 spesifik yang dikunci untuk pengembangan dan CI. Diselesaikan oleh P-007 (Godot 4.7.2-stable). | — | Selesai |
| O-002 | Framework pengujian GDScript. Diselesaikan oleh P-008 (test harness kustom headless). | — | Selesai |
| O-003 | Tooling lint dan format kode GDScript. Diselesaikan oleh P-011 (gdtoolkit 4.5.0). | — | Selesai |
| O-004 | Komposisi workflow CI. Diselesaikan oleh P-012 (dua workflow terpisah). | — | Selesai |
| O-005 | Pembagian rinci format data: data mana yang JSON dan data mana yang Godot Resources. | JSON untuk seluruh data balance versus pembagian per jenis entitas. | SDD-03 |
| O-006 | Mekanisme validasi skema konfigurasi. | Validator GDScript headless versus JSON Schema dengan tool eksternal. | SDD-03 |
| O-007 | Teknik inti AI: behavior tree, utility system, atau hibrida berlapis. | Behavior tree, utility AI, atau kombinasi keduanya per lapisan. | SDD-08 |
| O-008 | Versi Android minimum dan kelas perangkat target. Diselesaikan oleh P-009 (minSdk 24, kelas QA Android 8.0+, arm64-v8a dan armeabi-v7a). | — | Selesai |
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
2. Setiap keputusan yang dipilih dipromosikan ke Bagian 1, 2, 2B, 2C, atau 2D dengan konteks dan konsekuensi.
3. Keputusan yang dibatalkan tidak dihapus; statusnya diubah menjadi `Rejected` dengan alasan.
