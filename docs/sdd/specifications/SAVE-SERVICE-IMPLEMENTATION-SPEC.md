# SAVE-SERVICE-IMPLEMENTATION-SPEC: Spesifikasi Implementasi SaveService dan Kerangka Migrasi

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Dokumen desain: SAVE-SERVICE-DESIGN (Approved, 2026-10-31)
- Spesifikasi yang diimplementasikan: DATA-PERSISTENCE-SPEC dan DATA-MIGRATION-SPEC (Approved, 2026-10-30)
- Basis audit: HEAD `aa636633` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini menetapkan kontrak final SaveService: amplop store dan checksum, penulisan atomik, antrean tulis, pemeriksaan ruang, pemuatan dan pemulihan, kerangka migrasi, jurnal, cadangan, mode aman dan karantina, serta mode `--migrate-only`. Tanda tangan antarmuka publik berada pada SERVICE-API-SPEC bagian 6. SaveService adalah satu-satunya pemilik akses `user://saves/` (DATA-PERSISTENCE-SPEC bagian 9); seluruh modul lain mengakses melalui antarmuka. Struktur isi tiap store didefinisikan tahap pemiliknya; daftar store mengikuti DATA-PERSISTENCE-SPEC bagian 6, dan pada SDD-02 hanya store yang dapat dibentuk dengan nilai default yang dibuat; sisanya dibentuk tahap pemiliknya.

## 2. Requirement Terkait

CFR-FR-004, CFR-FR-019 s.d. CFR-FR-023, CFR-INT-001 s.d. CFR-INT-004, CFR-INT-103, CFR-NFR-006, CFR-NFR-007, CFR-AC-003, CFR-AC-004, CFR-AC-006; skenario T-08, T-09, T-10, T-12 pada UPDATE-TEST-PLAN.

## 3. Struktur Internal dan Pembungkas Berkas

1. `save_service.gd` (autoload): antrean tulis, momen simpan, orkestrasi langkah 5 boot, status store, antarmuka publik.
2. `save_store.gd`: amplop, checksum, penulisan atomik, pemuatan, mode aman, karantina. Seluruh operasi berkas melewati pembungkas berkas tipis (antarmaca `read_file`, `write_file`, `rename`, `file_exists`, `dir_exists`, `make_dir`, `copy_file`, `delete_file`, `list_dir`) yang implementasinya dapat diganti versi memori pada pengujian (requirement bagian 15 nomor 2).
3. `save_migration.gd`: registri langkah, rantai, jurnal, cadangan, pemulihan; dapat diinstansiasi langsung tanpa autoload oleh pengujian dan `--migrate-only`.
4. `save_space_probe.gd`: pemeriksaan ruang bebas.

## 4. Amplop dan Checksum

1. Amplop per store: `{"schema_version": int, "app_version_written": String, "checksum": String, "data": Dictionary}` pada `user://saves/<store_name>.store` (DATA-PERSISTENCE-SPEC bagian 7).
2. Checksum dihitung atas representasi kanonik `data`: `JSON.stringify(data, "", true)` (kunci terurut) yang di-hash SHA-256 melalui `Crypto.hash` dengan tipe `HASH_SHA256`, hasilnya dalam heksadesimal huruf kecil. Kanonisasi memastikan checksum stabil terhadap urutan kunci.
3. `app_version_written` diambil dari `game/version.json` melalui `src/core/app_version.gd` (P-004).
4. Pemuatan menghitung ulang checksum dan membandingkan; ketidakcocokan memicu jalur pemulihan bagian 7.

## 5. Penulisan Atomik dan Antrean Tulis

1. Urutan penulisan: tulis `user://tmp/<store>.tmp` dengan amplop lengkap dan data final `data` yang telah di-hash `checksum`-nya → pastikan penulisan selesai → ganti nama menjadi `user://saves/<store>.store`. Tidak ada penulisan langsung ke berkas target; tidak ada modul lain yang menulis.
2. Antrean tulis tunggal: satu entri per store; entri baru untuk store yang sama menimpa entri sebelumnya (hanya keadaan akhir yang ditulis).
3. Siraman antrean berjalan pada momen aman: momen simpan eksplisit (`queue_write`), pause (CFR-INT-101), penutupan normal (CFR-FR-003), dan setelah migrasi; tidak pernah pada jalur per-frame (CFR-NFR-006).
4. Pemicu momen simpan minimum (CFR-FR-021): akhir pertandingan (antarmuka siap dipanggil lapisan app sejak SDD-05), perubahan pengaturan (dipicu ConfigService melalui `queue_write("settings")`), perubahan rank (SDD-10), dan penutupan normal. Pada SDD-02, pemicu tanpa pemanggil nyata diuji dengan pemanggil uji.
5. Boot normal tanpa perubahan versi schema tidak menulis store apa pun (CFR-FR-004): seluruh langkah 5 hanya membaca; pengujian membandingkan stempel waktu berkas pada boot ganda.

## 6. Pemeriksaan Ruang (CFR-FR-022)

1. Sebelum menulis atau migrasi, layanan menghitung kebutuhan: dua kali ukuran store terbesar yang diketahui, ditambah estimasi cadangan untuk migrasi.
2. `save_space_probe.gd` memeriksa ruang bebas pada `user://`: pada Android melalui `StatFs` JavaClass bila tersedia; pada platform atau kondisi yang tidak dapat diperiksa, status `unknown` dan layanan melanjutkan dengan pola atomik sebagai perlindungan (diizinkan DATA-PERSISTENCE-SPEC bagian 12 nomor 3).
3. Ruang tidak cukup: penulisan ditunda, store berstatus `deferred`, pesan jelas kepada pemain sesuai kebijakan pesan, data lama tetap utuh; penundaan dicatat dan dapat ditanyai melalui `free_space_report()`. Percobaan ulang terjadi pada siraman berikutnya setelah pemeriksaan ulang ruang.

## 7. Pemuatan, Pemulihan, dan Mode Aman (CFR-FR-023)

Urutan pemuatan per store pada langkah 5:

1. Berkas store tidak ada: inisialisasi pertama; store default dibuat di memori dengan `schema_version` terkini dan nilai default aman; keberadaan berkas diperiksa sebelum penulisan; penulisan default ditunda hingga momen simpan pertama agar boot pertama tidak menulis (kecuali store yang memang harus diinisialisasi; pada SDD-02 seluruh pembentukan awal tertunda ke momen simpan). Store baru berstatus `ok`.
2. Berkas ada dan checksum cocok: `data` dimuat; status `ok`.
3. Checksum tidak cocok: jalur pemulihan cadangan berjenjang (keputusan SP-8): cadangan terbaru pada `user://saves/backup/` diuji lebih dahulu; bila tidak valid, cadangan lebih lama diuji (maksimal dua sesuai retensi); cadangan pertama yang valid dipakai dan dicatat `recovered`.
4. Seluruh cadangan tidak valid atau tidak tersedia: mode aman; berkas lama dipindahkan ke `user://saves/quarantine/<store>.<stempel waktu>.corrupt` (tidak pernah dihapus atau ditimpa), store default dibuat di memori dan ditandai `safe_mode`; modul pemakai membaca nilai default; pemain menerima pesan non-teknis sesuai requirement bagian 13 nomor 2.
5. Kegagalan satu store tidak menghentikan store lain (DATA-PERSISTENCE-SPEC bagian 6; DATA-MIGRATION-SPEC bagian 8 nomor 4).

## 8. Kerangka Migrasi (CFR-FR-020)

### 8.1 Registri dan Rantai

1. Langkah migrasi terdaftar per store dengan nama `migrate_<store>_<from>_to_<to>` (penamaan teknis berbahasa Inggris sesuai REPOSITORY-STRUCTURE-SPEC bagian 6 nomor 6; menegaskan pola `migrate_1_to_2` pada DATA-MIGRATION-SPEC bagian 4), terurut menaik; kenaikan selalu satu tingkat per langkah.
2. Setiap langkah adalah fungsi murni: menerima Dictionary struktur lama, mengembalikan Dictionary struktur baru, tanpa efek samping berkas. Langkah yang telah dirilis tidak pernah dihapus.
3. Setiap langkah wajib memiliki unit test dengan fixture versi lama pada `game/tests/fixtures/migration/` (DATA-MIGRATION-SPEC bagian 4 nomor 3).
4. `register_migration` dipanggil sebelum boot oleh kode registrasi migrasi (bagian 9); langkah ganda untuk pasangan versi yang sama ditolak `duplicate`.

### 8.2 Jurnal

1. Berkas `user://saves/migration_journal.json`: `{"stores": {"<store>": {"status": "idle"|"in_progress"|"completed", "started_at": String, "source_version": int, "completed_at": String}}}`; stempel waktu ISO-8601 UTC selaras format log.
2. Ditulis `in_progress` (beserta `started_at` dan `source_version`) sebelum langkah pertama; `completed` (beserta `completed_at`) setelah rename atomik berhasil; boot normal tanpa migrasi tidak menulis jurnal.
3. Pada boot, jurnal `in_progress` memicu pemulihan cadangan lalu percobaan ulang maksimal satu kali (DATA-MIGRATION-SPEC bagian 7).

### 8.3 Cadangan dan Retensi

1. Sebelum migrasi, store lama disalin ke `user://saves/backup/<store>.v<versi_lama>.bak`.
2. Retensi paling banyak dua cadangan terbaru per store; lebih lama dihapus terlama lebih dahulu; hanya kebijakan retensi yang boleh menghapus cadangan; cadangan tidak dihapus ketika migrasi gagal.
3. Cadangan dipakai oleh jalur pemulihan bagian 7 dan jurnal `in_progress`.

### 8.4 Alur Migrasi pada Boot

Mengikuti SAVE-SERVICE-DESIGN bagian 3.7 nomor 4 tanpa perubahan: bersihkan `user://tmp/` → baca jurnal; `in_progress` memicu pemulihan dan satu percobaan ulang → per store: bandingkan `schema_version`; lebih rendah berarti cadangkan, jurnal `in_progress`, rantai di memori, validasi hasil, berkas sementara, rename atomik, jurnal `completed`. Rantai dikerjakan sepenuhnya di memori; berkas lama utuh sampai rename.

### 8.5 Kegagalan Migrasi

1. Kegagalan mencakup checksum lama tidak valid, hasil rantai tidak lolos validasi, pengecualian langkah, dan ruang tidak cukup.
2. Prosedur: pulihkan cadangan, `schema_version` tetap versi lama, catat kegagalan pada log, pesan pemain sesuai UPDATE-SYSTEM-SPEC bagian 7 nomor 3 (data aman, versi lama digunakan); bila kode terkini tidak dapat membaca versi lama, store mode aman tanpa menghapus data.
3. Kegagalan satu store tidak menghentikan store lain; tidak ada jalur yang menginisialisasi ulang atau menghapus store akibat kegagalan (DATA-MIGRATION-SPEC bagian 8 nomor 5).
4. Idempotensi: langkah idempoten terhadap input versi lama yang sama; migrasi hanya berjalan bila `schema_version` lebih rendah dari versi terkini (DATA-MIGRATION-SPEC bagian 10).

## 9. Mode `--migrate-only` (Keputusan SP-7)

1. Skrip `game/tools/migrate_stores.gd` (penamaan kata kerja dan objek) dijalankan: `godot --headless --script res://tools/migrate_stores.gd -- --migrate-only <direktori_store>`.
2. Skrip menginstansiasi `save_migration.gd` langsung tanpa scene dan tanpa layanan lain, membaca store dari direktori argumen (fixture CI atau salinan), menjalankan rantai, mencetak laporan per store (nama, versi awal, versi akhir, status, cadangan dibuat), dan keluar dengan kode nol bila seluruh store berhasil dan kode bukan nol bila ada kegagalan.
3. Mode ini memenuhi DATA-MIGRATION-SPEC bagian 4 nomor 5 dan skenario T-08 s.d. T-12 otomatis CI (CFR-INT-004); pada SDD-02 belum ada langkah migrasi terdaftar untuk store mana pun (seluruh store versi 1), sehingga mode ini membuktikan rantai kosong dan penolakan fixture tak dikenal; keberhasilan rantai bertahap dibuktikan dengan fixture uji internal pada suite.

## 10. Penanganan Kesalahan

| Kegagalan | Kelas | Perlakuan |
| --- | --- | --- |
| Inisialisasi `user://saves/` gagal pada boot. | Fatal boot. | `"fatal"`; AppBootstrap menghentikan boot dengan pesan pemain. |
| Checksum store tidak cocok. | Data. | Pemulihan berjenjang; mode aman dan karantina bila gagal (bagian 7). |
| Ruang tidak cukup. | Data. | `deferred`; tanpa penulisan parsial; pesan pemain; percobaan ulang setelah pemeriksaan ulang. |
| Langkah migrasi gagal. | Data. | Bagian 8.5; cadangan dipulihkan; versi lama dipertahankan. |
| `queue_write` store tak dikenal. | Pelanggaran kontrak. | `error`; ERROR dan `push_error`. |
| Mutasi store `safe_mode`. | Data. | Perubahan memori ditolak untuk penulisan; status tetap `safe_mode`; WARN. |

## 11. Kondisi Normal dan Gagal

Kondisi normal: boot membaca seluruh store tanpa menulis; momen simpan menulis atomik melalui antrean; migrasi berjalan otomatis hanya setelah pembaruan dengan cadangan dan jurnal. Kondisi gagal: setiap baris tabel bagian 10 meninggalkan data lama utuh, status dapat ditanyai, dan store lain tidak terdampak.

## 12. Validasi dan Kasus Uji

`core_save_tests.gd`:

| ID | Kasus | Requirement | Lulus Bila |
| --- | --- | --- | --- |
| SV-01 | Amplop dan checksum kanonik stabil. | FR-019 | Tulis-baca menghasilkan checksum identik meski urutan kunci berbeda. |
| SV-02 | Penulisan atomik melalui tmp dan rename. | FR-019 | Tidak ada penulisan langsung ke berkas target; berkas sementara dibersihkan. |
| SV-03 | Antrean menimpa entri per store. | FR-019 | Dua antrean untuk store sama menghasilkan satu penulisan. |
| SV-04 | Boot ganda tidak menulis store. | FR-004 | Stempel waktu berkas tidak berubah. |
| SV-05 | Ruang cukup dan tidak cukup dengan probe stub. | FR-022 | Tulis berjalan; `deferred` tanpa penulisan parsial. |
| SV-06 | Checksum salah memicu pemulihan. | FR-023 | Cadangan terbaru valid dipakai; status `recovered`. |
| SV-07 | Cadangan tidak valid berjenjang lalu mode aman. | FR-023 | Cadangan lama diuji; karantina dibuat; default aman; berkas lama utuh. |
| SV-08 | Mutasi melalui update_store mengantrekan tulis. | FR-019 | `flush()` menuliskan hasil mutasi. |

`core_migration_tests.gd`:

| ID | Kasus | Requirement | Lulus Bila |
| --- | --- | --- | --- |
| MG-01 | Rantai beberapa versi berjalan berurutan. | FR-020, INT-002 | Hasil versi akhir sesuai fixture harapan. |
| MG-02 | Jurnal in_progress memicu pemulihan dan satu ulangan. | FR-020 | Boot kedua memulihkan lalu berhasil maksimal satu kali. |
| MG-03 | Cadangan retensi dua terbaru. | FR-020 | Cadangan ketiga terlama terhapus. |
| MG-04 | Langkah gagal memulihkan cadangan. | FR-020 | Versi lama; data utuh; pesan tercatat. |
| MG-05 | Migrasi tidak berjalan ulang setelah berhasil. | FR-004, INT-002 | Boot berikutnya tanpa penulisan. |
| MG-06 | Mode `--migrate-only` headless. | INT-004 | Laporan per store; kode keluar benar. |

`core_integration_tests.gd`: migrasi otomatis pada boot dengan fixture versi lama (AC-003), kill simulasi saat tulis dan migrasi (AC-004, INT-103), ubah-simpan-muat ulang pengaturan (AC-006). Kill simulasi memotong jalur pada titik: setelah penulisan tmp sebelum rename, setelah jurnal `in_progress` sebelum rename; boot pemulihan membuktikan data utuh.

## 13. Batasan

1. Struktur isi `data` per store didefinisikan tahap pemiliknya (SDD-03, SDD-04, SDD-10); SaveService hanya mengelola amplop, integritas, dan mekanika.
2. Proteksi anti-manipulasi lanjutan menyusul O-009 (SDD-10); checksum adalah mekanisme keandalan.
3. Sinkronisasi cloud tidak ada (offline penuh).
4. Manifest aset penimpa adalah titik sedia tanpa paket aktif pada SDD-02 (O-020); penerapannya milik sistem aset (UPDATE-SYSTEM-SPEC bagian 5.2).

## 14. Referensi

- DATA-PERSISTENCE-SPEC seluruh bagian (checklist bagian 13 dipenuhi); DATA-MIGRATION-SPEC seluruh bagian (checklist bagian 11 dipenuhi).
- UPDATE-SYSTEM-SPEC bagian 6, 7, 8; UPDATE-TEST-PLAN T-08 s.d. T-12.
- SAVE-SERVICE-DESIGN seluruh bagian; INITIALIZATION-LIFECYCLE-DESIGN bagian 3.2 (langkah 5).
- REPOSITORY-STRUCTURE-SPEC bagian 6 (penamaan alat).

## 15. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
