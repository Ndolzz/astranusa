# LOGGING-SYSTEM-DESIGN: Desain Sistem Pencatatan Log

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement terkait: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Basis audit: HEAD `ec3ccae` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini merancang LogService: pencatatan bertingkat dengan log bergulir pada `user://logs/`, buffer memori, dan kebijakan privasi isi. Desain ini menetapkan pilihan OJ-4: log bergulir kecil dengan tiga berkas, batas 512 KB per berkas, dan tingkat bawaan WARN pada rilis (disetujui pemilik proyek 2026-10-31, usulan P-022). Ruang lingkup: tingkat log, format, buffer dan siraman, rotasi dan pemangkasan, privasi, serta pengujian. Kebijakan pesan kepada pemain untuk kegagalan fatal diatur pada requirement bagian 13 dan dirinci per kegagalan pada dokumen layanan terkait.

## 2. Requirement yang Dilayani

CFR-FR-029 (tingkat log), CFR-FR-030 (log bergulir), CFR-FR-031 (kegagalan eksplisit; kontribusi LogService sebagai pusat pencatatan), CFR-FR-002 (LogService layanan kritis pada boot), CFR-FR-003 dan CFR-INT-101 (siraman pada penutupan dan pause), requirement bagian 14 nomor 3 (privasi isi log), CFR-NFR-005 (tanpa I/O blokir pada jalur per-frame).

## 3. Rancangan Teknis

### 3.1 Tingkat Log (CFR-FR-029)

1. Empat tingkat: DEBUG, INFO, WARN, ERROR; antarmuka `debug`, `info`, `warn`, `error` dengan parameter modul dan pesan.
2. Tingkat aktif dapat disetel dengan `set_level(level)`. Bawaan: WARN pada rilis; INFO pada pengembangan (deteksi `OS.is_debug_build()` dengan penimpa konfigurasi `log/level` untuk pengujangan). Log di bawah tingkat aktif tidak melewati antarmuka penyimpanan sama sekali.

### 3.2 Format Catatan

Satu baris per catatan: `<ISO-8601> <LEVEL> [<modul>] <pesan>`. Cap waktu memakai `Time.get_datetime_string_from_system()` dengan zona UTC agar log dapat diperbandingkan antar perangkat dan CI.

### 3.3 Buffer dan Siraman

1. Catatan ditulis ke buffer memori (Array baris) dan disiram ke berkas secara batch; antarmuka `log_*` tidak pernah melakukan I/O langsung.
2. Siraman dipicu oleh: buffer melampaui batas (4 KB gabungan baris), notifikasi pause (CFR-INT-101), penutupan normal (CFR-FR-003), dan panggilan eksplisit `flush()` untuk pengujian.
3. Bila buffer penuh sebelum siraman terjadwal, baris terlama dipangkas dengan penanda `... <n> baris terpangkas ...`; keadaan ini dicatat agar pemangkasan terlihat pada berkas akhir. Pemangkasan memilih kehilangan catatan lama, bukan memblokir pemanggil.

### 3.4 Rotasi dan Pemangkasan (CFR-FR-030)

1. Berkas aktif: `user://logs/astranusa.log`; saat ukurannya melampaui 512 KB saat siraman, berkas digulirkan: `.log` menjadi `.log.1`, `.log.1` menjadi `.log.2`, `.log.2` dihapus; kemudian berkas aktif baru dibuat.
2. Maksimum tiga berkas (aktif ditambah dua bergulir), total paling banyak sekitar 1,5 MB pada perangkat pemain.
3. Retensi berbasis rotasi: tidak ada pembersihan berbasis waktu; berkas terlama terhapus hanya saat rotasi.
4. Log tidak pernah menulis ke `res://` maupun `user://saves/`; pemeriksaan ini menjadi butir audit (requirement bagian 14).

### 3.5 Privasi Isi (Requirement Bagian 14 Nomor 3)

Log hanya memuat ringkasan diagnostik: nama modul, pesan teknis, cap waktu. Log tidak mencatat: isi store secara utuh, data pribadi pemain (nama panggilan disimpan sebagai fakta bahwa profil dimuat, bukan isinya), dan nilai pengaturan pribadi. Konvensi ini ditegakkan pada audit: pesan log tidak menerima struktur store mentah; pemanggil memformat ringkasan.

### 3.6 Mode Headless dan Cermin Keluaran

Pada mode headless CI dan pengembangan, catatan juga dicerminkan ke keluaran standar agar kegagalan suite terbaca pada log workflow. Pada rilis, cermin hanya untuk ERROR.

## 4. Kontrak Antarmodul

| Antarmuka | Rancangan |
| --- | --- |
| `debug(module, message)` / `info` / `warn` / `error` | Antarmuka pencatatan; tanpa I/O langsung. |
| `set_level(level)` | Mengubah tingkat aktif; penimpa konfigurasi pada boot. |
| `flush()` | Menyiram buffer ke berkas; dipanggil pada pause, penutupan, dan pengujian. |
| `current_level()` | Kueri tingkat aktif untuk pengujian. |
| `initialize(logs_dir)` | Mempersiapkan direktori dan berkas aktif; dipanggil AppBootstrap langkah 2. |

Ketergantungan: tidak ada; LogService hanya memakai API berkas Godot dan menjadi akhir graf ketergantungan (SERVICE-DEPENDENCY-DESIGN).

## 5. Penanganan Kesalahan

| Kegagalan | Perlakuan |
| --- | --- |
| Inisialisasi gagal (direktori atau berkas tidak dapat dibuat) pada boot. | Fatal boot sesuai FR-002: berhenti dengan pesan jelas kepada pemain; detail teknis dicerminkan ke keluaran standar. |
| Kegagalan penulisan setelah boot (penyimpanan penuh, berkas hilang). | Layanan masuk mode tanpa berkas: catatan tetap dicerminkan ke keluaran standar, status kesalahan dapat ditanyai, aplikasi berjalan; peringatan sekali per kejadian, tidak per catatan. |
| Buffer penuh. | Pemangkasan baris terlama dengan penanda (bagian 3.3). |

Tidak ada kegagalan log yang menelan kesalahan modul lain (CFR-FR-031): pengecualian pemanggil tetap dicatat sebagai ERROR.

## 6. Pertimbangan Performa

1. Antarmuka `log_*` hanya bekerja memori: penggabungan string kecil dan pemeriksaan tingkat; tidak ada alokasi berat dan tidak ada I/O pada jalur per-frame (CFR-NFR-005).
2. Siraman batch membatasi operasi berkas: paling sering saat batas buffer, pause, dan penutupan; pada jalur menganggur, siraman tidak terjadi.
3. Batas ukuran berkas dan jumlah berkas menjaga jejak penyimpanan tetap kecil dan terukur pada perangkat kelas menengah.

## 7. Alternatif yang Dipertimbangkan

| Alternatif | Kelebihan | Kekurangan | Alasan Tidak Dipilih |
| --- | --- | --- | --- |
| Tanpa berkas log pada rilis (OJ-4 opsi b). | Paling ringan; tanpa I/O. | Kegagalan pemain mustahil didiagnosis; bertentangan dengan CFR-FR-030 yang telah disetujui sehingga memerlukan proses perubahan requirement resmi. | Ditolak pemilik proyek 2026-10-31. |
| Log terstruktur JSON per baris. | Mudah diproses mesin. | Ukuran per baris besar; biaya serialisasi; tidak ada konsumen mesin pada proyek offline. | Format baris ringkas memadai. |
| Penulisan langsung per catatan tanpa buffer. | Sederhana; tanpa risiko kehilangan buffer. | I/O kecil berulang; berpotensi memblokir frame; keausan penyimpanan. | Melanggar CFR-NFR-005 dan pertimbangan performa perangkat kelas menengah. |

## 8. Risiko Teknis dan Mitigasi

| Risiko | Kemungkinan | Dampak | Mitigasi |
| --- | --- | --- | --- |
| Catatan terakhir hilang saat proses mati mendadak sebelum siraman. | Sedang | Rendah | Siraman pada pause dan penutupan; kehilangan hanya pada kill mendadak yang justru kehilangan seluruh proses. |
| Rotasi bermasalah pada berkas terkunci. | Rendah | Rendah | Hanya LogService yang menulis; satu jalur tulis; penulisan ulang rotasi gagal dicatat dan dicoba ulang pada siraman berikutnya. |
| Log tidak sengaja memuat data pribadi. | Sedang | Sedang | Konvensi 3.5; audit; antarmuka menerima string terformat, bukan struktur store. |

## 9. Strategi Pengujian

`core_log_tests.gd`: penyaringan tingkat (FR-029), format dan cap waktu, buffer dan siraman eksplisit, pemangkasan buffer penuh, rotasi dan batas tiga berkas 512 KB (FR-030), tidak adanya penulisan di luar `user://logs/`, kegagalan inisialisasi menghentikan boot (FR-002), mode tanpa berkas setelah boot tetap berjalan. Fixture: berkas log pra-isi untuk pengujian rotasi.

## 10. Kriteria Penerimaan Desain

1. Parameter OJ-4 (lokasi, tiga berkas, 512 KB, bawaan WARN) terdokumentasi dan teruji.
2. Tidak ada penulisan log di luar `user://logs/` (FR-030).
3. Jalur per-frame tanpa I/O (NFR-005) dinyatakan dan diperiksa audit.
4. Kebijakan privasi isi log tercantum dan menjadi butir audit.
5. Pemilik proyek menyetujui sebelum tahap Specification.

## 11. Referensi

- CORE-FRAMEWORK-REQUIREMENTS bagian 5.9, 13, 14
- INITIALIZATION-LIFECYCLE-DESIGN bagian 3.2, 3.4, 3.5 (urutan, penutupan, pause)
- SERVICE-DEPENDENCY-DESIGN (LogService sebagai akhir graf)
- DECISION_LOG: P-022 (usulan; OJ-4)

## 12. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
