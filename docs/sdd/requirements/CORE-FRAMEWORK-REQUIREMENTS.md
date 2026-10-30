# CORE-FRAMEWORK-REQUIREMENTS: Kebutuhan Sistem Core Framework

- Status: Approved (disetujui pemilik proyek pada 2026-10-30)
- Tahap roadmap: SDD-02 (Core Framework)
- Penulis: Arsitek proyek
- Terakhir diperbarui: 2026-10-30
- Basis audit: HEAD `6d57ec1` (commit penerimaan SDD-01; branch tunggal `main`)

## 1. Tujuan

Dokumen ini mendefinisikan kebutuhan Core Framework ASTRANUSA: kumpulan layanan generik yang menjadi fondasi teknis bagi seluruh tahap berikutnya (lobby, pertandingan, data, AI). Core Framework menyediakan siklus hidup aplikasi, pengelolaan scene, status aplikasi, komunikasi antarmodul, konfigurasi, penyimpanan, audio, input, pencatatan kesalahan, dan kebijakan resource, tanpa memuat pengetahuan apa pun tentang gameplay. Dokumen ini adalah tahap Requirement Analysis; tidak ada kode yang ditulis pada tahap ini.

## 2. Ruang Lingkup

Dalam lingkup:

1. Analisis kebutuhan untuk sepuluh area: Application Lifecycle, Scene Management, Game State Management, Event Bus, Configuration Management, Save System Integration, Audio Manager, Input Manager, Error Handling dan Logging, serta Resource Management.
2. Kebutuhan integrasi dengan spesifikasi yang telah disetujui: DATA-PERSISTENCE-SPEC, DATA-MIGRATION-SPEC, UPDATE-SYSTEM-SPEC, GODOT-CONFIGURATION-SPEC, REPOSITORY-STRUCTURE-SPEC, CI-PIPELINE-SPEC.
3. Urutan inisialisasi, siklus hidup Android, batas performa, keamanan data, dan pengujian (testability).
4. Identifikasi keputusan teknis terbuka dengan rekomendasi, tanpa mengunci keputusan arsitektur besar.

Di luar lingkup:

1. Perancangan teknis dan antarmuka terperinci (tahap Technical Design dan Specification SDD-02).
2. Implementasi kode (tertunda hingga spesifikasi SDD-02 disetujui).
3. Skema data konfigurasi konten (hero, item, emblem, battle spell, rank; SDD-03).
4. Struktur scene lobby dan UI (SDD-04), logika pertandingan (SDD-05 ke atas), AI (SDD-08).

## 3. Konteks Sistem

Core Framework menempati lapisan `game/src/core/` pada arsitektur berlapis yang telah ditetapkan. Lapisan core bersifat generik dan tidak mengetahui gameplay; lapisan di atasnya (`app/`, `data/`, `simulation/`, `presentation/`) memakai layanan core melalui antarmuka yang stabil.

| Lapisan | Menggunakan Core Untuk |
| --- | --- |
| `app/` | Routing scene, status aplikasi, siklus hidup, konfigurasi. |
| `data/` (SDD-03) | Validasi dan pemuatan konfigurasi melalui ConfigService. |
| `simulation/` (SDD-05 ke atas) | Event bus, object pool, RNG-safety, logging; tanpa akses node visual. |
| `presentation/` (SDD-04 ke atas) | Status aplikasi, pengaturan, audio, input. |

Konteks platform yang mengikat:

1. Aplikasi berjalan sepenuhnya offline pada Android (minSdk 24, kelas QA Android 8.0 ke atas, ABI arm64-v8a dan armeabi-v7a; P-009).
2. Orientasi landscape tetap dengan basis desain 1280x720 (P-010).
3. Data pemain berada pada `user://saves/` dan hanya boleh disentuh SaveService (DATA-PERSISTENCE-SPEC bagian 9).
4. Seluruh layanan harus dapat dijalankan headless pada CI tanpa perangkat Android (prinsip arsitektur nomor 3).
5. Scene boot SDD-01 (`ASTRANUSA 0.1.0 (build 1)`) tetap menjadi titik uji smoke sampai scene lobby tersedia pada SDD-04.

## 4. Batasan Desain

Batasan berikut telah dikunci pada dokumentasi disetujui dan tidak dirancang ulang pada tahap ini:

| No | Batasan | Sumber |
| --- | --- | --- |
| 1 | Godot 4.7.2-stable dan GDScript; tanpa fitur eksperimental. | P-007, D-002 |
| 2 | Arsitektur berlapis: core tidak bergantung pada lapisan di atasnya dan tidak mengenal gameplay. | TECHNICAL_ARCHITECTURE bagian 3 |
| 3 | Autoload dibatasi minimum; setiap penambahan wajib beralasan; daftar final ditetapkan pada spesifikasi SDD-02. | TECHNICAL_ARCHITECTURE bagian 6 |
| 4 | Hanya SaveService yang boleh mengakses `user://saves/`; penulisan atomik dengan amplop versi dan checksum. | DATA-PERSISTENCE-SPEC bagian 7-9 |
| 5 | Migrasi dijalankan pada boot sebelum scene manapun membaca data; jurnal, cadangan, dan pemulihan wajib. | DATA-MIGRATION-SPEC bagian 5-8 |
| 6 | Urutan boot setelah pembaruan mengikuti UPDATE-SYSTEM-SPEC bagian 6. | UPDATE-SYSTEM-SPEC bagian 6 |
| 7 | Konfigurasi statis dibaca dari `res://config/` dengan penimpa `user://assets_override/`. | DATA-PERSISTENCE-SPEC bagian 9; UPDATE-SYSTEM-SPEC bagian 5.2 |
| 8 | Struktur direktori mengikuti jadwal REPOSITORY-STRUCTURE-SPEC; tanpa direktori kosong. | REPOSITORY-STRUCTURE-SPEC bagian 4-5 |
| 9 | Lint gdlint 4.5.0 dan test harness berjalan pada workflow Validation; versi toolchain terkunci. | P-011, P-012, CI-PIPELINE-SPEC |
| 10 | Kebijakan alokasi objek dan object pool ditetapkan pada SDD-02. | GODOT-CONFIGURATION-SPEC bagian 5 |
| 11 | Aplikasi offline: tanpa izin jaringan, tanpa layanan cloud, tanpa unduhan otomatis. | UPDATE-SYSTEM-SPEC bagian 1 |
| 12 | Tidak ada perubahan konfigurasi Godot, workflow CI, atau toolchain SDD-01 pada tahap requirement ini. | Aturan proyek |

## 5. Kebutuhan Fungsional

Setiap requirement diberi ID unik `CFR-FR-xxx`, dikelompokkan per modul, dan menautkan modul penanggung jawab (bagian 7). Prioritas: Must (wajib SDD-02), Should (wajib bila kapasitas memungkinkan), Could (opsional).

### 5.1 Application Lifecycle (AppBootstrap)

| ID | Nama | Deskripsi | Prioritas | Rationale | Acceptance Criteria | Metode Verifikasi |
| --- | --- | --- | --- | --- | --- | --- |
| CFR-FR-001 | Urutan boot terkendali | Inisialisasi layanan berjalan sesuai urutan tetap pada bagian 9; langkah tidak dapat melompati prasyaratnya. | Must | Urutan yang tidak terkendali menghasilkan bug inisialisasi yang sulit direproduksi. | Setiap layanan terinisialisasi hanya setelah prasyaratnya; pelanggaran urutan menghasilkan kegagalan eksplisit, bukan perilaku tidak terdefinisi. | Unit test urutan boot headless. |
| CFR-FR-002 | Kegagalan terpisah per layanan | Kegagalan layanan kritis (Log, Config, Save) menghentikan boot dengan pesan jelas; kegagalan layanan non-kritis (Audio, Input) melanjutkan boot dalam mode terdegradasi dengan peringatan. | Must | Game offline tidak boleh gagal total hanya karena satu layanan sekunder tidak tersedia. | Boot dengan layanan sekunder dinonaktifkan tetap mencapai status siap dan mencatat mode terdegradasi. | Integration test dengan layanan sekunder di-stub gagal. |
| CFR-FR-003 | Penutupan normal | Penutupan aplikasi menjalankan: flush antrean tulis SaveService, penghentian audio, dan pencatatan log, dalam urutan tersebut. | Must | Penutupan yang tidak menyiram antrean dapat kehilangan data yang belum ditulis. | Seluruh antrean tulis kosong dan audio berhenti sebelum proses keluar pada penutupan normal. | Integration test penutupan headless. |
| CFR-FR-004 | Idempotensi boot | Boot normal tanpa perubahan versi schema tidak melakukan penulisan apa pun pada store. | Must | Menjatuhkan batasan ini menimbulkan penulisan berlebih dan risiko keausan penyimpanan. | Boot ganda berturut-turut tidak mengubah stempel waktu berkas store. | Integration test boot ganda; memeriksa mtime berkas store. |

### 5.2 Scene Management (SceneRouter)

| ID | Nama | Deskripsi | Prioritas | Rationale | Acceptance Criteria | Metode Verifikasi |
| --- | --- | --- | --- | --- | --- | --- |
| CFR-FR-005 | API routing scene bernama | Transisi antar scene utama dinyatakan sebagai route bernama dengan hook pra dan pasca transisi; route tak dikenal ditolak dengan error eksplisit. | Must | Menyatukan navigasi mencegah pemanggilan `change_scene` tersebar dan sulit diaudit. | Seluruh perpindahan scene pada kode hanya melalui router; route tak terdaftar gagal dengan pesan jelas. | Unit test router; audit kode (gdlint dan peninjauan). |
| CFR-FR-006 | Pemuatan asinkron | Scene tujuan dimuat asinkron dengan laporan kemajuan; frame utama tidak membeku selama pemuatan. | Must | Pembebanan sinkron di Android kelas menengah menghasilkan layar beku yang dirasakan pemain. | Pemuatan scene uji berlangsung asinkron; indikator kemajuan terbarui; tanpa pembekuan frame (tidak ada frame melebihi anggaran bagian 12). | Integration test pemuatan headless dengan scene uji. |
| CFR-FR-007 | Pelepasan memori transisi | Resource scene lama dilepas setelah scene baru aktif; router menyediakan titik pembersihan eksplisit. | Should | Mencegah akumulasi memori antar pertandingan pada perangkat terbatas. | Jumlah referensi resource scene lama kembali ke tingkat sebelum transisi pada pengujian memori. | Integration test dengan penghitungan referensi. |
| CFR-FR-008 | Routing headless | Router dapat merekam urutan transisi tanpa rendering untuk pengujian CI. | Should | Verifikasi alur scene pada CI tanpa perangkat grafis. | Rekaman transisi tersedia dan cocok dengan urutan yang diminta pada mode headless. | Unit test mode headless. |

### 5.3 Game State Management (GameState)

| ID | Nama | Deskripsi | Prioritas | Rationale | Acceptance Criteria | Metode Verifikasi |
| --- | --- | --- | --- | --- | --- | --- |
| CFR-FR-009 | Pustaka state machine generik | State machine (status, transisi, guard) disediakan sebagai pustaka yang dapat dipakai ulang oleh status aplikasi maupun sesi simulasi; transisi tidak sah ditolak dan dicatat. | Must | Status aplikasi dan status pertandingan membutuhkan pola sama; pustaka generik mencegah duplikasi. | Transisi terdaftar berhasil; transisi tidak terdaftar ditolak tanpa efek samping dan tercatat pada log. | Unit test transisi sah dan tidak sah. |
| CFR-FR-010 | Status aplikasi eksplisit | Framework mengelola status aplikasi tingkat atas (mis. BOOT, LOBBY, MATCH, RESULT) yang menjadi rujukan tunggal bagi lapisan di atasnya. | Must | Status tersebar menyulitkan penanganan pause dan transisi scene. | Status aplikasi dapat ditanyakan kapan pun dan konsisten dengan route aktif. | Integration test keterkaitan status dan route. |

### 5.4 Event Bus

| ID | Nama | Deskripsi | Prioritas | Rationale | Acceptance Criteria | Metode Verifikasi |
| --- | --- | --- | --- | --- | --- | --- |
| CFR-FR-011 | Event tervalidasi | Event didefinisikan sebagai konstanta terdaftar; emit atau berlangganan pada event tak dikenal ditolak dengan error. | Must | String liar membuat kegagalan senyap yang sulit dilacak. | Event tak terdaftar menghasilkan error eksplisit; seluruh event terdaftar pada satu register yang dapat diaudit. | Unit test registrasi dan penolakan. |
| CFR-FR-012 | Dua mode pengiriman | Event dapat dikirim seketika (immediate) atau melalui antrean yang disiram per frame (deferred); mode dinyatakan per event. | Must | Mode seketika memudahkan urutan logika; mode antrean mencegah rekursi dan reentrancy lintas modul. | Kedua mode berperilaku sesuai spesifikasi; event deferred terkirim pada siraman berikutnya, tidak seketika. | Unit test urutan pengiriman. |
| CFR-FR-013 | Kebersihan listener | Listener dapat dilepas; sisa listener aktif pada penutupan modul dicatat sebagai peringatan; tersedia API pelepasan menyeluruh untuk pengujian. | Must | Listener yang tertinggal adalah sumber kebocoran memori dan callback mati. | Setelah pelepasan, listener tidak menerima event; sisa listener pada shutdown menghasilkan peringatan log. | Unit test daur hidup listener. |
| CFR-FR-014 | Diagnostik event | Pada mode pengembangan, emit tanpa listener dicatat sebagai informasi, bukan error. | Should | Membantu menemukan salah ketik nama event dan event yang tidak lagi dipakai. | Emit tanpa listener menghasilkan catatan debug yang dapat difilter. | Unit test diagnostik. |

### 5.5 Configuration Management (ConfigService)

| ID | Nama | Deskripsi | Prioritas | Rationale | Acceptance Criteria | Metode Verifikasi |
| --- | --- | --- | --- | --- | --- | --- |
| CFR-FR-015 | Pemuatan bertingkat | Konfigurasi statis dibaca dari `res://config/` sebagai sumber dasar dan `user://assets_override/` sebagai penimpa; penimpa rusak diabaikan dengan peringatan. | Must | Mengikat UPDATE-SYSTEM-SPEC bagian 5.2 dan menjaga ketahanan terhadap berkas penimpa rusak. | Penimpa yang sah diterapkan; penimpa rusak diabaikan, sumber dasar dipakai, peringatan tercatat. | Unit test dengan fixture penimpa sah dan rusak. |
| CFR-FR-016 | Validasi pada pemuatan | Kerangka validasi dasar (keberadaan berkas, tipe kunci) tersedia pada SDD-02; data tidak valid ditolak dengan pesan jelas. Skema konten penuh menyusul SDD-03. | Must | Mencegah kondisi tidak terdefinisi dari data rusak (TECHNICAL_ARCHITECTURE bagian 5). | Data tidak valid menghasilkan kegagalan pemuatan eksplisit, bukan nilai bawaan senyap. | Unit test data sah dan tidak sah. |
| CFR-FR-017 | Pengaturan pemain | Kunci pengaturan pemain dibaca dan ditulis melalui satu antarmuka; nilai disinkronkan ke store `settings` melalui SaveService; perubahan memicu momen simpan. | Must | Pengaturan adalah data pemain (DATA-PERSISTENCE-SPEC bagian 6 nomor 11) dan wajib bertahan pembaruan. | Perubahan pengaturan tersedia setelah aplikasi dimulai ulang; tulis melalui antrean SaveService. | Integration test ubah-simpan-muat ulang. |
| CFR-FR-018 | Nilai default aman | Setiap kunci pengaturan memiliki nilai default; kunci tak dikenal pada berkas dipakai nilai default dengan peringatan, tanpa menggagalkan boot. | Must | Berkas lama tidak boleh membuat aplikasi tidak dapat dibuka. | Boot dengan berkas pengaturan rusak atau kunci tak dikenal tetap mencapai status siap. | Unit test dengan fixture berkas rusak. |

### 5.6 Save System Integration (SaveService)

| ID | Nama | Deskripsi | Prioritas | Rationale | Acceptance Criteria | Metode Verifikasi |
| --- | --- | --- | --- | --- | --- | --- |
| CFR-FR-019 | Implementasi persistensi penuh | SaveService mengimplementasikan DATA-PERSISTENCE-SPEC: amplop `schema_version`, checksum SHA-256, penulisan atomik, antrean tulis, dan kepemilikan akses tunggal atas `user://saves/`. | Must | Spesifikasi telah disetujui dan mengikat SDD-02. | Seluruh acceptance criteria DATA-PERSISTENCE-SPEC bagian 13 terpenuhi oleh SaveService. | Unit dan integration test; pemeriksaan checklist spesifikasi. |
| CFR-FR-020 | Kerangka migrasi | SaveService menyediakan kerangka DATA-MIGRATION-SPEC: registri langkah, jurnal, cadangan, pemulihan, dan mode `--migrate-only` headless. | Must | Migrasi otomatis adalah syarat pembaruan tanpa kehilangan data. | Seluruh acceptance criteria DATA-MIGRATION-SPEC bagian 11 terpenuhi oleh kerangka. | Integration test migrasi fixture; eksekusi `--migrate-only` pada CI. |
| CFR-FR-021 | Momen simpan minimum | Penulisan dipicu paling tidak pada: akhir pertandingan, perubahan pengaturan, perubahan rank, dan penutupan normal. | Must | Mengikat DATA-PERSISTENCE-SPEC bagian 8 nomor 5. | Setiap momen pemicu menghasilkan operasi tulis pada antrean. | Integration test tiap momen pemicu. |
| CFR-FR-022 | Pemeriksaan ruang simpan | Sebelum menulis atau migrasi, layanan memeriksa ruang bebas minimal dua kali ukuran store terbesar; bila tidak mencukupi, penulisan ditunda dengan pesan yang jelas. | Must | Mengikat DATA-PERSISTENCE-SPEC bagian 12 dan DATA-MIGRATION-SPEC bagian 9. | Ruang tidak mencukupi menghasilkan penundaan tanpa penulisan parsial. | Unit test dengan ruang disimulasikan. |
| CFR-FR-023 | Pemulihan store | Store dengan checksum tidak cocok dipulihkan dari cadangan; bila cadangan tidak tersedia, store dibuat ulang dengan nilai default tanpa menghapus berkas lama (mode aman). | Must | Kegagalan satu store tidak boleh menghapus data atau menghentikan seluruh aplikasi. | Store rusak pulih atau berjalan mode aman; berkas lama tetap ada; store lain tidak terdampak. | Integration test store rusak. |

### 5.7 Audio Manager (AudioService)

| ID | Nama | Deskripsi | Prioritas | Rationale | Acceptance Criteria | Metode Verifikasi |
| --- | --- | --- | --- | --- | --- | --- |
| CFR-FR-024 | Kategori volume | Volume dikelola per kategori (master, musik, efek, announcer) dan disimpan persisten pada store `settings`. | Must | Pengaturan audio adalah kebutuhan pemain yang wajib bertahan pembaruan. | Perubahan volume kategori bertahan setelah mulai ulang dan berlaku pada seluruh pemutaran. | Integration test simpan-muat. |
| CFR-FR-025 | API pemutaran terkendali | API play, stop, dan pause per sumber; jumlah node pemutar aktif dibatasi (polyphony) per kategori; node dikembalikan ke pool. | Must | Node audio yang tidak dibatasi menyebabkan kebocoran dan jeda audio pada Android. | Jumlah node aktif tidak melebihi batas; penghentian mengembalikan node ke pool. | Unit test batas polyphony. |
| CFR-FR-026 | Headless aman | Layanan audio berjalan tanpa perangkat keluaran audio (CI headless) tanpa error. | Must | Pengujian CI tidak memiliki perangkat audio. | Eksekusi headless memutar audio tanpa kegagalan (jalur no-op atau bus virtual). | Integration test headless pada CI. |

### 5.8 Input Manager (InputService)

| ID | Nama | Deskripsi | Prioritas | Rationale | Acceptance Criteria | Metode Verifikasi |
| --- | --- | --- | --- | --- | --- | --- |
| CFR-FR-027 | Façade input terpusat | Pembacaan input pemain di lapisan `app/` dan `core/` dilakukan melalui façade berbasis action map Godot, bukan pembacaan mentah yang tersebar. | Should | Menyatukan akses input memudahkan pengujian dan penggantian perilaku kontrol; cakupan penuh menyusul kebutuhan pertandingan (lihat OJ-3). | Tidak ada pembacaan input mentah di luar façade pada kode core dan app. | Audit kode; unit test façade. |
| CFR-FR-028 | Input sintetis untuk pengujian | Façade dapat menerima input sintetis sehingga alur berbasis input dapat diuji headless. | Should | CI tidak memiliki layar sentuh. | Alur uji yang dipicu input dapat dijalankan pada CI melalui input sintetis. | Integration test input sintetis. |

### 5.9 Error Handling dan Logging (LogService)

| ID | Nama | Deskripsi | Prioritas | Rationale | Acceptance Criteria | Metode Verifikasi |
| --- | --- | --- | --- | --- | --- | --- |
| CFR-FR-029 | Tingkat log | Log memiliki tingkat DEBUG, INFO, WARN, ERROR; tingkat aktif dapat disetel; bawaan rilis adalah WARN. | Must | Log berlebihan menurunkan kinerja dan memenuhi penyimpanan. | Log di bawah tingkat aktif tidak ditulis; tingkat dapat diubah pada mode pengembangan. | Unit test penyaringan tingkat. |
| CFR-FR-030 | Log bergulir | Log ditulis ke `user://logs/` dengan ukuran dan jumlah berkas terbatas; tidak pernah menulis ke `res://` maupun `user://saves/`. | Must | Mencegah pertumbuhan tanpa batas pada penyimpanan pemain. | Log melebihi batas dipangkas; tidak ada berkas log di luar `user://logs/`. | Unit test pemangkasan. |
| CFR-FR-031 | Kegagalan eksplisit | Tidak ada pengecualian yang ditelan diam-diam; kegagalan layanan dilaporkan eksplisit (status kesalahan dan log), kegagalan fatal boot menampilkan pesan yang dapat dipahami pemain. | Must | Kegagalan senyap membuat diagnosis mustahil dan melanggar prinsip arsitektur. | Audit kode menemukan nol penelanan senyap; kegagalan boot menghasilkan pesan jelas. | Audit kode; integration test kegagalan boot. |

### 5.10 Resource Management (kebijakan dan ObjectPool)

| ID | Nama | Deskripsi | Prioritas | Rationale | Acceptance Criteria | Metode Verifikasi |
| --- | --- | --- | --- | --- | --- | --- |
| CFR-FR-032 | Object pool generik | Pool acquire-release dengan pramasukan dan reset objek; jalur acquire tidak mengalokasikan objek baru selama stok tersedia. | Must | Pool adalah prasyarat anggaran alokasi per-frame (TECHNICAL_ARCHITECTURE bagian 10) dan dipakai tahap berikutnya. | Acquire berturut-turut dalam stok tidak memicu alokasi baru; objek direset saat dilepas. | Unit test pool. |
| CFR-FR-033 | Kebijakan alokasi per-frame | Kebijakan alokasi objek pada loop utama ditetapkan pada SDD-02 dan ditegakkan pada framework: tanpa alokasi besar pada jalur per-frame. | Must | Menjatuhkan mandat GODOT-CONFIGURATION-SPEC bagian 5 nomor 3. | Kebijakan terdokumentasi pada spesifikasi SDD-02; jalur per-frame framework terverifikasi bebas alokasi besar. | Spesifikasi; pengujian alokasi pada verifikasi. |
| CFR-FR-034 | Pemuatan resource terjadwal | API pemuatan resource asinkron dengan batas waktu dan hasil gagal yang eksplisit (tidak menggantung tanpa batas). | Should | Pemuatan tanpa batas waktu menggantung aplikasi tanpa umpan balik. | Pemuatan berkas tidak tersedia selesai dengan status gagal dalam batas waktu. | Unit test batas waktu. |

## 6. Kebutuhan Non-Fungsional

| ID | Nama | Deskripsi | Prioritas | Rationale | Acceptance Criteria | Metode Verifikasi |
| --- | --- | --- | --- | --- | --- | --- |
| CFR-NFR-001 | Headless paripurna | Seluruh layanan core berjalan pada CI headless tanpa perangkat Android. | Must | Prinsip testable; CI tanpa perangkat fisik. | Seluruh pengujian SDD-02 berjalan pada runner CI tanpa akses perangkat. | Eksekusi workflow Validation. |
| CFR-NFR-002 | Tanpa dependensi baru | Tidak ada addon atau pustaka pihak ketiga baru tanpa persetujuan eksplisit pemilik proyek. | Must | Menjaga repository ringan dan sesuai P-008. | Tidak ada berkas vendor baru; kebutuhan framework dievaluasi pada OJ-5. | Audit repository. |
| CFR-NFR-003 | API stabil Godot 4.7 | Hanya API stabil 4.7.2 yang digunakan; fitur eksperimental dilarang. | Must | Kestabilan export Android dan CI. | Audit kode menemukan nol pemakaian API eksperimental. | Audit kode; gdlint. |
| CFR-NFR-004 | Lint bersih | Seluruh berkas GDScript baru lolos gdlint 4.5.0 tanpa pengecualian baru. | Must | Kualitas kode terjaga otomatis pada CI (P-011). | Job lint CI lolos. | Workflow Validation. |
| CFR-NFR-005 | Overhead memori terukur | Jejak memori tetap layanan core dilaporkan pada verifikasi; tidak ada alokasi per-frame pada jalur menganggur. | Should | Anggaran memori perangkat kelas menengah. | Laporan memori tersedia pada laporan verifikasi SDD-02; jalur menganggur bebas alokasi. | Pengukuran memori headless. |
| CFR-NFR-006 | Tulis tanpa blok | Operasi tulis store tidak memblokir frame utama; tulis diantrekan dan disiram pada momen aman. | Should | Jeda frame saat menyimpan dirasakan pemain. | Penulisan store besar tidak menaikkan waktu frame di atas anggaran bagian 12 pada pengujian. | Integration test pengukuran waktu frame. |
| CFR-NFR-007 | Waktu tulis terukur | Penulisan store berukuran hingga 1 MB selesai dalam 50 ms atau kurang pada perangkat kelas QA (target, bukan gerbang keras). | Should | Menjaga momen simpan tidak terasa. | Pengukuran verifikasi mencatat waktu tulis; target dicapai atau deviasinya dijelaskan. | Pengukuran pada verifikasi. |
| CFR-NFR-008 | Tanggung jawab tunggal | Setiap layanan memiliki satu tanggung jawab utama dan satu berkas entri utama; ketergantungan antar modul mengikuti bagian 8. | Must | Modularitas adalah prinsip arsitektur nomor 1. | Audit kode menemukan pemisahan tanggung jawab sesuai bagian 7. | Audit kode. |

## 7. Tanggung Jawab Modul

Modul dipadatkan berdasarkan kebutuhan arsitektur dan biaya kompleksitas; tidak setiap area analisis menjadi modul terpisah (misalnya kebijakan resource adalah bagian spesifikasi, bukan layanan runtime; input menjadi façade ringan, bukan sistem penuh, hingga tahap pertandingan menuntut lebih).

| Modul (nama kerja) | Area | Tanggung Jawab Utama | Requirement Terkait |
| --- | --- | --- | --- |
| AppBootstrap | A | Mengatur urutan inisialisasi, degradasi layanan, dan penutupan normal. | FR-001 s.d. FR-004 |
| SceneRouter | B | Routing scene bernama, pemuatan asinkron, pelepasan memori transisi. | FR-005 s.d. FR-008 |
| GameState | C | Pustaka state machine generik dan status aplikasi tingkat atas. | FR-009, FR-010 |
| EventBus | D | Komunikasi antarmodul publish-subscribe tervalidasi. | FR-011 s.d. FR-014 |
| ConfigService | E | Pemuatan konfigurasi bertingkat, validasi dasar, pengaturan pemain. | FR-015 s.d. FR-018 |
| SaveService | F | Persistensi store, kerangka migrasi, pemulihan, antrean tulis. | FR-019 s.d. FR-023 |
| AudioService | G | Kategori volume, API pemutaran, batas polyphony, mode headless. | FR-024 s.d. FR-026 |
| InputService | H | Façade input berbasis action map dan dukungan input sintetis. | FR-027, FR-028 |
| LogService | I | Log bertingkat, log bergulir, pelaporan kegagalan terpusat. | FR-029 s.d. FR-031 |
| ObjectPool | J | Pool objek generik; kebijakan alokasi ditegakkan melalui spesifikasi dan audit. | FR-032 s.d. FR-034 |

Catatan konsolidasi: Resource Management tidak dijadikan layanan runtime tersendiri; kebijakannya dibakukan pada spesifikasi SDD-02 dan hanya ObjectPool yang menjadi kode layanan. Daftar autoload final ditetapkan pada tahap Technical Design sesuai mandat TECHNICAL_ARCHITECTURE bagian 6.

## 8. Ketergantungan Modul

Arah ketergantungan hanya boleh menuruni lapisan; core tidak bergantung pada app, data, simulation, maupun presentation.

| Modul | Boleh Bergantung Pada | Tidak Boleh Bergantung Pada |
| --- | --- | --- |
| LogService | API file Godot | Modul core lain |
| EventBus | LogService | ConfigService, SaveService, scene |
| ConfigService | LogService, SaveService (untuk store settings) | EventBus (hanya boleh memancarkan), scene |
| SaveService | LogService | ConfigService, EventBus (hanya boleh memancarkan), scene |
| GameState | LogService | Semua layanan lain (pustaka murni) |
| SceneRouter | LogService, EventBus, GameState | SaveService, ConfigService |
| AudioService | LogService, EventBus, SaveService (melalui ConfigService) | Scene |
| InputService | LogService | Semua layanan lain |
| AppBootstrap | Seluruh layanan di atas (hanya komposisi dan urutan) | Lapisan di luar core |
| ObjectPool | LogService | Semua layanan lain (pustaka murni) |

Ketentuan tambahan:

1. Komunikasi antar layanan core mengutamakan antarmuka eksplisit; event bus dipakai untuk penyebaran status, bukan pemanggilan prosedural yang wajib.
2. Pustaka murni (GameState, ObjectPool) harus dapat dipakai tanpa inisialisasi layanan lain, agar dapat diuji terisolasi.
3. Ketergantungan melingkar dilarang; pelanggaran ditolak pada audit desain.

## 9. Kebutuhan Inisialisasi

Urutan inisialisasi berikut memenuhi CFR-FR-001 dan mengikat UPDATE-SYSTEM-SPEC bagian 6:

1. AppBootstrap aktif paling awal.
2. LogService siap (paling awal agar kegagalan berikutnya tercatat).
3. ConfigService memuat nilai default bawaan.
4. EventBus siap.
5. SaveService: membersihkan `user://tmp/`, memeriksa jurnal migrasi dan memulihkan cadangan bila perlu, menjalankan migrasi bila perlu, memuat store, memeriksa manifest aset penimpa (titik sedia; tanpa paket aktif pada rilis awal sesuai O-020).
6. ConfigService menerapkan pengaturan pemain dari store `settings`.
7. AudioService menerapkan volume tersimpan.
8. InputService siap.
9. SceneRouter memuat scene awal (scene boot SDD-01 hingga lobby tersedia).
10. Status aplikasi diubah menjadi siap.

Ketentuan:

- Setiap langkah memiliki prasyarat eksplisit (bagian 8); pelanggaran urutan adalah kegagalan eksplisit (CFR-FR-001).
- Waktu total boot sampai status siap diukur dan dilaporkan pada verifikasi; target pada bagian 12.
- Inisialisasi layanan kritis tidak boleh memerlukan perangkat audio, sentuh, maupun jaringan.

## 10. Kebutuhan Siklus Hidup Android

| ID | Nama | Deskripsi | Prioritas | Rationale | Acceptance Criteria | Metode Verifikasi |
| --- | --- | --- | --- | --- | --- | --- |
| CFR-INT-101 | Pause oleh sistem | Saat aplikasi masuk latar belakang: audio dihentikan sementara, input diabaikan, dan antrean tulis disiram (flush) sebelum jeda. | Must | Android dapat mematikan proses latar belakang kapan pun; data yang belum ditulis dapat hilang. | Pada notifikasi jeda: audio berhenti, antrean tulis kosong, tidak ada penulisan setelah jeda. | Integration test simulasi notifikasi jeda. |
| CFR-INT-102 | Resume | Saat kembali ke latar depan: audio dipulihkan, input aktif kembali, status aplikasi tetap konsisten dengan route aktif. | Must | Pemulihan yang tidak konsisten menimbulkan tumpang-tindih status. | Status dan route setelah resume sama dengan sebelum pause pada pengujian. | Integration test pause-resume. |
| CFR-INT-103 | Penghentian oleh sistem | Aplikasi yang dihentikan paksa di titik mana pun tidak boleh menghasilkan store setengah tertulis; pemulihan otomatis berjalan pada boot berikutnya. | Must | Mengikat DATA-MIGRATION-SPEC bagian 7. | Uji henti paksa pada titik tulis dan migrasi menghasilkan pemulihan tanpa kehilangan data pada boot berikutnya. | Integration test henti paksa (kill test). |
| CFR-INT-104 | Penutupan atas permintaan | Permintaan penutupan jendela menjalankan prosedur penutupan normal (CFR-FR-003). | Must | Menjaga momen simpan penutupan. | Penutupan atas permintaan menyiram antrean tulis sebelum proses keluar. | Integration test penutupan. |

## 11. Kebutuhan Integrasi Persistensi

| ID | Nama | Deskripsi | Prioritas | Rationale | Acceptance Criteria | Metode Verifikasi |
| --- | --- | --- | --- | --- | --- | --- |
| CFR-INT-001 | Kesesuaian DATA-PERSISTENCE-SPEC | SaveService mengimplementasikan seluruh ketentuan spesifikasi tanpa penyimpangan. | Must | Spesifikasi disetujui dan mengikat SDD-02. | Checklist bagian 13 spesifikasi terpenuhi seluruhnya. | Pemeriksaan checklist pada verifikasi. |
| CFR-INT-002 | Kesesuaian DATA-MIGRATION-SPEC | Kerangka migrasi mengimplementasikan registri, jurnal, cadangan, pemulihan, dan mode `--migrate-only`. | Must | Spesifikasi disetujui dan mengikat SDD-02. | Checklist bagian 11 spesifikasi terpenuhi seluruhnya. | Pemeriksaan checklist; eksekusi CI. |
| CFR-INT-003 | Kesesuaian urutan boot pembaruan | Urutan inisialisasi bagian 9 selaras dengan UPDATE-SYSTEM-SPEC bagian 6. | Must | Konflik urutan boot akan memutus alur pembaruan. | Peninjauan silang bagian 9 terhadap spesifikasi menemukan nol konflik. | Peninjauan silang pada desain. |
| CFR-INT-004 | Integrasi CI | Pengujian SDD-02 berjalan pada workflow Validation; mode `--migrate-only` tersedia untuk CI headless. | Must | Mengikat CI-PIPELINE-SPEC dan DATA-MIGRATION-SPEC bagian 4 nomor 5. | Workflow Validation menjalankan seluruh pengujian core tanpa perangkat Android. | Eksekusi CI pada verifikasi. |
| CFR-INT-005 | Penetapan kebijakan alokasi | Kebijakan alokasi objek dan pool ditetapkan pada spesifikasi SDD-02 sesuai mandat GODOT-CONFIGURATION-SPEC bagian 5. | Must | Mandat eksplisit spesifikasi yang disetujui. | Spesifikasi SDD-02 memuat kebijakan alokasi. | Peninjauan dokumen. |
| CFR-INT-006 | Kesesuaian struktur repository | Kode layanan ditempatkan pada `game/src/core/`, pengujian pada `game/tests/`, tanpa direktori kosong. | Must | Mengikat REPOSITORY-STRUCTURE-SPEC. | Struktur sesuai jadwal spesifikasi; harness fondasi tetap lolos. | Test harness fondasi pada CI. |
| CFR-INT-007 | Kompatibilitas mundur SDD-01 | Scene boot dan test harness fondasi SDD-01 tetap berfungsi; MF-02 (teks versi pada scene boot) tetap lolos. | Must | Tahap baru tidak boleh merusak tahap sebelumnya. | Seluruh TF-01 s.d. TF-08 tetap lolos; scene boot tidak berubah perilaku. | Test harness fondasi; dispatch Android Build. |

## 12. Kebutuhan Performa

| No | Metrik | Target SDD-02 | Sumber |
| --- | --- | --- | --- |
| 1 | Waktu boot sampai status siap (headless, CI) | Diukur dan dilaporkan; tanpa target keras pada SDD-02. | Verifikasi SDD-02. |
| 2 | Waktu boot sampai lobby siap (perangkat QA) | Diukur pada verifikasi SDD-04 ke atas; referensi informal SDD-01 (di bawah 5 detik) tetap berlaku sebagai tolok ukur. | MF-05; TARGET arsitektur. |
| 3 | Pembekuan frame saat transisi scene | Tanpa pembekuan frame panjang; pemuatan asinkron (CFR-FR-006). | Arsitektur bagian 10. |
| 4 | Alokasi per frame pada jalur menganggur | Nol alokasi objek besar (CFR-NFR-005, FR-033). | Arsitektur bagian 10. |
| 5 | Waktu tulis store hingga 1 MB | 50 ms atau kurang pada perangkat kelas QA (CFR-NFR-007; target, bukan gerbang keras). | Persistensi. |
| 6 | Batas polyphony audio per kategori | Ditetapkan pada spesifikasi SDD-02; nilai bawaan konservatif untuk perangkat kelas menengah (CFR-FR-025). | Audio. |

Ketentuan: anggaran kinerja dan memori perangkat menyeluruh (60 FPS, 1 GB RSS) tetap milik arsitektur dan divalidasi mulai SDD-12; SDD-02 hanya menetapkan kerangka pengukuran dan target terbatas di atas.

## 13. Kebutuhan Penanganan Kesalahan

1. Klasifikasi kesalahan: kegagalan fatal boot (layanan kritis), kegagalan terdegradasi (layanan sekunder), dan kegagalan data (store, konfigurasi). Setiap kelas memiliki kebijakan penanganan yang ditetapkan pada spesifikasi SDD-02.
2. Pesan kepada pemain: hanya pesan non-teknis yang jelas; pesan teknis lengkap masuk log. Kegagalan migrasi mengikuti ketentuan UPDATE-SYSTEM-SPEC bagian 7 nomor 3 (data aman, versi lama digunakan).
3. Tidak ada inisialisasi ulang atau penghapusan store sebagai akibat kegagalan (mengikat DATA-MIGRATION-SPEC bagian 8 nomor 5).
4. Seluruh kegagalan layanan menghasilkan status kesalahan yang dapat ditanyai dan log; pengecualian tidak ditelan (CFR-FR-031).
5. Boot dengan data rusak tetap mencapai status siap dengan mode aman yang sesuai (CFR-FR-023, FR-018).

## 14. Keamanan dan Integritas Data

1. Hanya SaveService yang mengakses `user://saves/`; seluruh modul lain melalui antarmuka layanan (DATA-PERSISTENCE-SPEC bagian 9).
2. Checksum SHA-256 memverifikasi integritas setiap store saat dimuat; ketidakcocokan memicu pemulihan (CFR-FR-023).
3. Log tidak mencatat data pribadi pemain maupun isi store secara utuh; log hanya memuat ringkasan diagnostik (CFR-FR-030).
4. Tidak ada kredensial pada kode core; tidak ada layanan jaringan (offline, tanpa izin internet).
5. Seluruh input berkas (store, konfigurasi, penimpa aset) divalidasi sebelum digunakan (CFR-FR-016, FR-023).
6. Manipulasi oleh pemain pada perangkat sendiri tidak dapat dicegah mutlak; batas proteksi mengikuti DATA-PERSISTENCE-SPEC bagian 10 dan O-009.

## 15. Kebutuhan Pengujian (Testability)

1. Setiap layanan core dapat diuji unit secara terisolasi dan headless; pustaka murni (GameState, ObjectPool) tanpa prasyarat layanan.
2. Ketergantungan pada perangkat (audio, sentuh, berkas) disediakan titik suntikan (stub) pada desain agar dapat diuji di CI.
3. Pengujian baru mengikuti konvensi penamaan harness (`<lingkup>_tests.gd`, REPOSITORY-STRUCTURE-SPEC bagian 6) dan berjalan pada workflow Validation.
4. Seluruh requirement berprioritas Must memiliki pengujian otomatis yang merekam keberhasilannya sebelum tahap dinyatakan selesai.
5. Pengujian integrasi minimum: urutan boot penuh, ubah-simpan-muat ulang pengaturan, migrasi fixture versi lama, kill test tulis dan migrasi, pause-resume.
6. Keputusan framework pengujian pada SDD-02: harness kustom dipertahankan (disetujui pemilik proyek pada 2026-10-30, menegaskan kembali P-008); evaluasi ulang berikutnya bila biaya struktur pengujian melebihi manfaat.

## 16. Acceptance Criteria

| ID | Kriteria | Terkait |
| --- | --- | --- |
| CFR-AC-001 | Seluruh requirement Must terimplementasi dan pengujian otomatisnya lolos pada CI headless. | Bagian 5, 6, 10, 11 |
| CFR-AC-002 | Boot normal headless mencapai status siap tanpa error; boot ganda tidak menulis store. | FR-001, FR-004 |
| CFR-AC-003 | Simulasi pembaruan: store fixture versi lama dimigrasi otomatis pada boot dengan cadangan; data tidak hilang. | FR-020, INT-002 |
| CFR-AC-004 | Kill test: proses dihentikan paksa saat tulis dan migrasi; boot berikutnya pulih tanpa kehilangan data. | INT-103 |
| CFR-AC-005 | Pause-resume: antrean tulis disiram saat jeda; status dan route pulih konsisten. | INT-101, INT-102 |
| CFR-AC-006 | Pengaturan pemain (termasuk volume audio) bertahan setelah mulai ulang aplikasi. | FR-017, FR-024 |
| CFR-AC-007 | Kompatibilitas SDD-01 tetap utuh: TF-01 s.d. TF-08 lolos, gdlint bersih, APK debug CI hijau, scene boot tetap menampilkan teks versi. | INT-006, INT-007 |
| CFR-AC-008 | Spesifikasi SDD-02 (antarmuka, kebijakan alokasi, batas polyphony, penanganan kesalahan) disetujui sebelum implementasi dimulai. | Aturan gerbang SDD |

## 17. Pertanyaan Terbuka

Keputusan berikut belum dikunci. Penandaan O-0xx adalah usulan penambahan pada Decision Log; penomoran final ditetapkan bersama persetujuan pemilik proyek. Rekomendasi teknis disertakan, namun tidak diikat sebelum disetujui.

### OJ-1 (usulan O-022): Pola Application Lifecycle

- Permasalahan: bagaimana titik masuk aplikasi disusun pada Godot.
- Opsi: (a) custom `MainLoop`/`SceneTree` skrip; (b) autoload bootstrap dengan scene utama biasa.
- Kelebihan/kurangan: opsi (a) kendali penuh siklus hidup, namun kompleks, berisiko terhadap perilaku export Android dan sulit diuji; opsi (b) sederhana, stabil pada export Android, selaras SDD-01, dengan tetap dapat menangkap notifikasi pause/resume.
- Rekomendasi: opsi (b).
- Dampak: menentukan struktur AppBootstrap dan pengujian boot pada desain SDD-02.

### OJ-2 (usulan O-023): Pola Akses Layanan

- Permasalahan: bagaimana modul menemukan layanan (autoload Godot vs service locator tunggal).
- Opsi: (a) autoload per layanan sesuai TECHNICAL_ARCHITECTURE bagian 6; (b) satu autoload wadah (service locator) yang memegang seluruh layanan.
- Kelebihan/kurangan: (a) idiomatik Godot, akses langsung, jumlah autoload bertambah; (b) satu autoload, lebih mudah disuntik untuk pengujian, namun menjadi titik ketergantungan pusat dan melanggar semangat autoload minimum secara struktur.
- Rekomendasi: (a) dengan daftar autoload final ditetapkan pada desain, mematuhi prinsip minimum.
- Dampak: memengaruhi seluruh kode pemanggil layanan dan struktur pengujian.

### OJ-3 (usulan O-024): Cakupan Input Manager pada SDD-02

- Permasalahan: apakah kontrol permainan dirancang sekarang atau menunggu kebutuhan pertandingan (SDD-05).
- Opsi: (a) façade input penuh sejak SDD-02; (b) façade minimal (action map + input sintetis); (c) tunda seluruhnya ke SDD-05.
- Kelebihan/kurangan: (a) mencegah penulisan ulang, namun mendesain kontrol tanpa kebutuhan nyata (berisiko salah); (b) menutup kebutuhan testability tanpa mendesain prematur; (c) paling ringan namun meninggalkan pembacaan input tersebar selama beberapa tahap.
- Rekomendasi: (b), sesuai prioritas Should pada FR-027 dan FR-028.
- Dampak: menentukan apakah modul input masuk daftar layanan SDD-02.

### OJ-4 (usulan O-025): Penyimpanan Log

- Permasalahan: apakah log file disimpan pada perangkat pemain.
- Opsi: (a) log bergulir kecil pada `user://logs/` (mis. 3 berkas, 512 KB per berkas); (b) hanya keluaran debug pengembangan, tanpa log file pada rilis.
- Kelebihan/kurangan: (a) memudahkan diagnosis laporan pemain, dengan biaya penyimpanan kecil; (b) paling ringan, namun laporan kegagalan pemain tidak dapat diperiksa.
- Rekomendasi: (a) dengan tingkat bawaan WARN pada rilis.
- Dampak: menentukan rancangan LogService dan ketentuan privasi log.

### OJ-5: Evaluasi Framework Pengujian (mandat P-008)

- Permasalahan: P-008 menetapkan evaluasi ulang kebutuhan framework pengujian pada requirement SDD-02.
- Opsi: (a) lanjut harness kustom dengan struktur suite; (b) mengadopsi GUT; (c) mengadopsi gdUnit4.
- Kelebihan/kurangan: (a) tanpa dependensi, konsisten SDD-01, biaya struktur test sendiri; (b) dan (c) fitur lengkap (assertion, laporan, CI ready), namun menambah dependensi pihak ketiga yang selama ini dihindari dan mengubah test harness fondasi.
- Rekomendasi: (a); evaluasi ulang berikutnya bila jumlah pengujian SDD-02 menunjukkan biaya struktur melebihi manfaat.
- Keputusan: opsi (a) disetujui pemilik proyek pada 2026-10-30; keputusan ini menegaskan kembali P-008 untuk tahap SDD-02 dan menjadi masukan definitif bagi Technical Design.
- Dampak: menentukan struktur `game/tests/` dan CI pada SDD-02; berpotensi menambah keputusan dependensi baru.

## 18. Di Luar Lingkup

1. Implementasi kode dan antarmuka terperinci (menyusul Technical Design dan Specification SDD-02).
2. Gameplay apa pun: unit, combat, ability, AI, peta, ekonomi, rank (SDD-05 s.d. SDD-11).
3. Skema dan validator data konten (SDD-03; lihat O-005, O-006).
4. Scene dan UI lobby, menu pengaturan tampilan (SDD-04).
5. Konten audio dan announcer (SDD-09, SDD-12).
6. Kontrol permainan final (SDD-05; lihat OJ-3).
7. Sistem pembaruan daring, cloud, multiplayer, monetisasi (non-goals proyek).
8. Signing rilis produksi dan keystore (O-018, SDD-13).
9. Perubahan konfigurasi Godot, workflow CI, atau toolchain SDD-01.
10. Proteksi anti-manipulasi tingkat lanjut data rank (O-009, SDD-10).

## Referensi

- [TECHNICAL_ARCHITECTURE](../../TECHNICAL_ARCHITECTURE.md)
- [DECISION_LOG](../../DECISION_LOG.md): D-001 s.d. D-006, P-003, P-004, P-007 s.d. P-012, P-018, O-009, O-019, O-020, O-021
- [ROADMAP](../../ROADMAP.md)
- [DATA-PERSISTENCE-SPEC](../specifications/DATA-PERSISTENCE-SPEC.md)
- [DATA-MIGRATION-SPEC](../specifications/DATA-MIGRATION-SPEC.md)
- [UPDATE-SYSTEM-SPEC](../specifications/UPDATE-SYSTEM-SPEC.md)
- [GODOT-CONFIGURATION-SPEC](../specifications/GODOT-CONFIGURATION-SPEC.md)
- [REPOSITORY-STRUCTURE-SPEC](../specifications/REPOSITORY-STRUCTURE-SPEC.md)
- [CI-PIPELINE-SPEC](../specifications/CI-PIPELINE-SPEC.md)
- [TEMPLATE-REQ](../../templates/TEMPLATE-REQ.md)

## Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-30
