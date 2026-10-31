# CORE-FRAMEWORK-TEST-ARCHITECTURE: Arsitektur Pengujian Core Framework

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement terkait: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Basis audit: HEAD `ec3ccae` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini merancang struktur pengujian Core Framework SDD-02: suite harness kustom headless, pustaka assertion bersama, fixture, integrasi ke workflow Validation, serta pemetaan acceptance criteria ke bukti pengujian. Keputusan OJ-5 menegaskan harness kustom (diputuskan pemilik proyek 2026-10-30, menegaskan kembali P-008 untuk SDD-02). Ruang lingkup: pengujian otomatis SDD-02; pengujian manual perangkat (termasuk kill proses sungguhan) dicatat sebagai verifikasi perangkat pada tahap verifikasi, bukan bagian arsitektur ini.

## 2. Requirement yang Dilayani

Requirement bagian 15 seluruhnya (testability), CFR-NFR-001 (headless paripurna), CFR-NFR-002 (tanpa dependensi baru), CFR-NFR-004 (lint bersih), CFR-INT-004 (integrasi CI), CFR-INT-007 (kompatibilitas SDD-01), CFR-AC-001 s.d. CFR-AC-008, serta P-008 dan keputusan OJ-5.

## 3. Rancangan Teknis

### 3.1 Struktur Direktori Pengujian

```
game/tests/
├── foundation_tests.gd          # Harness SDD-01; tetap utuh (CFR-INT-007).
├── core_test_lib.gd             # Pustaka assertion dan pelaporan bersama (class_name).
├── core_boot_tests.gd           # Boot, degradasi, penutupan, idempotensi, pause-resume.
├── core_save_tests.gd           # Store, checksum, atomik, antrean, ruang, pemulihan.
├── core_migration_tests.gd      # Rantai, jurnal, cadangan, mode aman, --migrate-only.
├── core_event_bus_tests.gd      # Register, dua mode, kebersihan listener.
├── core_config_tests.gd         # Pemuatan bertingkat, validasi, pengaturan.
├── core_scene_router_tests.gd  # Route bernama, pemuatan, rekaman headless.
├── core_state_tests.gd          # StateMachine, AppState, konsistensi status-route.
├── core_audio_tests.gd          # Kategori volume, polyphony, headless aman.
├── core_input_tests.gd          # Façade, injeksi sintetis, perilaku pause.
├── core_log_tests.gd            # Tingkat, buffer, rotasi, privasi jalur berkas.
├── core_pool_tests.gd           # ObjectPool, CoreResourceLoader batas waktu.
├── core_integration_tests.gd    # Boot penuh, simpan-muat, migrasi boot, kill sim, pause-resume.
└── fixtures/                    # Fixture data: store versi lama, berkas rusak, log pra-isi.
    └── migration/               # Fixture rantai migrasi per versi.
```

Penamaan mengikuti `<lingkup>_tests.gd` (REPOSITORY-STRUCTURE-SPEC bagian 6 nomor 4); `core_test_lib.gd` adalah pustaka, bukan suite, dan tidak memiliki fungsi main. Seluruh direktori dan berkas dibuat pada tahap implementasi; tidak ada direktori kosong (spesifikasi bagian 7).

### 3.2 Pustaka Assertion Bersama

`core_test_lib.gd` menyediakan: pencacahan kasus, assertion (`assert_eq`, `assert_true`, `assert_not_null`, `assert_file_exists`, dan lain-lain), pesan kegagalan dengan konteks, akumulasi status, dan kode keluar proses. Setiap suite adalah skrip `SceneTree` headless yang: menginstansiasi unit yang diuji (pustaka murni langsung; layanan dengan stub penyuntikan), menjalankan kasus, mencetak ringkasan, dan keluar dengan kode bukan nol saat ada kegagalan. Pola ini menuruti `foundation_tests.gd` SDD-01 sehingga konvensi tetap tunggal (P-008).

### 3.3 Titik Suntikan Stub (Requirement Bagian 15 Nomor 2)

| Kebutuhan Perangkat | Titik Suntikan | Pengganti Pengujian |
| --- | --- | --- |
| Berkas pada `user://` | Pembungkas berkas pada `save_store.gd` | Implementasi memori pada suite save dan migration. |
| Audio keluaran | Deteksi driver dummy pada `audio_service.gd` | Headless bawaan; tanpa stub tambahan. |
| Layar sentuh dan input | Lapisan injeksi pada `input_service.gd` | `inject_press`, `inject_release` (FR-028). |
| Waktu pada batas pemuatan | Parameter timeout `CoreResourceLoader` | Nilai kecil untuk memicu batas waktu. |
| Ruang bebas | `save_space_probe.gd` | Probe stub: cukup atau tidak cukup (FR-022). |
| Notifikasi OS pause/resume/tutup | Handler terpisah pada AppBootstrap | Pemanggilan langsung handler (INT-101, INT-102, INT-104). |

Pustaka murni (GameState, ObjectPool, CoreResourceLoader) diuji tanpa autoload aktif sebagai bukti isolasi (requirement bagian 15 nomor 1).

### 3.4 Integrasi CI (CFR-INT-004)

1. Workflow Validation memperoleh langkah tambahan setelah `foundation_tests.gd`: menjalankan setiap suite core secara berurutan dengan `godot --headless --script res://tests/<suite>.gd`, ditambah `--migrate-only` terhadap fixture. Setiap kegagalan suite menggagalkan job dengan anotasi eksplisit (prinsip CI-PIPELINE-SPEC bagian 3 nomor 4).
2. Perubahan ini adalah perubahan langkah saja: versi Godot, gdtoolkit, dan seluruh toolchain terkunci tidak berubah (P-007, P-011, P-012); tidak ada workflow baru; pemicu tidak berubah. Perubahan dilakukan pada tahap implementasi dengan persetujuan pemilik proyek karena CI-PIPELINE-SPEC mengikat.
3. Seluruh suite berjalan pada runner tanpa perangkat Android (CFR-NFR-001); `tests/` dan `tools/` tetap dikecualikan dari export APK (REPOSITORY-STRUCTURE-SPEC bagian 7 nomor 3).

### 3.5 Pemetaan Acceptance Criteria ke Bukti

| ID | Kriteria | Bukti Pengujian |
| --- | --- | --- |
| AC-001 | Seluruh requirement Must terimplementasi dan lolos CI headless. | Seluruh suite bagian 3.1 hijau pada workflow Validation. |
| AC-002 | Boot normal headless siap tanpa error; boot ganda tidak menulis store. | `core_boot_tests.gd`: boot siap; perbandingan mtime store pada boot ganda (FR-004). |
| AC-003 | Store fixture versi lama dimigrasi otomatis dengan cadangan; data tidak hilang. | `core_integration_tests.gd`: migrasi boot dengan fixture; verifikasi isi dan cadangan. |
| AC-004 | Kill saat tulis dan migrasi pulih tanpa kehilangan data. | `core_integration_tests.gd`: kill simulasi (penulisan jurnal `in_progress` dan berkas sementara terputus, lalu boot pemulihan); kill proses sungguhan manual pada perangkat verifikasi. |
| AC-005 | Pause-resume: antrean disiram; status dan route pulih konsisten. | `core_boot_tests.gd` dan `core_integration_tests.gd`: pemanggilan handler pause/resume. |
| AC-006 | Pengaturan pemain bertahan setelah mulai ulang. | `core_integration_tests.gd`: ubah-simpan-muat ulang pengaturan termasuk volume. |
| AC-007 | Kompatibilitas SDD-01 utuh. | `foundation_tests.gd` tetap hijau; gdlint bersih; dispatch Android Build hijau; scene boot menampilkan teks versi (MF-02). |
| AC-008 | Spesifikasi SDD-02 disetujui sebelum implementasi. | Bukan bukti pengujian; gerbang proses SDD pada tahap Specification. |

## 4. Kontrak Antarmodul

Arsitektur ini tidak menambah antarmuka produk; kontraknya adalah konvensi: setiap requirement Must baru wajib memiliki kasus pada suite yang terdaftar pada SERVICE-RESPONSIBILITY-MATRIX sebelum implementasi dinyatakan selesai (requirement bagian 15 nomor 4). Suite tidak membagi status lintas berkas; tiap suite mandiri dan dapat dijalankan terpisah.

## 5. Penanganan Kesalahan

Kegagalan assertion menghasilkan pesan dengan konteks (suite, kasus, nilai harapan dan aktual) dan mencatat kegagalan tanpa menghentikan seluruh kasus dalam satu suite; akhir suite mengeluarkan ringkasan dan kode keluar. Kegagalan inisialisasi suite (fixture hilang, berkas rusak tidak sesuai rencana) dianggap kegagalan suite itu sendiri dan dilaporkan eksplisit, tidak ditelan.

## 6. Pertimbangan Performa

Total durasi seluruh suite dijaga ringan untuk Validation yang berjalan pada setiap push (prinsip P-012: validasi cepat): suite unit berukuran kecil; suite integrasi menghindari pengulangan boot penuh lebih dari yang diperlukan; fixture berukuran minimal tetapi representatif (store terbesar fixture di bawah 1 MB). Durasi total suite dicatat pada laporan verifikasi; bila melebihi anggaran wajar (misalnya dua menit), struktur dirapikan pada tahap yang sama, bukan ditambah dependensi framework (NFR-002).

## 7. Alternatif yang Dipertimbangkan

| Alternatif | Kelebihan | Kekurangan | Alasan Tidak Dipilih |
| --- | --- | --- | --- |
| Mengadopsi GUT atau gdUnit4 (OJ-5 opsi b dan c). | Assertion, laporan, dan integrasi CI siap pakai. | Menambah dependensi pihak ketiga yang selama ini dihindari (NFR-002); mengubah harness fondasi; vendor berkas baru pada repository. | OJ-5 diputuskan: harness kustom (2026-10-30). |
| Satu berkas suite raksasa. | Tanpa berkas banyak. | Lama berjalan sebagian; kegagalan sulit dilokalisasi; bertentangan pelaporan per lingkup. | Suite per lingkup sesuai penamaan spesifikasi. |
| Menjalankan suite hanya pada pull request. | Beban CI turun. | Push langsung ke main (praktik proyek ini sejak SDD-01) tidak tervalidasi. | P-012: Validation pada push dan pull request. |

## 8. Risiko Teknis dan Mitigasi

| Risiko | Kemungkinan | Dampak | Mitigasi |
| --- | --- | --- | --- |
| Biaya struktur harness kustom menumpuk seiring jumlah suite. | Sedang | Sedang | Pustaka bersama 3.2; evaluasi ulang OJ-5 pada tahap berikutnya bila biaya melebihi manfaat (tercatat pada OJ-5). |
| Kill simulasi tidak merepresentasikan kill proses sungguhan. | Sedang | Sedang | Kill sungguhan pada perangkat manual saat verifikasi (AC-004); simulasi menutupi titik kritis pada CI. |
| Langkah CI baru memperlambat Validation. | Rendah | Rendah | Pengukuran durasi; suite ringkas; penggabungan ke job validate yang ada. |
| Fixture tidak sinkron dengan langkah migrasi baru. | Rendah | Sedang | Kewajiban fixture per langkah (SAVE-SERVICE-DESIGN bagian 3.7 nomor 6); audit checklist. |

## 9. Strategi Pengujian (Meta)

Arsitektur ini adalah strategi pengujian itu sendiri; penerapannya diverifikasi pada tahap Verification SDD-02: seluruh suite hijau pada runner CI, `--migrate-only` hijau, hasil dan durasi dicatat pada laporan tahap, dan pengujian manual perangkat (MF SDD-01 ditambah kill sungguhan dan pause sungguhan) dilaporkan pemilik proyek.

## 10. Kriteria Penerimaan Desain

1. Setiap requirement berprioritas Must memiliki suite dan kasus yang terpetakan (bagian 3.5 dan SERVICE-RESPONSIBILITY-MATRIX).
2. Struktur pengujian tanpa dependensi baru (NFR-002) dan sepenuhnya headless (NFR-001).
3. Harness fondasi SDD-01 tetap utuh dan tetap dijalankan (CFR-INT-007).
4. Perubahan CI terbatas pada langkah tambahan tanpa perubahan toolchain terkunci.
5. Pemilik proyek menyetujui sebelum tahap Specification.

## 11. Referensi

- CORE-FRAMEWORK-REQUIREMENTS bagian 15, 16, 17 (OJ-5)
- CI-PIPELINE-SPEC bagian 3, 4, 5
- REPOSITORY-STRUCTURE-SPEC bagian 4, 6, 7
- SAVE-SERVICE-DESIGN (fixture, `--migrate-only`, kill simulasi)
- INITIALIZATION-LIFECYCLE-DESIGN bagian 9 (handler untuk pengujian)
- DECISION_LOG: P-008, P-011, P-012, OJ-5

## 12. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
