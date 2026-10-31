# CORE-FRAMEWORK-IMPLEMENTATION-TEST-SPEC: Spesifikasi Pengujian Implementasi Core Framework

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Dokumen desain: CORE-FRAMEWORK-TEST-ARCHITECTURE (Approved, 2026-10-31)
- Basis audit: HEAD `aa636633` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini menetapkan struktur pengujian final SDD-02: daftar suite, pustaka assertion bersama, fixture, titik suntikan stub, pemetaan kasus uji ke requirement dan acceptance criteria, serta rencana integrasi CI. Pengujian mengikuti keputusan OJ-5: harness kustom headless (P-008 ditegaskan kembali). Seluruh suite berjalan pada runner CI tanpa perangkat Android (CFR-NFR-001) dan tanpa dependensi baru (CFR-NFR-002). Pengujian manual perangkat dicatat pada tahap verifikasi, bukan bagian spesifikasi ini.

## 2. Struktur Direktori dan Suite

```
game/tests/
├── foundation_tests.gd          # Harness SDD-01; tetap utuh (CFR-INT-007).
├── core_test_lib.gd             # Pustaka assertion dan pelaporan bersama (class_name).
├── core_boot_tests.gd           # CB: boot, degradasi, penutupan, idempotensi, pause-resume.
├── core_save_tests.gd           # SV: store, checksum, atomik, antrean, ruang, pemulihan.
├── core_migration_tests.gd     # MG: rantai, jurnal, cadangan, mode aman, --migrate-only.
├── core_event_bus_tests.gd      # EB: register, dua mode, kebersihan listener.
├── core_config_tests.gd         # CF: pemuatan bertingkat, validasi, pengaturan.
├── core_scene_router_tests.gd   # SR: route bernama, pemuatan, rekaman headless.
├── core_state_tests.gd          # SM: StateMachine, AppState, konsistensi.
├── core_audio_tests.gd          # AU: kategori volume, polyphony, headless aman.
├── core_input_tests.gd          # IN: façade, injeksi sintetis, perilaku pause.
├── core_log_tests.gd            # LG: tingkat, buffer, rotasi, privasi jalur berkas.
├── core_pool_tests.gd           # OP dan RL: ObjectPool, CoreResourceLoader batas waktu.
├── core_integration_tests.gd     # IT: boot penuh, simpan-muat, migrasi boot, kill sim, pause-resume.
└── fixtures/
    └── migration/               # Fixture rantai migrasi per versi.
```

Penamaan `<lingkup>_tests.gd` sesuai REPOSITORY-STRUCTURE-SPEC bagian 6 nomor 4; `core_test_lib.gd` pustaka tanpa fungsi main; seluruh berkas dibuat pada tahap implementasi tanpa direktori kosong.

## 3. Pustaka Assertion Bersama

`core_test_lib.gd` menyediakan pencacahan kasus, assertion (`assert_eq`, `assert_true`, `assert_false`, `assert_not_null`, `assert_file_exists`, `assert_between`, `assert_status`), pesan kegagalan berkonteks (suite, kasus, harapan, aktual), akumulasi status, dan kode keluar proses. Setiap suite adalah skrip `SceneTree` headless: menginstansiasi unit teruji (pustaka murni langsung; layanan dengan stub penyuntikan), menjalankan kasus, mencetak ringkasan, keluar dengan kode bukan nol saat ada kegagalan. Pola menuruti `foundation_tests.gd` (konvensi tunggal P-008). Kegagalan assertion tidak menghentikan suite; kegagalan inisialisasi suite (fixture hilang) adalah kegagalan suite.

## 4. Titik Suntikan Stub

| Kebutuhan Perangkat | Titik Suntikan | Pengganti Pengujian |
| --- | --- | --- |
| Berkas `user://` | Pembungkas berkas pada `save_store.gd`. | Implementasi memori pada suite SV, MG, IT. |
| Ruang bebas | `save_space_probe.gd`. | Probe stub cukup dan tidak cukup (FR-022). |
| Waktu batas pemuatan | `time_source` pada `CoreResourceLoader`. | Sumber waktu suntik (SP-5). |
| Input sentuh | Lapisan injeksi `input_service.gd`. | `inject_press`, `inject_release` (FR-028). |
| Audio keluaran | Deteksi driver pada `audio_service.gd`. | Headless bawaan tanpa stub tambahan (FR-026). |
| Notifikasi OS | Handler terpisah AppBootstrap. | Pemanggilan langsung `handle_pause`, `handle_resume`, `handle_close_request`. |
| Layanan sekunder gagal | Stub penyuntikan `initialize`. | Layanan sekunder di-stub gagal (FR-002). |

Pustaka murni (StateMachine, AppState, ObjectPool, CoreResourceLoader) diuji tanpa autoload aktif sebagai bukti isolasi (requirement bagian 15 nomor 1).

## 5. Kasus Uji Khas Setiap Suite

1. `core_boot_tests.gd` (CB): urutan sepuluh langkah dan penolakan pelanggaran prasyarat (CB-01, FR-001); boot dengan layanan sekunder di-stub gagal tetap siap dan tercatat degradasi (CB-02, FR-002); penutupan normal menyiram antrean, menghentikan audio, menyiram log (CB-03, FR-003); boot ganda tidak mengubah stempel waktu store (CB-04, FR-004); handler pause-resume memanggil siraman antrean dan pemulihan konsisten (CB-05, INT-101, INT-102); penutupan atas permintaan (CB-06, INT-104); pengukuran waktu boot tercatat (CB-07, bagian 12 nomor 1); `app.ready` terpancar setelah READY (CB-08).
2. `core_integration_tests.gd` (IT): boot penuh mencapai READY tanpa error (IT-01, AC-002); migrasi otomatis pada boot dengan fixture versi lama, cadangan, dan jurnal `completed` (IT-02, AC-003, T-08); kill simulasi saat tulis dan saat migrasi: boot pemulihan tanpa kehilangan data (IT-03, IT-04, AC-004, INT-103, T-09, T-10); ubah-simpan-muat ulang pengaturan termasuk volume (IT-05, AC-006); rantai beberapa versi sekaligus (IT-06, T-12); pause-resume menyiram antrean dan memulihkan status serta route (IT-07, AC-005).
3. Kasus uji suite lainnya dirinci pada dokumen spesifikasi modul masing-masing (tabel kasus per suite); identitas kasus tidak tumpang tindih lintas dokumen.

## 6. Pemetaan Requirement Prioritas Must ke Suite

| Requirement | Suite Pembukti | 
| --- | --- |
| FR-001 s.d. FR-004 | CB; IT |
| FR-005 s.d. FR-008 | SR |
| FR-009, FR-010 | SM; SR |
| FR-011 s.d. FR-014 | EB |
| FR-015 s.d. FR-018 | CF; IT |
| FR-019 s.d. FR-023 | SV; MG; IT |
| FR-024 s.d. FR-026 | AU; IT |
| FR-027, FR-028 | IN; IT |
| FR-029 s.d. FR-031 | LG; CB; audit kode |
| FR-032, FR-033 | OP; audit kode |
| FR-034 | RL; SR |
| CFR-NFR-001, CFR-NFR-004 | Eksekusi CI penuh (seluruh suite headless; gdlint) |
| CFR-NFR-005 | OP; EB; audit alokasi; pengukuran memori pada verifikasi |
| CFR-NFR-006, CFR-NFR-007 | SV; IT; pengukuran waktu tulis pada verifikasi |
| CFR-NFR-008 | Audit kode terhadap SERVICE-RESPONSIBILITY-MATRIX |
| INT-001, INT-002 | SV; MG (checklist spesifikasi persistensi dan migrasi) |
| INT-003 | CB (peninjauan silang langkah 5 terhadap UPDATE-SYSTEM-SPEC bagian 6) |
| INT-004 | Eksekusi `--migrate-only` pada CI (MG-06) |
| INT-005 | Dokumen CORE-FRAMEWORK-IMPLEMENTATION-SPEC bagian 6; audit |
| INT-006 | Struktur sesuai tata letak final; harness fondasi |
| INT-007 | `foundation_tests.gd` tetap hijau; MF-02 scene boot (dispatch Android Build) |
| INT-101 s.d. INT-104 | CB; IT; IN; AU |

Requirement Should (FR-007, FR-008, FR-014, FR-027, FR-028, FR-034, NFR-005 s.d. NFR-007) memiliki kasus uji seluruhnya; NFR-005 s.d. NFR-007 memiliki target pengukuran pada verifikasi, bukan gerbang keras.

## 7. Pemetaan Acceptance Criteria ke Bukti

| ID | Bukti |
| --- | --- |
| CFR-AC-001 | Seluruh suite hijau pada workflow Validation; audit kode untuk butir tanpa bukti otomatis (CFR-FR-031, CFR-FR-033, CFR-NFR-008). |
| CFR-AC-002 | CB-04, IT-01. |
| CFR-AC-003 | IT-02 (fixture versi lama, cadangan, jurnal). |
| CFR-AC-004 | IT-03, IT-04 (simulasi); kill proses sungguhan manual pada verifikasi perangkat. |
| CFR-AC-005 | CB-05, IT-07. |
| CFR-AC-006 | IT-05, CF-04, AU-01. |
| CFR-AC-007 | `foundation_tests.gd` hijau; gdlint bersih; dispatch Android Build hijau; MF-02 lolos. |
| CFR-AC-008 | Gerbang proses: spesifikasi disetujui pemilik proyek sebelum implementasi. |

## 8. Integrasi CI (Rencana; Tidak Dieksekusi pada Tahap Ini)

1. Workflow Validation memperoleh langkah tambahan setelah `foundation_tests.gd`: menjalankan setiap suite core secara berurutan dengan `godot --headless --script res://tests/<suite>.gd`, ditambah `migrate_stores.gd --migrate-only` terhadap fixture. Setiap kegagalan suite menggagalkan job dengan anotasi eksplisit (CI-PIPELINE-SPEC bagian 3 nomor 4).
2. Perubahan hanya langkah: versi Godot, gdtoolkit, dan seluruh toolchain terkunci tidak berubah (P-007, P-011, P-012); tidak ada workflow baru; pemicu tidak berubah. Perubahan dilakukan pada tahap implementasi dengan persetujuan pemilik proyek karena CI-PIPELINE-SPEC mengikat; spesifikasi ini hanya merencanakan.
3. `tests/` dan `tools/` tetap dikecualikan dari export APK.
4. Durasi total suite dijaga ringan (prinsip P-012); fixture terbesar di bawah 1 MB; durasi dicatat pada laporan verifikasi; bila melampaui anggaran wajar (dua menit), struktur dirapikan tanpa menambah dependensi (CFR-NFR-002).

## 9. Batasan

1. Kill proses sungguhan, pause sungguhan, dan pengujian perangkat nyata dilakukan manual pada tahap verifikasi dan dicatat pada laporan tahap (MF SDD-01 ditambah butir SDD-02).
2. Audit kode (FR-027 pembacaan input, FR-031 penelanan senyap, FR-033 alokasi, NFR-008 tanggung jawab tunggal) dilakukan pada tahap Code Audit dengan checklist yang dirinci dari dokumen spesifikasi.
3. Pengukuran jejak memori dan waktu tulis dicatat pada tahap verifikasi (CFR-NFR-005 s.d. NFR-007), bukan gerbang assertion CI.

## 10. Referensi

- CORE-FRAMEWORK-TEST-ARCHITECTURE seluruh bagian; CORE-FRAMEWORK-REQUIREMENTS bagian 15, 16.
- UPDATE-TEST-PLAN T-08 s.d. T-12; CI-PIPELINE-SPEC bagian 3 s.d. 5.
- REPOSITORY-STRUCTURE-SPEC bagian 6, 7.
- SERVICE-RESPONSIBILITY-MATRIX (kolom suite pengujian).

## 11. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
