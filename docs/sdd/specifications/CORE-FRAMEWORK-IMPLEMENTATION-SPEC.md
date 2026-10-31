# CORE-FRAMEWORK-IMPLEMENTATION-SPEC: Spesifikasi Implementasi Core Framework

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Dokumen desain: kesembilan dokumen `docs/sdd/technical-design/` (Approved, 2026-10-31)
- Basis audit: HEAD `aa636633` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini adalah dokumen induk spesifikasi implementasi SDD-02. Tujuannya menetapkan kontrak yang mengikat implementasi Core Framework: tata letak berkas final, daftar autoload final, konvensi pelaporan kesalahan lintas layanan, kebijakan alokasi objek pada loop utama, kontrak boot, penutupan, dan siklus hidup Android, serta integrasi terhadap spesifikasi lintas tahap yang telah disetujui. Dokumen ini tidak mengulang tanda tangan antarmuka (lihat SERVICE-API-SPEC) dan tidak mengulang perilaku per modul (lihat dokumen spesifikasi modul).

Di dalam lingkup: seluruh kode pada `game/src/core/`, alat headless `game/tools/` milik SDD-02, dan struktur pengujian pada `game/tests/` milik SDD-02.

Di luar lingkup: kode implementasi (ditulis pada tahap Implementation setelah spesifikasi disetujui, CFR-AC-008), scene, gameplay, aset, skema data konten (SDD-03), struktur lobby (SDD-04), kontrol pertandingan (SDD-05), dan perubahan konfigurasi CI (rencana langkah CI pada CORE-FRAMEWORK-IMPLEMENTATION-TEST-SPEC diimplementasikan terpisah pada tahap implementasi dengan persetujuan pemilik proyek).

## 2. Referensi Dokumen

- CORE-FRAMEWORK-REQUIREMENTS (requirement; 34 CFR-FR, 8 CFR-NFR, 11 CFR-INT, 8 CFR-AC).
- Kesembilan dokumen technical design, khususnya CORE-FRAMEWORK-ARCHITECTURE (induk desain), SERVICE-DEPENDENCY-DESIGN (graf ketergantungan), dan INITIALIZATION-LIFECYCLE-DESIGN (urutan boot).
- DATA-PERSISTENCE-SPEC, DATA-MIGRATION-SPEC, UPDATE-SYSTEM-SPEC, APK-COMPATIBILITY-SPEC (spesifikasi lintas tahap yang mengikat).
- REPOSITORY-STRUCTURE-SPEC (struktur dan penamaan), GODOT-CONFIGURATION-SPEC (mandat kebijakan alokasi bagian 5 nomor 3), CI-PIPELINE-SPEC (integrasi pengujian).
- DECISION_LOG: D-001 s.d. D-006, P-001 s.d. P-022; keputusan spesifikasi disetujui pemilik proyek pada 2026-10-31 (dicatat pada Bagian 2F DECISION_LOG).

## 3. Tata Letak Berkas Final

Seluruh berkas berikut dibuat pada tahap Implementation, tidak pada tahap spesifikasi ini. Penamaan mengikuti REPOSITORY-STRUCTURE-SPEC bagian 6 (skrip `snake_case.gd`, `class_name` PascalCase, teknis berbahasa Inggris, narasi dokumentasi berbahasa Indonesia).

| Berkas | Jenis | Modul | Keterangan |
| --- | --- | --- | --- |
| `game/src/core/app_bootstrap.gd` | Autoload `AppBootstrap` | A | Urutan inisialisasi, degradasi, penutupan, notifikasi Android. |
| `game/src/core/log_service.gd` | Autoload `LogService` | I | Log bertingkat, buffer, rotasi. |
| `game/src/core/event_bus.gd` | Autoload `EventBus` | D | Publish-subscribe tervalidasi. |
| `game/src/core/core_events.gd` | `class_name CoreEvents` | D | Register konstanta event SDD-02 beserta mode, pemilik, dan kunci payload. Berkas ini diambil dari EVENT-BUS-DESIGN bagian 3.1 yang belum tercantum pada tabel tata letak dokumen desain; penambahannya pada tata letak final adalah normalisasi celah desain, bukan perubahan keputusan. |
| `game/src/core/config_service.gd` | Autoload `ConfigService` | E | Konfigurasi bertingkat, pengaturan pemain. |
| `game/src/core/save_service.gd` | Autoload `SaveService` | F | Antrean tulis, momen simpan, orkestrasi boot langkah 5. |
| `game/src/core/save_store.gd` | `class_name SaveStore` | F | Amplop, checksum, penulisan atomik, pemuatan, mode aman, karantina. |
| `game/src/core/save_migration.gd` | `class_name SaveMigration` | F | Registri langkah, jurnal, cadangan, pemulihan. |
| `game/src/core/save_space_probe.gd` | `class_name SaveSpaceProbe` | F | Strategi pemeriksaan ruang bebas. |
| `game/src/core/audio_service.gd` | Autoload `AudioService` | G | Volume kategori, pemutaran terkendali, polyphony. |
| `game/src/core/input_service.gd` | Autoload `InputService` | H | Façade action map, input sintetis. |
| `game/src/core/scene_router.gd` | Autoload `SceneRouter` | B | Route bernama, pemuatan asinkron, pelepasan memori. |
| `game/src/core/state_machine.gd` | `class_name StateMachine` (RefCounted) | C | Pustaka murni. |
| `game/src/core/app_state.gd` | `class_name AppState` (RefCounted) | C | Status aplikasi tingkat atas. |
| `game/src/core/object_pool.gd` | `class_name ObjectPool` (RefCounted) | J | Pool generik. |
| `game/src/core/resource_loader.gd` | `class_name CoreResourceLoader` (RefCounted) | J | Pemuatan asinkron dengan batas waktu. |
| `game/tools/migrate_stores.gd` | Skrip headless | F | Mode `--migrate-only`; penamaan "kata kerja dan objek" sesuai REPOSITORY-STRUCTURE-SPEC bagian 6 nomor 5 (menggantikan nama `migrate_only.gd` pada dokumen desain). |
| `game/src/core/app_version.gd` | Ada sejak SDD-01 | - | Sumber versi aplikasi (P-004); dipakai SaveService untuk `app_version_written`. |

Berkas pengujian dan fixture dirinci pada CORE-FRAMEWORK-IMPLEMENTATION-TEST-SPEC. Tidak ada direktori kosong (REPOSITORY-STRUCTURE-SPEC bagian 7 nomor 1); seluruh berkas pada `tests/` dan `tools/` tetap dikecualikan dari export APK melalui `exclude_filter` yang telah ada.

## 4. Daftar Autoload Final dan Urutan Deklarasi

Sesuai P-020: delapan autoload dengan urutan deklarasi pada `project.godot` selaras dengan urutan inisialisasi: AppBootstrap, LogService, EventBus, ConfigService, SaveService, AudioService, InputService, SceneRouter. Urutan yang ditegakkan adalah panggilan `initialize()` eksplisit oleh AppBootstrap sesuai requirement bagian 9; urutan deklarasi adalah lapisan pertahanan pertama. Pendaftaran dilakukan pada tahap Implementation dan saat itu TF-01 s.d. TF-08 diverifikasi ulang (CFR-INT-006, CFR-INT-007). `GameState` (StateMachine, AppState), `ObjectPool`, `CoreResourceLoader`, `SaveStore`, `SaveMigration`, `SaveSpaceProbe`, dan `CoreEvents` bukan autoload.

## 5. Konvensi Pelaporan Kesalahan Lintas Layanan

Klasifikasi mengikuti requirement bagian 13: kegagalan fatal boot (layanan kritis: LogService, ConfigService dasar, SaveService), kegagalan terdegradasi (layanan sekunder: AudioService, InputService; ditolak operasi per kejadian pada modul lain), dan kegagalan data (store, konfigurasi, resource).

1. Dua kelas pelaporan dibedakan tajam.
   a. Kegagalan operasional yang wajar pada runtime (berkas rusak, ruang tidak cukup, route tak terdaftar, stok pool habis, batas polyphony tercapai, batas waktu terlampaui): operasi mengembalikan status terdefinisi; aplikasi tetap berjalan sesuai kelas kegagalannya.
   b. Pelanggaran kontrak oleh pemanggil (argumen tidak sah, prasyarat dilanggar, event tak terdaftar, pelepasan objek dua kali, akses di luar antarmuka): operasi ditolak, dicatat ERROR pada LogService, dan memakai `push_error` agar kegagalan terlihat pada keluaran CI; eksekusi tidak dilanjutkan dengan data tidak valid.
2. Status kembalian memakai konstanta string yang didefinisikan pada berkas layanan masing-masing dan dirinci pada SERVICE-API-SPEC. Operasi tanpa muatan data mengembalikan status; operasi dengan muatan data mengembalikan Dictionary tunggal dengan kunci `status` dan kunci muatan opsional (`handle`, `resource`, `data`, `error`).
3. Setiap layanan menyediakan kueri status yang dapat ditanyai kapan pun (`is_ready`, `degraded_services`, `store_status`, `file_mode_status`, dan lain-lain sesuai SERVICE-API-SPEC). Tidak ada kegagalan yang hanya terlihat pada log (CFR-FR-031).
4. Pesan kepada pemain hanya untuk kegagalan yang menimpa pengalaman bermain: pesan non-teknis sesuai requirement bagian 13 nomor 2; pesan teknis lengkap hanya pada log.
5. Tidak ada pengecualian yang ditelan tanpa mencatat; penanganan listener EventBus mengikuti EVENT-BUS-SPEC.

## 6. Kebijakan Alokasi Objek pada Loop Utama

Kebijakan ini memenuhi mandat GODOT-CONFIGURATION-SPEC bagian 5 nomor 3, CFR-FR-033, CFR-NFR-005, dan CFR-INT-005.

1. Definisi jalur per-frame framework: siraman antrean deferred EventBus (`_process`), `acquire()` dan `release()` ObjectPool, seluruh API pembacaan InputService, dan pengambilan hasil `CoreResourceLoader.poll()` yang dipanggil per frame selama transisi.
2. Larangan pada jalur per-frame framework: mengalokasikan objek baru (`new`), menumbuhkan Array atau Dictionary, membuat string berukuran besar, memuat resource secara sinkron, dan memicu I/O berkas. Jeda antrean, indeks siraman, dan peta injeksi dialokasikan saat inisialisasi atau prewarm dan digunakan ulang.
3. `acquire()` tidak pernah mengalokasikan implisit: stok habis mengembalikan null dan pemanggil memutuskan `grow(n)` atau menolak operasi. `grow(n)` adalah operasi eksplisit yang dialokasikan di luar jalur per-frame sensitif dan dicatat pada log.
4. Pengecualian terdokumentasi: `emit()` pada EventBus boleh menambah antrean (kejadian dipicu pemanggil, bukan jalur menganggur); pemangkasan buffer LogService hanya pada kejadian batas terlampaui; keduanya bukan jalur menganggur.
5. Penegakan: butir audit kode per tahap memeriksa larangan nomor 2 pada seluruh fungsi yang berjalan per frame; suite pengujian membuktikan penggunaan ulang (acquire berturut-turut dalam stok mengembalikan objek dari pool tanpa alokasi baru; siraman antrean memakai wadah yang digunakan ulang).
6. Jejak memori tetap layanan core dilaporkan pada verifikasi (CFR-NFR-005); anggaran menyeluruh 60 FPS dan 1 GB RSS tetap milik TECHNICAL_ARCHITECTURE bagian 10 dan divalidasi mulai SDD-12.

## 7. Kontrak Boot, Penutupan, dan Siklus Hidup Android

1. Urutan inisialisasi mengikuti INITIALIZATION-LIFECYCLE-DESIGN bagian 3.2 sepuluh langkah tanpa perubahan. Setiap langkah dipanggil eksplisit oleh AppBootstrap; hasil diperiksa sebelum langkah berikutnya; pelanggaran prasyarat adalah kegagalan eksplisit (CFR-FR-001).
2. AppBootstrap mengekspos antarmuka pada SERVICE-API-SPEC; handler `handle_pause()`, `handle_resume()`, dan `handle_close_request()` ditulis sebagai metode terpisah yang dapat dipanggil pengujian tanpa notifikasi sistem operasi.
3. Penutupan normal menjalankan urutan tetap: siram antrean tulis SaveService, hentikan seluruh audio dan kembalikan node ke pool, catat status dan siram buffer LogService, izinkan proses keluar; setiap langkah diberi tenggat internal dan tenggat terlampaui menghasilkan peringatan tanpa menggantung penutupan (CFR-FR-003).
4. Pemetaan notifikasi: `NOTIFICATION_APPLICATION_PAUSED` (hentikan audio, abaikan input, siram antrean tulis dan buffer log), `NOTIFICATION_APPLICATION_RESUMED` (pulihkan), `NOTIFICATION_WM_CLOSE_REQUEST` (penutupan normal), penghentian paksa tanpa notifikasi (ketahanan bergantung penulisan atomik dan jurnal; pemulihan pada boot berikutnya) (CFR-INT-101 s.d. 104).
5. Boot normal tanpa perubahan versi schema tidak menulis store apa pun (CFR-FR-004); waktu boot diukur dari awal langkah 2 hingga status siap dan dicatat (requirement bagian 12 nomor 1).

## 8. Integrasi Spesifikasi Lintas Tahap

| Spesifikasi | Ketentuan yang Mengikat Implementasi SDD-02 |
| --- | --- |
| DATA-PERSISTENCE-SPEC | Amplop, checksum, penulisan atomik, antrean tunggal, kepemilikan `user://saves/`, inisialisasi pertama, pemeriksaan ruang; checklist bagian 13 dipenuhi SaveService (CFR-INT-001). |
| DATA-MIGRATION-SPEC | Registri rantai, jurnal, cadangan retensi dua, pemulihan, idempotensi, mode `--migrate-only`; checklist bagian 11 (CFR-INT-002). |
| UPDATE-SYSTEM-SPEC | Urutan boot bagian 6 dipetakan satu-ke-satu pada langkah 5 (CFR-INT-003); manifest aset penimpa adalah titik sedia tanpa paket aktif (O-020). |
| APK-COMPATIBILITY-SPEC | Tidak ada perubahan identitas paket, versi, keystore, dan preset export oleh SDD-02. |
| REPOSITORY-STRUCTURE-SPEC | Tata letak bagian 3-7: tanpa direktori kosong, penamaan bagian 6, `tests/` dan `tools/` dikecualikan dari export (CFR-INT-006). |
| GODOT-CONFIGURATION-SPEC | Tanpa perubahan konfigurasi proyek selain deklarasi autoload; kebijakan alokasi ditetapkan bagian 6 dokumen ini (CFR-INT-005). |
| CI-PIPELINE-SPEC | Pengujian SDD-02 berjalan pada workflow Validation; perubahan berupa langkah tambahan saja, pada tahap implementasi dengan persetujuan pemilik proyek (CFR-INT-004). |

## 9. Batasan dan Hal yang Tidak Termasuk Cakupan

1. Tidak ada logika gameplay, pengetahuan konten, atau akses lapisan atas dari core.
2. Tidak ada layanan jaringan, kredensial, atau izin baru; aplikasi tetap offline penuh.
3. Tidak ada dependensi pihak ketiga baru (CFR-NFR-002); hanya API stabil Godot 4.7.2 (CFR-NFR-003).
4. Tidak ada perubahan pada scene boot SDD-01 dan harness fondasi selain penambahan suite baru (CFR-INT-007).
5. Skema data konten dan validator penuh menyusul SDD-03 (O-005, O-006); struktur isi store per domain data menyusul tahap pemiliknya.

## 10. Acceptance Criteria Dokumen

- [ ] Seluruh tanda tangan pada SERVICE-API-SPEC konsisten dengan dokumen modul dan dengan tabel izin ketergantungan SERVICE-DEPENDENCY-DESIGN.
- [ ] Seluruh requirement Must memiliki pemetaan kasus uji pada CORE-FRAMEWORK-IMPLEMENTATION-TEST-SPEC.
- [ ] Seluruh keputusan SP-1 s.d. SP-9 tercantum sesuai persetujuan pemilik proyek 2026-10-31 dan tidak ada keputusan belum disetujui yang ditulis sebagai keputusan final.
- [ ] Tidak ada spesifikasi yang bertentangan dengan Requirements, Technical Design, dan spesifikasi lintas tahap.
- [ ] Pemilik proyek menyetujui seluruh dokumen sebelum tahap Implementation dimulai (CFR-AC-008).

## 11. Referensi

- CORE-FRAMEWORK-REQUIREMENTS bagian 4, 7 s.d. 16.
- CORE-FRAMEWORK-ARCHITECTURE bagian 3, 4, 5, 6; SERVICE-DEPENDENCY-DESIGN bagian 3, 4; INITIALIZATION-LIFECYCLE-DESIGN bagian 3.
- SAVE-SERVICE-DESIGN bagian 3.9 (pemetaan urutan boot pembaruan).
- REPOSITORY-STRUCTURE-SPEC bagian 3 s.d. 7; GODOT-CONFIGURATION-SPEC bagian 5.
- DECISION_LOG: P-019 s.d. P-022; keputusan spesifikasi SDD-02 (Bagian 2F).

## 12. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
