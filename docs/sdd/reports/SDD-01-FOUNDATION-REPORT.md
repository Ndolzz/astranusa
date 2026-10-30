# SDD-01-FOUNDATION-REPORT: Laporan Tahap Repository & CI Foundation

- Status: In Review
- Tahap: SDD-01 (Repository & CI Foundation)
- Tanggal pekerjaan: 2026-10-30
- Pemilik laporan: Arsitek proyek

## 1. Hasil Audit Repository

1. Branch tunggal `main`; HEAD sebelum pekerjaan: `20f31ff` (SPEC: Update System & Data Persistence).
2. Tidak ada branch lain, tidak ada protection rule, tidak ada file proyek Godot maupun workflow CI sebelum pekerjaan ini.
3. `game/` hanya berisi README perencanaan; `.github/workflows/` hanya berisi README perencanaan.
4. Dokumentasi SDD-00 dan batch spesifikasi Update System & Data Persistence konsisten dengan kondisi repository.
5. Keputusan terbuka yang wajib diselesaikan pada tahap ini: O-001, O-002, O-003, O-004, O-008; seluruhnya diselesaikan melalui P-007 s.d. P-012 (bagian 3).
6. Versi Godot stabil terbaru diverifikasi melalui riset: 4.7.2-stable (18 Agustus 2026); Godot 4.8 masih beta.

## 2. File yang Dibuat dan Diubah

Dibuat (proyek Godot):

- `game/project.godot`
- `game/version.json`
- `game/export_presets.cfg`
- `game/.gdlintrc`
- `game/assets/icon.svg`
- `game/src/core/app_version.gd`
- `game/src/app/boot.gd`
- `game/src/app/boot.tscn`
- `game/tools/apply_version.gd`
- `game/tests/foundation_tests.gd`

Diubah (proyek Godot):

- `game/README.md` (dari perencanaan menjadi dokumentasi struktur aktual)

Dibuat (CI/CD):

- `.github/workflows/validation.yml`
- `.github/workflows/android-build.yml`

Diubah (CI/CD dan root):

- `.github/workflows/README.md` (dari rencana menjadi dokumentasi workflow terimplementasi)
- `.gitignore` (menambah `build/` untuk output export)
- `CHANGELOG.md` (baru; entri 0.1.0)

Dibuat dan diubah (dokumentasi SDD):

- `docs/sdd/specifications/REPOSITORY-STRUCTURE-SPEC.md`
- `docs/sdd/specifications/GODOT-CONFIGURATION-SPEC.md`
- `docs/sdd/specifications/CI-PIPELINE-SPEC.md`
- `docs/sdd/verification/FOUNDATION-TEST-PLAN.md`
- `docs/sdd/reports/SDD-01-FOUNDATION-REPORT.md`
- `docs/DECISION_LOG.md` (Bagian 2C; penyelesaian O-001 s.d. O-004 dan O-008)
- `docs/ROADMAP.md` (kolom status tahap)
- `README.md` (status proyek, indeks dokumentasi, struktur repository)

## 3. Keputusan Teknis Baru

Disetujui pemilik proyek pada 2026-10-30, dicatat pada Decision Log Bagian 2C:

| ID | Keputusan | Keputusan Terbuka yang Diselesaikan |
| --- | --- | --- |
| P-007 | Godot 4.7.2-stable dikunci untuk pengembangan dan CI. | O-001 |
| P-008 | Test harness kustom headless tanpa addon; GUT/gdUnit4 dievaluasi ulang pada SDD-02 bila kompleksitas meningkat. | O-002 |
| P-009 | minSdk 24 dan targetSdk 36 (bawaan template 4.7.2); kelas perangkat QA Android 8.0 ke atas; APK debug memuat arm64-v8a dan armeabi-v7a. | O-008 |
| P-010 | Orientasi landscape; viewport dasar 1280x720; stretch canvas_items dengan aspect expand. | Baru |
| P-011 | gdtoolkit 4.5.0 (gdlint) sebagai tooling lint, terkunci pada CI. | O-003 |
| P-012 | Dua workflow terpisah: Validation (push/PR main) dan Android Build (dispatch manual dan tag v*). | O-004 |

## 4. Versi Godot dan Konfigurasi Android

- Versi Godot: 4.7.2-stable (editor dan export template), URL rilis resmi dikunci pada workflow.
- Rendering: Mobile Renderer; kompresi tekstur ETC2/ASTC.
- Orientasi landscape; viewport 1280x720; stretch canvas_items/expand.
- applicationId: `com.ndolzz.astranusa` (P-003).
- minSdk 24; targetSdk 36; arsitektur debug: arm64-v8a dan armeabi-v7a; prebuilt template tanpa gradle build pada SDD-01.
- JDK 17 (Temurin); Android build-tools 35.0.1; platform android-35.
- Versi aplikasi: versionCode 1, versionName 0.1.0, sumber `game/version.json`.

## 5. Hasil Automated Tests

Terverifikasi pada eksekusi workflow Validation, run `41002625549` (commit `57af8c7`, 2026-10-30): [Validation run 41002625549](https://github.com/Ndolzz/astranusa/actions/runs/41002625549).

| Pengujian | Hasil |
| --- | --- |
| TF-01 s.d. TF-05 (test harness fondasi: metadata versi, konfigurasi proyek, identitas export, struktur direktori, parsing skrip) | Lolos. Step `Run foundation tests` selesai success; harness keluar kode nol. |
| TF-06 (gdlint atas `src`, `tools`, `tests`) | Lolos. Job `Lint GDScript (gdlint)` selesai success tanpa pelanggaran. |
| TF-07 (validasi versi CI terhadap rilis sebelumnya) | Lolos. Step `Validate version metadata against previous release` selesai success; baseline 0 (belum ada rilis), versionCode 1. |
| TF-08 (sinkronisasi preset export oleh `apply_version.gd`) | Menunggu eksekusi workflow Android Build. |

## 6. Hasil GitHub Actions

| Workflow | Pemicu | Hasil |
| --- | --- | --- |
| Validation | Push ke `main` (commit `57af8c7`) | Success. Kedua job (`Lint GDScript (gdlint)`, `Validate project and run foundation tests`) selesai success: [run 41002625549](https://github.com/Ndolzz/astranusa/actions/runs/41002625549). |
| Android Build | Dispatch manual atau tag `v*` (P-012) | Belum dieksekusi pada tahap ini; menunggu dispatch manual oleh pemilik proyek karena pemicunya sengaja bukan push biasa. |

## 7. Status APK Build

1. Belum ada APK yang dihasilkan pada tahap ini karena workflow Android Build belum dieksekusi.
2. Langkah eksekusi: buka halaman [Actions - Android Build](https://github.com/Ndolzz/astranusa/actions/workflows/android-build.yml), pilih `Run workflow` pada branch `main`, lalu unduh artifact `astranusa-debug-apk` setelah job selesai.
3. Setelah APK tersedia, pemilik proyek melakukan pengujian manual MF-01 s.d. MF-05 pada [FOUNDATION-TEST-PLAN](../verification/FOUNDATION-TEST-PLAN.md) di perangkat Android kelas menengah (Android 8.0 ke atas).
4. Kompatibilitas perangkat Android nyata belum diklaim sampai langkah 3 selesai dan dilaporkan.

### 7.1 Verifikasi Akhir (2026-10-30)

1. Audit ulang pada HEAD `16fe5bf` (branch tunggal `main`): kondisi repository identik dengan laporan tahap ini; tidak ada perubahan pengguna yang tertimpa.
2. Workflow Validation dikonfirmasi lolos pada HEAD melalui eksekusi run #2 (commit `16fe5bf`, selesai success).
3. Halaman Actions mengonfirmasi workflow Android Build belum pernah dieksekusi (nol run) hingga verifikasi ini; tidak ada APK yang dihasilkan dan build tidak diklaim berhasil.
4. Verifikator tidak memiliki kapabilitas dispatch workflow GitHub Actions melalui tooling yang tersedia; sesuai desain pemicu P-012, eksekusi memerlukan dispatch manual oleh pemilik proyek.
5. Tinjauan statis workflow menemukan kecacatan berisiko tinggi sebelum eksekusi pertama: `yes | sdkmanager --licenses` exit 141 (SIGPIPE) di bawah `set -euo pipefail`, pola kegagalan CI Android yang terdokumentasi luas. Perbaikan minimal diterapkan sesuai P-013 (disetujui pemilik proyek pada 2026-10-30).
6. Seluruh butir verifikasi APK (applicationId, versionName, versionCode, arsitektur arm64-v8a dan armeabi-v7a, integritas, scene boot) tetap pending hingga artifact tersedia; kecocokan nilai pada konfigurasi export telah divalidasi test harness (TF-03) namun bukan bukti kompatibilitas perangkat.
7. Eksekusi pertama workflow Android Build (dispatch manual pemilik proyek, run `41003932265`, 2026-10-30) gagal dalam 13 detik sebelum kode proyek tersentuh; penyebab: kerusakan upstream `android-actions/setup-android` v3 yang memasang paket `tools` legacy yang telah dihapus Google dari repositori SDK. Perbaikan: upgrade ke v4 sesuai P-014 (disetujui pemilik proyek pada 2026-10-30). Belum ada APK yang dihasilkan; build ulang menunggu dispatch manual berikutnya.
8. Eksekusi kedua workflow Android Build (dispatch manual pemilik proyek, 2026-10-30) gagal pada langkah Export debug APK: Godot tidak membuat direktori tujuan `build/` secara otomatis (`Target folder does not exist or is inaccessible`). Seluruh langkah sebelumnya lolos sehingga perbaikan P-014 terbukti memadai; perbaikan P-015 menambahkan `mkdir -p build` sebelum ekspor. Commit P-014 juga tanpa sengaja menyimpan `docs/DECISION_LOG.md` dalam lapisan enkode JSON; commit ini memulihkan formatnya tanpa mengubah isi keputusan.

## 8. Kendala dan Keputusan yang Masih Terbuka

1. Kompatibilitas perangkat Android nyata belum dapat diklaim sebelum MF-01 s.d. MF-05 dilakukan pemilik proyek pada perangkat kelas menengah Android 8.0 ke atas.
2. Signing rilis belum aktif; provisioning keystore produksi tetap pada O-018 (SDD-13). Tidak ada kredensial yang direkayasa.
3. Nilai minSdk dan targetSdk melekat pada prebuilt template; bila kelak diperlukan kendali penuh (misalnya penyempitan arsitektur atau gradle build), dievaluasi pada SDD-13.
4. Keputusan terbuka berikutnya sesuai tahap batas: O-005 dan O-006 (SDD-03), O-010 dan O-013 (SDD-04), O-012 (SDD-05).
5. Tinjauan statis verifikasi akhir menemukan risiko kegagalan langkah penerimaan lisensi SDK pada workflow Android Build (SIGPIPE di bawah pipefail); perbaikan minimal diterapkan sesuai P-013 (disetujui pemilik proyek pada 2026-10-30).
6. Eksekusi workflow Android Build memerlukan dispatch manual pemilik proyek; tooling verifikator tidak menyediakan kapabilitas dispatch, sehingga tidak ada klaim keberhasilan build yang dibuat.
7. Eksekusi pertama Android Build (run `41003932265`) gagal karena kerusakan upstream action setup (paket `tools` dihapus Google; P-014). Diperlukan dispatch ulang oleh pemilik proyek setelah perbaikan untuk membuktikan build lolos.
8. Eksekusi kedua Android Build gagal pada langkah Export debug APK karena direktori tujuan tidak dibuat (P-015). Diperlukan dispatch ketiga oleh pemilik proyek untuk membuktikan build lolos.

## 9. Acceptance Status

| Kriteria (dari requirement SDD-01) | Status |
| --- | --- |
| 1. Proyek Godot dapat dibuka dan divalidasi. | Terpenuhi. `godot --headless --import` selesai success pada CI. |
| 2. Versi Godot terdokumentasi dan dikunci. | Terpenuhi (P-007; workflow memakai URL rilis terkunci). |
| 3. Application ID sesuai spesifikasi. | Terpenuhi pada konfigurasi; divalidasi test harness (TF-03) pada CI. |
| 4. Struktur direktori dasar tersedia. | Terpenuhi sesuai jadwal REPOSITORY-STRUCTURE-SPEC; divalidasi TF-04. |
| 5. Metadata versi valid. | Terpenuhi; divalidasi TF-01 dan langkah CI TF-07. |
| 6. Automated tests benar-benar berjalan. | Terpenuhi. Test harness dieksekusi pada CI dengan hasil success (run `41002625549`). |
| 7. Validation workflow berhasil. | Terpenuhi. Kedua job selesai success. |
| 8. Android build menghasilkan APK debug atau kendala spesifik dilaporkan. | Kendala spesifik dilaporkan: percobaan pertama (run `41003932265`) gagal pada langkah setup SDK (P-014); percobaan kedua gagal pada langkah Export debug APK karena direktori tujuan `build/` tidak dibuat (P-015). Perbaikan P-013, P-014, dan P-015 diterapkan; menunggu dispatch ketiga oleh pemilik proyek. |
| 9. Dokumentasi saling konsisten. | Terpenuhi; ditinjau silang antar dokumen. |
| 10. Tidak ada perubahan di luar scope. | Terpenuhi; tidak ada gameplay, hero, AI, lobby, atau sistem pertandingan yang diimplementasikan. |

## 10. Rekomendasi Tahap SDD Berikutnya

1. Pemilik proyek menjalankan workflow Android Build secara manual (perbaikan P-013, P-014, dan P-015 telah diterapkan), mengunduh artifact APK debug, dan melakukan MF-01 s.d. MF-05 pada perangkat nyata, lalu menetapkan acceptance SDD-01.
2. Tahap berikutnya: SDD-02 (Core Framework). Persiapan yang disarankan: requirement dan desain layanan inti (event bus, scene router, config service, save service, state machine, object pool), dengan tetap menahan implementasi hingga spesifikasinya disetujui.
3. Evaluasi ulang kebutuhan framework pengujian (GUT/gdUnit4) dilakukan pada requirement SDD-02 sebagaimana dicatat pada P-008.
