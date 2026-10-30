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

Menunggu hasil eksekusi workflow pada commit tahap ini. Bagian ini diperbarui setelah hasil workflow Validation diverifikasi melalui GitHub Actions.

## 6. Hasil GitHub Actions

Menunggu hasil eksekusi workflow pada commit tahap ini. Bagian ini diperbarui setelah status eksekusi Validation dan Android Build diverifikasi.

## 7. Status APK Build

Menunggu hasil eksekusi workflow Android Build. Bagian ini diperbarui setelah status export dan verifikasi artifact diverifikasi. Pengujian pada perangkat Android nyata (MF-01 s.d. MF-03 pada FOUNDATION-TEST-PLAN) menunggu pemilik proyek.

## 8. Kendala dan Keputusan yang Masih Terbuka

1. Kompatibilitas perangkat Android nyata belum dapat diklaim sebelum MF-01 s.d. MF-03 dilakukan pemilik proyek pada perangkat kelas menengah Android 8.0 ke atas.
2. Signing rilis belum aktif; provisioning keystore produksi tetap pada O-018 (SDD-13). Tidak ada kredensial yang direkayasa.
3. Nilai minSdk dan targetSdk melekat pada prebuilt template; bila kelak diperlukan kendali penuh (misalnya penyempitan arsitektur atau gradle build), dievaluasi pada SDD-13.
4. Keputusan terbuka berikutnya sesuai tahap batas: O-005 dan O-006 (SDD-03), O-010 dan O-013 (SDD-04), O-012 (SDD-05).

## 9. Acceptance Status

| Kriteria (dari requirement SDD-01) | Status |
| --- | --- |
| 1. Proyek Godot dapat dibuka dan divalidasi. | Menunggu hasil CI (import headless). |
| 2. Versi Godot terdokumentasi dan dikunci. | Terpenuhi (P-007, workflow terkunci). |
| 3. Application ID sesuai spesifikasi. | Terpenuhi pada konfigurasi; divalidasi CI. |
| 4. Struktur direktori dasar tersedia. | Terpenuhi sesuai jadwal REPOSITORY-STRUCTURE-SPEC. |
| 5. Metadata versi valid. | Terpenuhi pada repository; divalidasi CI. |
| 6. Automated tests benar-benar berjalan. | Menunggu hasil CI. |
| 7. Validation workflow berhasil. | Menunggu hasil CI. |
| 8. Android build menghasilkan APK debug atau kendala spesifik dilaporkan. | Menunggu hasil CI. |
| 9. Dokumentasi saling konsisten. | Terpenuhi; ditinjau silang antar dokumen. |
| 10. Tidak ada perubahan di luar scope. | Terpenuhi; tidak ada gameplay, hero, AI, lobby, atau sistem pertandingan yang diimplementasikan. |

## 10. Rekomendasi Tahap SDD Berikutnya

1. Setelah workflow hijau dan APK debug terverifikasi artifact, pemilik proyek melakukan MF-01 s.d. MF-03 pada perangkat nyata, lalu menetapkan acceptance SDD-01.
2. Tahap berikutnya: SDD-02 (Core Framework). Persiapan yang disarankan: requirement dan desain layanan inti (event bus, scene router, config service, save service, state machine, object pool), dengan tetap menahan implementasi hingga spesifikasinya disetujui.
3. Evaluasi ulang kebutuhan framework pengujian (GUT/gdUnit4) dilakukan pada requirement SDD-02 sebagaimana dicatat pada P-008.
