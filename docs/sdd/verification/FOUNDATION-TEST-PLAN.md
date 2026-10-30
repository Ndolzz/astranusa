# FOUNDATION-TEST-PLAN: Rencana Pengujian Fondasi SDD-01

- Status: Approved (disetujui pemilik proyek pada 2026-10-30)
- Sistem: Fondasi Repository, Konfigurasi, dan CI
- Tahap roadmap terikat: SDD-01
- Terakhir diperbarui: 2026-10-30 (hasil eksekusi kelima dan pengujian manual perangkat dicatat; seluruh kriteria lolos)

## 1. Tujuan

Memastikan fondasi SDD-01 terverifikasi oleh pengujian otomatis yang berjalan nyata pada CI, serta menetapkan rencana verifikasi manual pada perangkat Android nyata.

## 2. Pengujian Otomatis

Test harness: `game/tests/foundation_tests.gd` (P-008), berbasis assertion nyata; keluar dengan kode bukan nol saat ada kegagalan. Dijalankan pada job `validate` workflow Validation setelah `godot --headless --import`.

| ID | Skenario | Hasil yang Diharapkan |
| --- | --- | --- |
| TF-01 | Metadata versi `version.json` | Berkas terbaca sebagai JSON; `versionCode` bilangan bulat positif; `versionName` lolos pola semantic versioning. |
| TF-02 | Konfigurasi `project.godot` | `config/name` ASTRANUSA; `config/features` memuat 4.7; rendering method mobile; viewport 1280x720; orientasi landscape; stretch canvas_items/expand; main scene valid dan tersedia. |
| TF-03 | Identitas export | `export_presets.cfg` terbaca; preset Android tersedia; `package/unique_name` sama dengan `com.ndolzz.astranusa`; `version/code` dan `version/name` identik dengan `version.json`; arsitektur arm64-v8a dan armeabi-v7a aktif. Koreksi assertion arsitektur dicatat pada P-017 (harness sebelumnya memvalidasi kunci gaya lama). |
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
| MF-02 | Smoke test boot | Jalankan aplikasi. | Layar boot menampilkan ASTRANUSA beserta versionName dan versionCode dari `version.json` (`ASTRANUSA 0.1.0 (build 1)`). |
| MF-03 | Orientasi | Amati tampilan. | Aplikasi tampil landscape penuh tanpa distorsi pada rasio layar perangkat. |
| MF-04 | Stabilitas awal | Biarkan aplikasi terbuka minimal 60 detik tanpa interaksi. | Tidak ada crash, force close, atau ANR pada 60 detik pertama. |
| MF-05 | Performa startup | Ukur perkiraan durasi dari tap ikon hingga scene boot tampil (cold start). | Durasi dapat diterima dan dicatat; referensi informal SDD-01: di bawah 5 detik pada perangkat kelas menengah (bukan gerbang lolos keras). |
| MF-06 | Catatan hasil | Isi hasil pengujian pada laporan tahap. | Hasil MF-01 s.d. MF-05 tercatat pada [SDD-01-FOUNDATION-REPORT](../reports/SDD-01-FOUNDATION-REPORT.md). |

### 4.1 Prosedur Rinci Eksekusi Manual

Prasyarat: perangkat Android kelas menengah (Android 8.0 / API 26 ke atas, arsitektur arm64-v8a atau armeabi-v7a) dan akses pemilik repository.

1. Buka halaman [Actions - Android Build](https://github.com/Ndolzz/astranusa/actions/workflows/android-build.yml), pilih `Run workflow` pada branch `main`, lalu jalankan (pemicu dispatch manual sesuai P-012).
2. Tunggu job `build-debug-apk` selesai dengan status success (batas 40 menit).
3. Unduh artifact `astranusa-debug-apk` dari halaman eksekusi (retensi 14 hari); ekstrak `astranusa-debug.apk` dan `release-notes.md`.
4. MF-01: pasang APK pada perangkat (salin berkas lalu izinkan instalasi dari sumber tidak dikenal bila diminta, atau gunakan `adb install astranusa-debug.apk`).
5. MF-02: buka aplikasi dari launcher; pastikan scene boot tampil dengan teks `ASTRANUSA 0.1.0 (build 1)`.
6. MF-03: amati orientasi landscape dan ketiadaan distorsi pada rasio layar perangkat.
7. MF-04: biarkan aplikasi terbuka 60 detik; pastikan tidak ada crash atau dialog force close.
8. MF-05: catat perkiraan durasi cold start dari tap ikon hingga scene boot tampil.
9. MF-06: catat hasil MF-01 s.d. MF-05 pada [SDD-01-FOUNDATION-REPORT](../reports/SDD-01-FOUNDATION-REPORT.md).

## 5. Kriteria Lolos

1. Seluruh pengujian otomatis TF-01 s.d. TF-08 lolos pada CI dengan bukti eksekusi workflow.
2. WF-01 dan WF-02 selesai success dengan artifact APK tersedia.
3. MF-01 s.d. MF-05 dinyatakan lolos oleh pemilik proyek.

## 6. Hasil

Bukti eksekusi: [Validation run 41002625549](https://github.com/Ndolzz/astranusa/actions/runs/41002625549) pada commit `57af8c7` (2026-10-30); verifikasi akhir pada HEAD `16fe5bf` dikonfirmasi oleh eksekusi Validation run #2 yang selesai success (2026-10-30).

Verifikasi akhir SDD-01 (2026-10-30): halaman Actions mengonfirmasi workflow Android Build belum memiliki eksekusi (nol run), sehingga WF-02 dan WF-03 tetap menunggu dispatch manual. Tinjauan statis menemukan risiko kegagalan langkah penerimaan lisensi SDK (`yes | sdkmanager --licenses` exit 141 di bawah `set -o pipefail`); temuan dan mitigasinya dicatat pada [CI-PIPELINE-SPEC](../specifications/CI-PIPELINE-SPEC.md) bagian 10 (P-013). Percobaan dispatch pertama (run `41003932265`) kemudian gagal pada langkah setup SDK karena kerusakan upstream `android-actions/setup-android` v3; perbaikan dicatat sebagai P-014. Percobaan kedua gagal pada langkah Export debug APK karena Godot tidak membuat direktori tujuan secara otomatis; perbaikan dicatat sebagai P-015. Percobaan ketiga berhasil mengekspor APK namun gagal pada langkah verifikasi karena `aapt` legacy tidak dapat membaca manifest biner buatan Godot; perbaikan dicatat sebagai P-016. Percobaan keempat lolos seluruh verifikasi kecuali armeabi-v7a karena kunci arsitektur preset memakai nama gaya lama yang diabaikan Godot 4; perbaikan dicatat sebagai P-017, termasuk koreksi assertion harness TF-03 yang selama ini memvalidasi kunci lama (false positive). Percobaan kelima (run #5, dispatch manual pemilik proyek, 2026-10-30) selesai success dalam 1 menit: verifikasi aapt2 melaporkan applicationId, versionCode, versionName, serta arsitektur arm64-v8a dan armeabi-v7a sesuai, dan artifact `astranusa-debug-apk` tersedia. Pemilik proyek kemudian melakukan MF-01 s.d. MF-06 pada perangkat Android nyata dan seluruhnya dinyatakan lolos pada 2026-10-30; tahap SDD-01 dinyatakan selesai (P-018).

| ID | Status | Catatan |
| --- | --- | --- |
| TF-01 s.d. TF-05 | Lolos | Step `Run foundation tests` selesai success; harness keluar kode nol. |
| TF-06 | Lolos | Job `Lint GDScript (gdlint)` selesai success tanpa pelanggaran. |
| TF-07 | Lolos | Step `Validate version metadata against previous release` selesai success (baseline 0). |
| TF-08 | Lolos | Langkah Apply version metadata pada eksekusi kelima workflow Android Build (run #5, 2026-10-30) selesai success; verifikasi aapt2 mengonfirmasi versionCode 1 dan versionName 0.1.0 sesuai `version.json`. |
| WF-01 | Lolos | Kedua job Validation selesai success. |
| WF-02, WF-03 | Lolos | Percobaan kelima (run #5, dispatch manual pemilik proyek, 2026-10-30) selesai success dalam 1 menit; job `build-debug-apk` lolos, artifact `astranusa-debug-apk` tersedia, dan verifikasi melaporkan applicationId `com.ndolzz.astranusa`, versionCode 1, versionName 0.1.0, serta arsitektur arm64-v8a dan armeabi-v7a sesuai. Empat percobaan sebelumnya gagal dan diperbaiki melalui P-014 s.d. P-017. |
| MF-01 s.d. MF-06 | Lolos | Dilakukan pemilik proyek pada perangkat Android nyata terhadap artifact eksekusi kelima (2026-10-30): instalasi, scene boot `ASTRANUSA 0.1.0 (build 1)`, orientasi landscape, stabilitas 60 detik, dan durasi startup dinyatakan lolos; hasil dicatat pada laporan tahap (MF-06). |

## 7. Referensi

- [CI-PIPELINE-SPEC](../specifications/CI-PIPELINE-SPEC.md)
- [GODOT-CONFIGURATION-SPEC](../specifications/GODOT-CONFIGURATION-SPEC.md)
- [REPOSITORY-STRUCTURE-SPEC](../specifications/REPOSITORY-STRUCTURE-SPEC.md)
- [APK-COMPATIBILITY-SPEC](../specifications/APK-COMPATIBILITY-SPEC.md)
