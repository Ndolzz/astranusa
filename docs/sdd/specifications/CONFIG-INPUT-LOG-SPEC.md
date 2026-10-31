# CONFIG-INPUT-LOG-SPEC: Spesifikasi ConfigService, InputService, dan LogService

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Dokumen desain: CORE-FRAMEWORK-ARCHITECTURE bagian 3.6, INPUT-SYSTEM-DESIGN, LOGGING-SYSTEM-DESIGN (Approved, 2026-10-31)
- Basis audit: HEAD `aa636633` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini menetapkan kontrak final tiga layanan: ConfigService (pemuatan bertingkat, validasi dasar, pengaturan pemain), InputService (façade action map dan input sintetis), dan LogService (tingkat, format, buffer, rotasi, privasi). Tanda tangan antarmuka berada pada SERVICE-API-SPEC bagian 3, 5, dan 8. Ketiga layanan dipisahkan dalam satu dokumen karena kontraknya ringkas dan saling terkait pada urutan boot; masing-masing tetap satu berkas entri utama (CFR-NFR-008).

## 2. ConfigService

### 2.1 Requirement Terkait

CFR-FR-015 s.d. CFR-FR-018, CFR-INT-005, CFR-AC-006.

### 2.2 Pemuatan Bertingkat (CFR-FR-015)

1. `load_config(file_name)` membaca `res://config/<file_name>` sebagai sumber dasar; berkas dengan nama sama pada `user://assets_override/<file_name>` menimpa nilai kunci yang sama.
2. Penimpa rusak (tidak terurai sebagai JSON, bukan objek kunci-nilai, atau gagal validasi skema) diabaikan dengan WARN; nilai dasar tetap dipakai.
3. Pada SDD-02 belum ada berkas konfigurasi konten pada `res://config/` (direktori dijadwalkan SDD-03 sesuai REPOSITORY-STRUCTURE-SPEC bagian 5); `load_config` pada keadaan tanpa berkas mengembalikan `missing_base` yang merupakan keadaan normal pada SDD-02, bukan kegagalan. Mekanisme penuh diuji dengan fixture pada suite.
4. Kegagalan berkas dasar setelah SDD-03 (berkas wajib rusak) adalah fatal boot sesuai kelas layanan kritis (CORE-FRAMEWORK-ARCHITECTURE bagian 5).

### 2.3 Kerangka Validasi Dasar (CFR-FR-016)

1. Skema deklaratif ringan per berkas: daftar kunci wajib dan tipe nilai yang diharapkan (`bool`, `int`, `float`, `string`, `array`, `dictionary`).
2. Validasi berjalan pada pemuatan: kunci wajib hilang atau tipe tidak sesuai menolak berkas dengan status `invalid` dan pesan yang menyebut berkas, kunci, dan harapan; tidak ada nilai bawaan senyap untuk data tidak valid.
3. Skema konten penuh menyusul SDD-03 (O-005, O-006); kerangka ini wajib cukup untuk pengujian SDD-02.

### 2.4 Pengaturan Pemain (CFR-FR-017, CFR-FR-018)

1. Nilai default aman terdefinisi untuk setiap kunci pengaturan SDD-02: kunci volume `audio/master`, `audio/music`, `audio/sfx`, `audio/announcer` bernilai 1.0. Kunci baru pada tahap berikutnya wajib membawa nilai default.
2. `get_setting(key, default)` mengembalikan nilai tersimpan atau default; kunci tak dikenal pada berkas memakai default dengan WARN sekali per kunci per sesi; boot tetap siap (CFR-FR-018).
3. `set_setting(key, value)` memperbarui memori, memancarkan signal `setting_changed`, dan mengantrekan tulis store `settings` melalui SaveService; penulisan berkas hanya oleh SaveService.
4. `apply_player_settings()` (langkah 6) membaca store `settings` hasil SaveService; store `safe_mode` atau `deferred`: nilai default dipakai dengan WARN dan status `degraded` (CFR-FR-002).

## 3. InputService

### 3.1 Requirement Terkait

CFR-FR-027, CFR-FR-028, CFR-INT-101, CFR-INT-102.

### 3.2 Action Map (Keputusan SP-6)

1. `initialize(action_config, logger)` mendaftarkan seluruh aksi pada `action_config` ke `InputMap` engine; struktur data: `{"actions": [{"name": String, "type": String, "events": [Dictionary InputEvent]}]}`.
2. Pada SDD-02, sumber `action_config` adalah data bawaan internal (konstanta pada `input_service.gd`): aksi `ui_confirm` dan `ui_cancel` dengan pemetaan default; direktori `game/config/` tetap dijadwalkan SDD-03 sesuai REPOSITORY-STRUCTURE-SPEC. Sejak SDD-03, AppBootstrap mengalihkan sumber ke berkas konfigurasi tanpa perubahan antarmuka; jalur pemuatan berkas diuji sejak SDD-02 dengan fixture.
3. Aksi pertandingan tidak didesain pada SDD-02 (OJ-3); penambahan aksi pada tahap berikutnya adalah penambahan data, bukan perubahan kode façade.
4. Data aksi tidak sah (struktur salah) memasukkan mode terdegradasi tanpa aksi (CFR-FR-002); pendaftaran sebagian tidak dilakukan: seluruh aksi divalidasi sebelum satu pun didaftarkan.

### 3.3 Pembacaan dan Status Pause

1. `is_action_pressed`, `is_action_just_pressed`, `is_action_just_released`, dan `get_axis` membaca `InputMap` engine dan lapisan injeksi.
2. Saat status pause aktif (`set_paused(true)` oleh AppBootstrap), seluruh pembacaan mengembalikan kondisi dilepas (`false`, `0.0`) (CFR-INT-101); resume mengembalikan pembacaan normal (CFR-INT-102).
3. Aksi tak terdaftar pada pembacaan: `false` dengan WARN sekali per aksi per sesi (mencegah banjir log).

### 3.4 Input Sintetis (CFR-FR-028)

1. `inject_press(action, strength)` dan `inject_release(action)` menyimpan nilai injeksi pada peta kecil yang dipakai API pembacaan dengan prioritas di atas keadaan engine.
2. Mode pengujian aktif bila `OS.is_debug_build()` atau penanda uji eksplisit diset; pada rilis non-debug tanpa penanda, injeksi ditolak `rejected` (injeksi bukan jalur produksi).
3. `clear_injections()` membersihkan seluruh injeksi; dipanggil otomatis pada awal tiap suite pengujian; injeksi tidak bertahan lintas sesi.
4. Injeksi aksi tak terdaftar ditolak `unknown_action` dengan ERROR pada mode pengujian.

### 3.5 Aturan Audit (CFR-FR-027)

Tidak ada pembacaan input mentah (`Input.*` langsung) pada kode lapisan `app/` dan `core/` di luar InputService; pengecualian: kode presentation yang menangani event UI node Control miliknya sendiri. Pemeriksaan pola menjadi butir audit kode dan tinjauan CI.

## 4. LogService

### 4.1 Requirement Terkait

CFR-FR-029 s.d. CFR-FR-031, CFR-INT-101, CFR-FR-003, requirement bagian 14 nomor 3, CFR-NFR-005; keputusan SP-1 tahap desain (P-022): tiga berkas, 512 KB per berkas, bawaan WARN rilis.

### 4.2 Tingkat dan Bawaan (CFR-FR-029)

1. Empat tingkat: `DEBUG`, `INFO`, `WARN`, `ERROR`; catatan di bawah tingkat aktif tidak melewati antarmuka penyimpanan.
2. Bawaan: `WARN` pada rilis; `INFO` pada pengembangan (`OS.is_debug_build()`); penimpa konfigurasi `log/level` berlaku untuk pengujian; nilai penimpa tidak sah diabaikan dengan WARN dan bawaan tetap dipakai.

### 4.3 Format Catatan

Satu baris per catatan: `<ISO-8601 UTC> <LEVEL> [<modul>] <pesan>`; cap waktu `Time.get_datetime_string_from_system(true)` (UTC) selaras keterbandingan antar perangkat dan CI.

### 4.4 Buffer dan Siraman

1. Catatan masuk buffer memori (Array baris); antarmuka pencatatan tidak pernah melakukan I/O langsung.
2. Siraman dipicu: gabungan ukuran baris buffer melampaui 4 KB, notifikasi pause (CFR-INT-101), penutupan normal (CFR-FR-003), dan `flush()` eksplisit.
3. Buffer penuh sebelum siraman terjadwal: baris terlama dipangkas dan penanda `... <n> baris terpangkas ...` dimasukkan agar pemangkasan terlihat; pemangkasan memilih kehilangan catatan lama, bukan memblokir pemanggil.

### 4.5 Rotasi dan Pemangkasan (CFR-FR-030)

1. Berkas aktif `user://logs/astranusa.log`; saat ukuran melampaui 512 KB pada saat siraman, rotasi menggulirkan: `.log` menjadi `.log.1`, `.log.1` menjadi `.log.2`, `.log.2` dihapus, berkas aktif baru dibuat.
2. Maksimum tiga berkas; total jejak paling banyak sekitar 1,5 MB; retensi hanya berbasis rotasi.
3. Log tidak pernah menulis ke `res://` maupun `user://saves/`; pemeriksaan jalur adalah butir audit.

### 4.6 Privasi Isi (Requirement Bagian 14 Nomor 3)

Log hanya memuat nama modul, pesan teknis terformat, dan cap waktu. Tidak dicatat: isi store utuh, data pribadi pemain (kata sandi tidak ada pada game offline; nama panggilan hanya sebagai fakta dimuat, bukan isinya), dan nilai pengaturan pribadi. Antarmuka pencatatan menerima string terformat; pemanggil memformat ringkasan.

### 4.7 Cermin Keluaran

Pada mode headless CI dan pengembangan, catatan dicerminkan ke keluaran standar agar kegagalan suite terbaca pada log workflow; pada rilis, cermin hanya untuk ERROR.

### 4.8 Kegagalan Penulisan

Setelah boot, kegagalan penulisan (penyimpanan penuh, berkas hilang) memasukkan mode tanpa berkas: catatan tetap dicerminkan ke keluaran standar, `file_mode_status()` mengembalikan `fileless`, peringatan dicatat sekali per kejadian; aplikasi berjalan. Kegagalan inisialisasi direktori pada boot tetap fatal (CFR-FR-002).

## 5. Penanganan Kesalahan Gabungan

| Layanan | Kegagalan | Kelas | Perlakuan |
| --- | --- | --- | --- |
| ConfigService | Penimpa rusak. | Data. | Diabaikan dengan WARN; dasar dipakai (FR-015). |
| ConfigService | Data dasar tidak valid (pasca SDD-03). | Fatal boot. | `invalid`; boot berhenti (FR-016, FR-002). |
| ConfigService | Store settings mode aman saat langkah 6. | Terdegradasi. | Default dengan WARN; `degraded` (FR-018). |
| InputService | Konfigurasi aksi rusak. | Terdegradasi. | Boot lanjut tanpa aksi (FR-002). |
| InputService | Aksi tak terdaftar dibaca. | Data. | `false`; WARN sekali per aksi per sesi. |
| InputService | Injeksi di luar mode pengujian. | Pelanggaran kontrak. | `rejected`; ERROR. |
| LogService | Inisialisasi gagal. | Fatal boot. | `"fatal"`; boot berhenti (FR-002). |
| LogService | Penulisan gagal pasca boot. | Terdegradasi. | Mode tanpa berkas; status dapat ditanyai. |
| LogService | Nilai `set_level` tidak sah. | Pelanggaran kontrak. | Ditolak; ERROR dan `push_error`. |

## 6. Validasi dan Kasus Uji

`core_config_tests.gd`:

| ID | Kasus | Requirement | Lulus Bila |
| --- | --- | --- | --- |
| CF-01 | Penimpa sah diterapkan; penimpa rusak diabaikan. | FR-015 | Nilai dasar tertimpa; WARN tercatat untuk rusak. |
| CF-02 | Validasi menolak data tidak valid. | FR-016 | `invalid` dengan kunci pada pesan. |
| CF-03 | Kunci tak dikenal memakai default tanpa menggagalkan boot. | FR-018 | Nilai default; WARN; boot siap. |
| CF-04 | Ubah-simpan-muat ulang pengaturan. | FR-017, AC-006 | Nilai bertahan setelah muat ulang. |
| CF-05 | `load_config` tanpa berkas pada SDD-02. | FR-015 | `missing_base` normal; tanpa kegagalan. |

`core_input_tests.gd`:

| ID | Kasus | Requirement | Lulus Bila |
| --- | --- | --- | --- |
| IN-01 | Registrasi aksi dari data bawaan. | FR-027 | Aksi terdaftar pada `InputMap`. |
| IN-02 | Pembacaan pressed, tepi naik, tepi turun, dan poros. | FR-027 | Seluruh pembacaan sesuai injeksi. |
| IN-03 | Injeksi mengungguli keadaan engine. | FR-028 | Pembacaan mengikuti nilai injeksi. |
| IN-04 | `clear_injections` membersihkan seluruh injeksi. | FR-028 | Pembacaan kembali normal. |
| IN-05 | Saat pause seluruh pembacaan dilepas. | INT-101 | `false`/`0.0` selama `set_paused(true)`. |
| IN-06 | Injeksi aksi tak terdaftar ditolak. | FR-028 | `unknown_action`; ERROR. |
| IN-07 | Injeksi di luar mode pengujian ditolak. | FR-028 | `rejected` pada mode non-debug tanpa penanda. |

`core_log_tests.gd`:

| ID | Kasus | Requirement | Lulus Bila |
| --- | --- | --- | --- |
| LG-01 | Penyaringan tingkat. | FR-029 | Catatan di bawah tingkat tidak ditulis. |
| LG-02 | Format baris dan cap waktu UTC. | Bagian 4.3 | Baris sesuai pola. |
| LG-03 | Siraman eksplisit dan batas buffer. | Bagian 4.4 | Buffer kosong setelah siraman; batas memicu siraman. |
| LG-04 | Pemangkasan buffer penuh dengan penanda. | Bagian 4.4 | Penanda tercantum. |
| LG-05 | Rotasi tiga berkas 512 KB. | FR-030 | Tiga berkas; terlama terhapus. |
| LG-06 | Tidak ada penulisan di luar `user://logs/`. | FR-030 | Pemeriksaan jalur lolos. |
| LG-07 | Kegagalan inisialisasi fatal boot. | FR-002 | Boot berhenti dengan pesan. |
| LG-08 | Mode tanpa berkas pasca boot. | Bagian 4.8 | `fileless`; aplikasi berjalan. |

## 7. Batasan

1. Skema data konten penuh dan validator penuh menyusul SDD-03 (O-005, O-006).
2. Kontrol sentuh konkret dan aksi pertandingan menyusul SDD-04 dan SDD-05 (OJ-3).
3. Log terstruktur JSON per baris ditolak pada desain; format baris ringkas final.
4. Tidak ada pengiriman log ke layanan luar (offline penuh).

## 8. Referensi

- CORE-FRAMEWORK-ARCHITECTURE bagian 3.6; INPUT-SYSTEM-DESIGN; LOGGING-SYSTEM-DESIGN.
- UPDATE-SYSTEM-SPEC bagian 5.2 (penimpa aset), 6 (urutan boot), 7 (pesan pemain).
- Keputusan SP-6 (sumber action map SDD-02), disetujui pemilik proyek 2026-10-31; P-022 (parameter log).
- SERVICE-DEPENDENCY-DESIGN tabel 3.2 (ketergantungan tiga layanan).

## 9. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
