# Workflow GitHub Actions

Direktori ini berisi definisi workflow CI/CD yang diimplementasikan pada tahap SDD-01. Rancangan lengkap, daftar versi terkunci, mekanisme validasi versi, dan arsitektur signing rilis didokumentasikan pada [CI-PIPELINE-SPEC](../../docs/sdd/specifications/CI-PIPELINE-SPEC.md).

## Workflow Terimplementasi

| Workflow | Berkas | Tujuan | Pemicu |
| --- | --- | --- | --- |
| Validation | `validation.yml` | Lint GDScript (gdlint), import proyek headless, test harness fondasi, validasi metadata versi terhadap rilis sebelumnya. | Push dan pull request ke `main`. |
| Android Build | `android-build.yml` | Export APK debug dengan toolchain terkunci, verifikasi applicationId, versionCode, versionName, dan arsitektur APK, lalu upload artifact. | Dispatch manual dan push tag `v*`. |

## Prinsip

1. Versi Godot (4.7.2-stable), export template, JDK (Temurin 17), komponen Android SDK (build-tools 35.0.1, platform android-35), gdtoolkit (4.5.0), dan GitHub Actions dikunci; perubahan versi melewati Decision Log.
2. Tidak ada kredensial pada repository. Keystore debug dibuat per eksekusi CI dengan parameter debug standar Android dan tidak digunakan untuk distribusi; signing rilis menunggu keputusan O-018 pada SDD-13.
3. Artifact APK disimpan sebagai workflow artifact dengan retensi 14 hari, bukan pada repository.
4. Kegagalan dilaporkan eksplisit melalui anotasi `::error` dan kode keluar bukan nol.

## Rencana Lanjutan

Validasi data konfigurasi (JSON dan Godot Resources terhadap skema) berjalan pada workflow Validation mulai SDD-03, ketika data konfigurasi pertama tersedia (lihat [ROADMAP](../../docs/ROADMAP.md)).
