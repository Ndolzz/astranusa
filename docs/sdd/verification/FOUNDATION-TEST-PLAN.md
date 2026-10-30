# FOUNDATION-TEST-PLAN: Rencana Pengujian Fondasi SDD-01

- Status: Approved (disetujui pemilik proyek pada 2026-10-30)
- Sistem: Fondasi Repository, Konfigurasi, dan CI
- Tahap roadmap terikat: SDD-01
- Terakhir diperbarui: 2026-10-30 (hasil eksekusi CI dicatat)

## 1. Tujuan

Memastikan fondasi SDD-01 terverifikasi oleh pengujian otomatis yang berjalan nyata pada CI, serta menetapkan rencana verifikasi manual pada perangkat Android nyata.

## 2. Pengujian Otomatis

Test harness: `game/tests/foundation_tests.gd` (P-008), berbasis assertion nyata; keluar dengan kode bukan nol saat ada kegagalan. Dijalankan pada job `validate` workflow Validation setelah `godot --headless --import`.

| ID | Skenario | Hasil yang Diharapkan |
| --- | --- | --- |
| TF-01 | Metadata versi `version.json` | Berkas terbaca sebagai JSON; `versionCode` bilangan bulat positif; `versionName` lolos pola semantic versioning. |
| TF-02 | Konfigurasi `project.godot` | `config/name` ASTRANUSA; `config/features` memuat 4.7; rendering method mobile; viewport 1280x720; orientasi landscape; stretch canvas_items/expand; main scene valid dan tersedia. |
| TF-03 | Identitas export | `export_presets.cfg` terbaca; preset Android tersedia; `package/unique_name` sama dengan `com.ndolzz.astranusa`; `version/code` dan `version/name` identik dengan `version.json`; arsitektur arm64-v8a dan armeabi-v7a aktif. |
| TF-04 | Struktur direktori wajib | Seluruh direktori wajib SDD-01 tersedia (`src`, `src/core`, `src/app`, `assets`, `tests`, `tools`). |
| TF-05 | Parsing skrip GDScript | Seluruh berkas `.gd` pada `src`, `tools`, dan `tests` dapat dimuat dan lolos `reload()` tanpa error parsing. |
| TF-06 | Lint GDScript | `gdlint src tools tests` lolos tanpa pelanggaran pada job `lint`. |
| TF-07 | Validasi versi CI | Langkah CI memastikan `versionCode` meningkat dari rilis sebelumnya (baseline 0 selama belum ada rilis) dan `versionName` semver. |
| TF-08 | Sinkronisasi preset export | `tools/apply_version.gd` menulis versi dari `version.json` ke preset dan menolak `applicationId` yang tidak sesuai. |

Perintah eksekusi lokal (dari `game/`):

```
godot --headless --script res://tests/foundation_tests.gd
gdlint src tools tests
```

## 3. Pengujian Workflow

| ID | Skenario | Hasil yang Diharapkan |
| --- | --- | --- |
| WF-01 | Push ke `main` memicu workflow Validation. | Kedua job (lint, validate) selesai dengan status success. |
| WF-02 | Dispatch manual workflow Android Build. | Job build selesai success; artifact `astranusa-debug-apk` tersedia. |
| WF-03 | Verifikasi artifact APK. | Langkah verifikasi melaporkan `applicationId`, `versionCode`, `versionName`, dan kedua arsitektur sesuai. |

## 4. Pengujian Manual pada Perangkat Nyata

Pengujian ini wajib dilakukan pemilik proyek pada perangkat Android kelas menengah (Android 8.0 ke atas); kompatibilitas perangkat tidak boleh diklaim sebelum pengujian ini selesai.

| ID | Skenario | Langkah | Hasil yang Diharapkan |
| --- | --- | --- | --- |
| MF-01 | Instalasi APK debug | Unduh artifact dari eksekusi workflow Android Build; pasang pada perangkat. | APK terpasang tanpa uninstall aplikasi lain. |
| MF-02 | Smoke test boot | Jalankan aplikasi. | Layar boot menampilkan ASTRANUSA beserta versionName dan versionCode dari `version.json`. |
| MF-03 | Orientasi | Amati tampilan. | Aplikasi tampil landscape penuh tanpa distorsi pada rasio layar perangkat. |
| MF-04 | Catatan hasil | Isi hasil pengujian pada laporan tahap. | Hasil tercatat pada [SDD-01-FOUNDATION-REPORT](../reports/SDD-01-FOUNDATION-REPORT.md). |

## 5. Kriteria Lolos

1. Seluruh pengujian otomatis TF-01 s.d. TF-08 lolos pada CI dengan bukti eksekusi workflow.
2. WF-01 dan WF-02 selesai success dengan artifact APK tersedia.
3. MF-01 s.d. MF-03 dinyatakan lolos oleh pemilik proyek.

## 6. Hasil

Bukti eksekusi: [Validation run 41002625549](https://github.com/Ndolzz/astranusa/actions/runs/41002625549) pada commit `57af8c7` (2026-10-30).

| ID | Status | Catatan |
| --- | --- | --- |
| TF-01 s.d. TF-05 | Lolos | Step `Run foundation tests` selesai success; harness keluar kode nol. |
| TF-06 | Lolos | Job `Lint GDScript (gdlint)` selesai success tanpa pelanggaran. |
| TF-07 | Lolos | Step `Validate version metadata against previous release` selesai success (baseline 0). |
| TF-08 | Menunggu | Dieksekusi pada workflow Android Build. |
| WF-01 | Lolos | Kedua job Validation selesai success. |
| WF-02, WF-03 | Menunggu dispatch manual | Pemilik proyek menjalankan workflow Android Build melalui halaman Actions. |
| MF-01 s.d. MF-04 | Menunggu pengujian pemilik proyek | Memerlukan perangkat Android nyata. |

## 7. Referensi

- [CI-PIPELINE-SPEC](../specifications/CI-PIPELINE-SPEC.md)
- [GODOT-CONFIGURATION-SPEC](../specifications/GODOT-CONFIGURATION-SPEC.md)
- [REPOSITORY-STRUCTURE-SPEC](../specifications/REPOSITORY-STRUCTURE-SPEC.md)
- [APK-COMPATIBILITY-SPEC](../specifications/APK-COMPATIBILITY-SPEC.md)
