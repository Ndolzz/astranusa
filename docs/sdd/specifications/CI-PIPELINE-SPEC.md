# CI-PIPELINE-SPEC: Pipeline Validasi dan Build APK

- Status: Approved (disetujui pemilik proyek pada 2026-10-30)
- Sistem: Continuous Integration dan Delivery
- Tahap roadmap terikat: SDD-01; mengikat seluruh tahap berikutnya
- Terakhir diperbarui: 2026-10-30 (risiko kegagalan penerimaan lisensi SDK, upgrade setup-android v4, pembuatan direktori ekspor, dan penggantian alat verifikasi ke aapt2 tercatat pada verifikasi akhir SDD-01)

## 1. Tujuan

Menetapkan workflow GitHub Actions yang memvalidasi setiap perubahan dan menghasilkan APK Android secara konsisten, terkunci, dan tanpa kredensial pada repository.

## 2. Ruang Lingkup

Dalam lingkup: komposisi workflow, pemicu, langkah validasi, mekanisme validasi versi, pipeline build APK debug, kebijakan artifact, dan arsitektur signing rilis (dokumentasi saja).

Di luar lingkup: kebijakan data pemain (lihat [DATA-PERSISTENCE-SPEC](DATA-PERSISTENCE-SPEC.md)) dan alur pembaruan dari sisi pemain (lihat [UPDATE-SYSTEM-SPEC](UPDATE-SYSTEM-SPEC.md)).

## 3. Prinsip

1. Seluruh versi toolchain dikunci pada berkas workflow; perubahan versi melewati Decision Log.
2. Tidak ada kredensial pada repository; kredensial hanya melalui konteks Secrets dan tidak pernah dicetak.
3. Artifact tidak disimpan pada repository, hanya sebagai workflow artifact dengan retensi terdefinisi.
4. Setiap kegagalan dilaporkan eksplisit melalui anotasi `::error` dan kode keluar bukan nol.
5. Workflow tidak mengirim APK ke layanan eksternal apa pun.

## 4. Komposisi Workflow (P-012; menyelesaikan O-004)

| Workflow | Pemicu | Tanggung Jawab |
| --- | --- | --- |
| Validation (`validation.yml`) | Push dan pull request ke `main`. | Lint GDScript, import proyek headless, test harness fondasi, validasi metadata versi. |
| Android Build (`android-build.yml`) | Dispatch manual dan push tag `v*`. | Export APK debug, verifikasi identitas APK, upload artifact. |

Alasan pemisahan: artifact build hanya dihasilkan saat diminta sehingga riwayat Actions tetap ringkas; validasi berjalan cepat pada setiap perubahan. Validasi data konfigurasi terhadap skema bergabung ke workflow Validation mulai SDD-03, saat data konfigurasi pertama tersedia (O-006).

## 5. Workflow Validation

Job `lint`:

1. Checkout repository.
2. Pasang Python 3.12 dan gdtoolkit 4.5.0 (gdlint).
3. Jalankan `gdlint src tools tests` pada root proyek `game/`; pelanggaran menggagalkan job.

Job `validate`:

1. Checkout repository.
2. Unduh editor Godot 4.7.2-stable dari URL rilis resmi yang dikunci.
3. `godot --headless --import`: memvalidasi konfigurasi proyek dan mengimpor resource.
4. `godot --headless --script res://tests/foundation_tests.gd`: menjalankan test harness fondasi (metadata versi, konfigurasi proyek, identitas export, struktur direktori, parsing seluruh skrip GDScript). Kode keluar bukan nol menggagalkan job.
5. Validasi metadata versi terhadap rilis sebelumnya (bagian 7).

## 6. Workflow Android Build

1. Checkout repository.
2. Pasang JDK Temurin 17 dan Android SDK (cmdline-tools).
3. Pasang komponen SDK terkunci: `platform-tools`, `platforms;android-35`, `build-tools;35.0.1`; lisensi SDK diterima oleh action setup-android (P-013).
4. Unduh export template Godot 4.7.2 (di-cache antar eksekusi berdasarkan versi template) dan editor 4.7.2-stable.
5. `godot --headless --import` pada `game/`.
6. Buat keystore debug standar Android per eksekusi (kredensial debug publik bawaan; bukan rahasia).
7. `godot --headless --script res://tools/apply_version.gd`: menyinkronkan `version/code` dan `version/name` dari `version.json` ke preset export, memverifikasi `applicationId`, dan memasang path keystore debug dari variabel lingkungan.
8. `mkdir -p build` lalu `godot --headless --export-debug "Android Debug" build/astranusa-debug.apk` (P-015: Godot tidak membuat direktori tujuan secara otomatis).
9. Verifikasi artifact APK: integritas zip, `applicationId` sama dengan nilai terkunci, `versionCode` dan `versionName` sama dengan `version.json`, serta keberadaan arsitektur `arm64-v8a` dan `armeabi-v7a` melalui `aapt2 dump badging`. Ketidaksesuaian menggagalkan build sebelum artifact didistribusikan.
10. Ekstrak ringkasan changelog versi terkini dari `CHANGELOG.md` sebagai `release-notes.md`.
11. Upload artifact `astranusa-debug-apk` (APK dan ringkasan changelog) dengan retensi 14 hari.

## 7. Mekanisme Validasi versionCode

1. `versionCode` harus bilangan bulat positif; `versionName` harus `MAJOR.MINOR.PATCH` (divalidasi oleh test harness dan oleh langkah CI).
2. Nilai pembanding (baseline) adalah `versionCode` rilis GitHub terakhir. Rilis wajib menyertakan aset `version.json` agar pembanding dapat dibaca mesin.
3. Jika belum ada rilis, baseline bernilai 0.
4. Jika `versionCode` baru tidak lebih tinggi dari baseline, workflow gagal dengan pesan eksplisit sebelum APK dibangun.
5. Tidak ada pembubuhan angka versi otomatis dari nomor eksekusi CI (P-004).

## 8. Toolchain Terkunci

| Komponen | Versi Terkunci |
| --- | --- |
| Godot editor dan export template | 4.7.2-stable (`Godot_v4.7.2-stable_linux.x86_64.zip`, `Godot_v4.7.2-stable_export_templates.tpz`) |
| JDK | Temurin 17 |
| Android build-tools | 35.0.1 |
| Android platform | android-35 |
| gdtoolkit (gdlint) | 4.5.0 |
| actions/checkout, setup-python, setup-java, cache, upload-artifact | v4, v5, v4, v4, v4 |
| android-actions/setup-android | v4 (v4.0.4; P-014) |

## 9. Arsitektur Signing Rilis (Dokumentasi; Tidak Aktif)

1. Build produksi ditandatangani satu keystore produksi konsisten; skema tanda tangan v2 dan v3 bawaan export Godot.
2. Keystore produksi disimpan sebagai GitHub Secrets berikut dan tidak pernah berada pada repository:

| Secret | Fungsi |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | Berkas keystore produksi terenkode base64. |
| `ANDROID_KEYSTORE_PASSWORD` | Kata sandi keystore. |
| `ANDROID_KEY_PASSWORD` | Kata sandi key alias produksi. |

3. Job signing rilis sengaja belum ditambahkan pada SDD-01; provisioning keystore produksi, cadangan aman, dan kebijakan rotasi ditetapkan pada O-018 sebelum rilis pertama yang ditandatangani produksi (SDD-13).
4. Tidak ada kredensial yang direkayasa, dibuat, atau dicatat pada tahap ini.

## 10. Risiko dan Mitigasi

| Risiko | Mitigasi |
| --- | --- |
| Nilai minSdk dan targetSdk melekat pada template bawaan (prebuilt). | Dokumentasi eksplisit pada GODOT-CONFIGURATION-SPEC; verifikasi manifest pada langkah verifikasi APK; opsi gradle build dievaluasi pada SDD-13. |
| `aapt` tidak tersedia pada build-tools tertentu. | Langkah verifikasi beralih ke `aapt2` bila `aapt` tidak ditemukan. |
| `yes \| sdkmanager --licenses` exit 141 (SIGPIPE) di bawah `set -o pipefail` pada langkah instalasi komponen SDK; `yes` menerima SIGPIPE ketika `sdkmanager` menutup stdin sehingga langkah gagal meskipun penerimaan lisensi berhasil. Ditemukan melalui tinjauan statis verifikasi akhir SDD-01 (2026-10-30) sebelum eksekusi pertama workflow. | Pipeline `yes` dihapus dan lisensi diterima secara eksplisit melalui input `accept-android-sdk-licenses: true` pada `android-actions/setup-android` v3 (P-013). Tidak ada perubahan versi toolchain. |
| `android-actions/setup-android` v3 memasang paket legacy `tools` yang telah dihapus Google dari repositori SDK; action gagal sebelum kode proyek tersentuh (dikonfirmasi pada eksekusi pertama run `41003932265`, gagal 13 detik). | Upgrade ke v4 sesuai P-014: default paket hanya `platform-tools`, native Node 24, input `accept-android-sdk-licenses` tetap tersedia. |
| Godot tidak membuat direktori tujuan ekspor secara otomatis; eksekusi kedua workflow gagal pada langkah export (`Target folder does not exist or is inaccessible: "build"`). | Langkah Export debug APK menjalankan `mkdir -p build` sebelum `--export-debug` (P-015). |
| `aapt` legacy tidak dapat membaca manifest biner Android buatan Godot (`android:required` tidak dikodekan sebagai integer), sehingga verifikasi gagal meskipun APK berhasil diekspor. | Langkah verifikasi memakai `aapt2` bawaan build-tools yang terkunci (P-016). |
| Rilis lama tanpa aset `version.json`. | Workflow gagal dengan pesan eksplisit; konvensi aset rilis ditetapkan sejak rilis pertama. |

## 11. Acceptance Criteria

- [x] Workflow Validation berjalan dan lolos pada push ke `main` (bukti: [run 41002625549](https://github.com/Ndolzz/astranusa/actions/runs/41002625549), commit `57af8c7`; kedua job success). Verifikasi pada pull request mengikuti pada kontribusi berikutnya.
- [ ] Workflow Android Build menghasilkan artifact APK debug hasil verifikasi identitas.
- [x] Seluruh versi toolchain terkunci dan terdokumentasi pada bagian 8.
- [x] Tidak ada kredensial pada repository maupun log workflow.
- [ ] Build gagal dengan pesan jelas ketika validasi identitas atau versi tidak lolos (mekanisme terimplementasi; pembuktian kegagalan direkam pada verifikasi berikutnya).

Status acceptance diperbarui pada [SDD-01-FOUNDATION-REPORT](../reports/SDD-01-FOUNDATION-REPORT.md) seiring hasil eksekusi workflow diverifikasi.

## 12. Referensi

- [APK-COMPATIBILITY-SPEC](APK-COMPATIBILITY-SPEC.md)
- [GODOT-CONFIGURATION-SPEC](GODOT-CONFIGURATION-SPEC.md)
- [REPOSITORY-STRUCTURE-SPEC](REPOSITORY-STRUCTURE-SPEC.md)
- [FOUNDATION-TEST-PLAN](../verification/FOUNDATION-TEST-PLAN.md)
- [Decision Log](../../DECISION_LOG.md): P-004, P-007, P-011, P-012, P-013, P-014, P-015, P-016, O-018
