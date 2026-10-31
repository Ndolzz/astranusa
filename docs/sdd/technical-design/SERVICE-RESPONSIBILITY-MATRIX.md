# SERVICE-RESPONSIBILITY-MATRIX: Matriks Tanggung Jawab Layanan Core

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement terkait: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Basis audit: HEAD `ec3ccae` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini adalah sumber tunggal pemetaan tanggung jawab, antarmuka, dan kepemilikan pengujian seluruh modul Core Framework. Tujuannya menegakkan tanggung jawab tunggal (CFR-NFR-008) dan menjadikan setiap requirement dapat dilacak ke modul penanggung jawab dan pengujian pembuktinya. Ruang lingkup: sepuluh modul pada requirement bagian 7. Dokumen ini tidak mengulangi rancangan teknis (lihat CORE-FRAMEWORK-ARCHITECTURE dan dokumen khusus) dan tidak menetapkan arah ketergantungan (lihat SERVICE-DEPENDENCY-DESIGN).

## 2. Requirement yang Dilayani

CFR-NFR-008 (tanggung jawab tunggal dan satu berkas entri utama), CFR-FR-001 s.d. FR-034 (penugasan modul), requirement bagian 7 dan 15. Matriks ini juga menjadi lampiran bukti bagi CFR-AC-001 saat setiap requirement Must dibuktikan pengujian otomatisnya.

## 3. Matriks Tanggung Jawab

| Modul | Berkas Entri | Jenis | Tanggung Jawab Utama | Requirement | Kelas Kegagalan | Suite Pengujian |
| --- | --- | --- | --- | --- | --- | --- |
| AppBootstrap | `app_bootstrap.gd` | Autoload | Urutan inisialisasi, degradasi layanan, penutupan normal, notifikasi Android. | FR-001 s.d. FR-004, INT-101 s.d. INT-104, INT-003 | Fatal boot / terdegradasi | `core_boot_tests.gd` |
| SceneRouter | `scene_router.gd` | Autoload | Routing scene bernama, pemuatan asinkron, pelepasan memori transisi, rekaman headless. | FR-005 s.d. FR-008, FR-010 | Terdegradasi / data | `core_scene_router_tests.gd` |
| GameState | `state_machine.gd`, `app_state.gd` | Pustaka murni | State machine generik dan status aplikasi tingkat atas. | FR-009, FR-010 | Terdegradasi | `core_state_tests.gd` |
| EventBus | `event_bus.gd` | Autoload | Publish-subscribe tervalidasi, dua mode pengiriman, kebersihan listener. | FR-011 s.d. FR-014 | Terdegradasi | `core_event_bus_tests.gd` |
| ConfigService | `config_service.gd` | Autoload | Pemuatan konfigurasi bertingkat, validasi dasar, antarmuka pengaturan pemain. | FR-015 s.d. FR-018, INT-005 | Fatal boot (dasar) / data (penimpa) | `core_config_tests.gd` |
| SaveService | `save_service.gd` (+ `save_store.gd`, `save_migration.gd`, `save_space_probe.gd`) | Autoload + pustaka pendukung | Persistensi store, antrean tulis, migrasi, jurnal, cadangan, pemulihan. | FR-019 s.d. FR-023, INT-001 s.d. INT-004 | Fatal boot / data | `core_save_tests.gd`, `core_migration_tests.gd` |
| AudioService | `audio_service.gd` | Autoload | Volume per kategori, pemutaran terkendali, batas polyphony, headless aman. | FR-024 s.d. FR-026 | Terdegradasi | `core_audio_tests.gd` |
| InputService | `input_service.gd` | Autoload | Façade action map, input sintetis untuk pengujian. | FR-027, FR-028 | Terdegradasi | `core_input_tests.gd` |
| LogService | `log_service.gd` | Autoload | Log bertingkat, buffer dan siraman, log bergulir, pelaporan kegagalan. | FR-029 s.d. FR-031 | Fatal boot (init) / terdegradasi (tulis) | `core_log_tests.gd` |
| ObjectPool | `object_pool.gd` | Pustaka murni | Pool acquire-release generik dengan pramasukan dan reset. | FR-032 | Terdegradasi | `core_pool_tests.gd` |
| CoreResourceLoader | `resource_loader.gd` | Pustaka murni | Pemuatan resource asinkron dengan batas waktu. | FR-033 (dukungan), FR-034 | Data | `core_pool_tests.gd` |
| Integrasi lintas modul | `core_integration_tests.gd` | Suite | Boot penuh, ubah-simpan-muat ulang, migrasi boot, kill simulasi, pause-resume. | AC-001 s.d. AC-006 | - | `core_integration_tests.gd` |

## 4. Kontrak Antarmodul

Ketentuan yang mengikat seluruh modul:

1. Satu berkas entri utama per layanan (CFR-NFR-008); berkas pendukung hanya untuk tanggung jawab yang berbeda nyata dan tercatat pada matriks ini.
2. Antarmuka yang tercantum pada CORE-FRAMEWORK-ARCHITECTURE bagian 4 adalah satu-satunya jalur akses antar modul; rincian tanda tangan ditetapkan pada tahap Specification.
3. Pustaka murni (GameState, ObjectPool, CoreResourceLoader) tidak menyimpan referensi layanan global; logger dan dependensi lain disuntikkan pada konstruksi.
4. Setiap penambahan modul baru pada tahap berikutnya wajib menambah baris pada matriks ini terlebih dahulu sebelum kode ditulis.

## 5. Penanganan Kesalahan

Setiap baris matriks mencantumkan kelas kegagalan sesuai requirement bagian 13. Ketentuan lintas modul: kegagalan layanan kritis (Log, Config dasar, Save) menghentikan boot dengan pesan jelas; kegagalan layanan sekunder (Audio, Input) melanjutkan boot dalam mode terdegradasi (CFR-FR-002); seluruh kegagalan menghasilkan status yang dapat ditanyai dan log (CFR-FR-031).

## 6. Pertimbangan Performa

Matriks membatasi permukaan tiap modul agar jalur per-frame terkendali: hanya EventBus, ObjectPool, dan InputService beroperasi pada jalur per-frame framework; modul lain bekerja pada momen insidental (boot, transisi, simpan). Kepemilikan anggaran per jalur dirinci pada dokumen rancangan masing-masing.

## 7. Alternatif yang Dipertimbangkan

| Alternatif | Kelebihan | Kekurangan | Alasan Tidak Dipilih |
| --- | --- | --- | --- |
| Satu berkas rancangan besar tanpa matriks. | Ringkas. | Traceability requirement ke modul dan pengujian menyebar pada banyak dokumen. | Pemilik proyek meminta matriks tanggung jawab tersendiri. |
| Matriks digabung ke dokumen arsitektur induk. | Satu tempat baca. | Dokumen induk membesar; perubahan matriks menimbulkan revisi arsitektur. | Pisah agregat stabil (matriks) dari rancangan (arsitektur). |

## 8. Risiko Teknis dan Mitigasi

| Risiko | Kemungkinan | Dampak | Mitigasi |
| --- | --- | --- | --- |
| Matriks usang saat modul bertambah pada tahap berikutnya. | Sedang | Sedang | Ketentuan nomor 4 bagian ini; pemeriksaan matriks menjadi butir audit tiap tahap. |
| Kepemilikan pengujian kabur antar suite. | Rendah | Sedang | Kolom suite pengujian wajib; suite tanpa requirement tercatat tidak diterima audit. |

## 9. Strategi Pengujian

Setiap requirement berprioritas Must wajib memiliki baris suite pengujian pada matriks sebelum implementasi (requirement bagian 15 nomor 4); suite yang dibentuk mengikuti penamaan `<lingkup>_tests.gd` (REPOSITORY-STRUCTURE-SPEC bagian 6 nomor 4) dan berjalan pada workflow Validation (CFR-INT-004). Rancangan suite dirinci pada CORE-FRAMEWORK-TEST-ARCHITECTURE.

## 10. Kriteria Penerimaan Desain

1. Sepuluh modul requirement bagian 7 terpetakan seluruhnya, ditambah CoreResourceLoader sebagai pustaka pendukung area Resource Management.
2. Setiap requirement FR-001 s.d. FR-034 memiliki modul penanggung jawab dan suite pengujian.
3. Tidak ada modul dengan dua tanggung jawab utama.
4. Pemilik proyek menyetujui matriks sebelum tahap Specification.

## 11. Referensi

- CORE-FRAMEWORK-REQUIREMENTS bagian 7, 13, 15, 16
- CORE-FRAMEWORK-ARCHITECTURE (tata letak berkas dan antarmuka)
- SERVICE-DEPENDENCY-DESIGN (arah ketergantungan)
- CORE-FRAMEWORK-TEST-ARCHITECTURE (struktur suite)
- REPOSITORY-STRUCTURE-SPEC bagian 6 (penamaan)

## 12. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
