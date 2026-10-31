# EVENT-BUS-SPEC: Spesifikasi Event Bus

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Dokumen desain: EVENT-BUS-DESIGN (Approved, 2026-10-31)
- Basis audit: HEAD `aa636633` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini menetapkan kontrak final EventBus: register event SDD-02, semantik dua mode pengiriman, kebersihan listener, validasi payload, diagnostik, penanganan kegagalan listener, dan kasus uji. Tanda tangan antarmuka berada pada SERVICE-API-SPEC bagian 4. Kebijakan kapan event dipakai berada pada SERVICE-DEPENDENCY-DESIGN bagian 3.4.

## 2. Requirement Terkait

CFR-FR-011 (event tervalidasi), CFR-FR-012 (dua mode pengiriman), CFR-FR-013 (kebersihan listener), CFR-FR-014 (diagnostik), CFR-FR-031 (kegagalan eksplisit), CFR-NFR-005 (tanpa alokasi pada jalur menganggur).

## 3. Register Event Final SDD-02

Register tunggal berada pada `core_events.gd` berisi konstanta nama event, mode, pemilik, dan kunci payload wajib. Daftar final SDD-02:

| Konstanta | Nama Event | Mode | Pemilik | Kunci Payload Wajib | Pancaran |
| --- | --- | --- | --- | --- | --- |
| `EVENT_APP_PAUSED` | `app.paused` | immediate | AppBootstrap | - | Saat notifikasi pause (CFR-INT-101). |
| `EVENT_APP_RESUMED` | `app.resumed` | immediate | AppBootstrap | - | Saat notifikasi resume (CFR-INT-102). |
| `EVENT_APP_READY` | `app.ready` | deferred | AppBootstrap | `boot_ms` (int) | Setelah status READY langkah 10. |
| `EVENT_SAVE_STORE_WRITTEN` | `save.store_written` | deferred | SaveService | `store` (String) | Setelah penulisan store berhasil tersiram. |
| `EVENT_SAVE_MIGRATION_COMPLETED` | `save.migration_completed` | deferred | SaveService | `store` (String), `from_version` (int), `to_version` (int) | Setelah migrasi satu store selesai. |
| `EVENT_CONFIG_SETTING_CHANGED` | `config.setting_changed` | immediate | ConfigService | `key` (String) | Setelah nilai pengaturan diperbarui di memori. |

Ketentuan register:

1. Seluruh konstanta didaftarkan oleh pemiliknya saat inisialisasi layanan (langkah 4 s.d. 6 boot); register diaudit: emit atau subscribe sebelum pendaftaran pemiliknya ditolak dengan status `unknown_event`.
2. Lapisan atas menambah event dengan `register_event` saat inisialisasi modulnya; menambah konstanta baru pada `core_events.gd` dilakukan bersama penambahan baris pada SERVICE-RESPONSIBILITY-MATRIX (ketentuan matriks nomor 4).
3. Nama event memakai pola `<modul>.<kejadian>` dengan huruf kecil dan titik pemisah; nilai di luar pola ditolak saat `register_event`.

## 4. Semantik Pengiriman

### 4.1 Mode Immediate

1. Listener dipanggil sinkron pada saat `emit`, berurutan sesuai urutan langganan.
2. Urutan lintas modul bukan kontrak: pemakai yang membutuhkan urutan mendeklarasikannya pada rancangan modulnya; event `config.setting_changed` adalah pengecualian terdokumentasi: nilai memori telah diperbarui sebelum listener dipanggil sehingga pembaca selalu membaca nilai baru.
3. Emit immediate yang dilakukan dari dalam listener immediate diperbolehkan dengan kedalaman dibatasi: kedalaman melebihi delapan menghasilkan ERROR dan penolakan emit (pelindung rekursi tidak terkendali).

### 4.2 Mode Deferred

1. Payload masuk antrean dan disiram sekali per frame pada `_process` EventBus melalui `flush_deferred()`.
2. Emit yang terjadi di dalam siraman tidak dieksekusi pada siraman berjalan; menunggu siraman frame berikutnya (pemutusan reentrancy, CFR-FR-012).
3. Antrean menyimpan salinan ringan referensi event dan payload; pemancar immediate tidak memodifikasi payload setelah emit (konvensi ditegakkan audit). Untuk deferred, pemancar tidak memodifikasi Dictionary payload setelah emit karena isi dikirim pada siraman berikutnya.
4. Saat penutupan, sisa antrean disiram satu kali sebelum `clear_all()`; sisa yang belum tersiram dicatat WARN.

### 4.3 Payload

1. Payload selalu Dictionary; kunci wajib diperiksa saat `emit`; kunci hilang menolak emit dengan status `invalid_payload` dan ERROR yang mencantumkan nama event dan kunci yang hilang.
2. Kunci opsional diperbolehkan; nilai payload tidak disalin mendalam.

## 5. Kebersihan Listener

1. `subscribe(name, listener, owner)` menyimpan callable dan referensi pemilik; `owner` wajib dan menjadi dasar `unsubscribe_owner`.
2. Listener dengan pemilik yang telah dibebaskan dilewati pada siraman berikutnya dan dicatat WARN; pelepasan seluruh langganan pemilik tersebut dilakukan otomatis saat pelanggaran pertama terdeteksi.
3. Saat penutupan aplikasi, sisa listener aktif dicatat sebagai peringatan (CFR-FR-013); `clear_all()` untuk pengujian menegaskan keadaan kosong.
4. `unsubscribe` idempoten; memanggil dengan callable yang tidak terdaftar tidak menimbulkan kegagalan.

## 6. Diagnostik

Pada tingkat log DEBUG (mode pengembangan), emit pada event terdaftar tanpa satu pun listener dicatat INFO dengan nama event, bukan error (CFR-FR-014). Pada rilis dengan bawaan WARN, catatan ini tidak ditulis.

## 7. Penanganan Kegagalan

| Kegagalan | Kelas | Perlakuan |
| --- | --- | --- |
| Nama event tak terdaftar pada emit atau subscribe. | Pelanggaran kontrak. | Ditolak status `unknown_event`; ERROR dan `push_error`. |
| Payload tanpa kunci wajib. | Data. | Emit ditolak `invalid_payload`; ERROR dengan rincian kunci. |
| Listener melempar kesalahan. | Terdegradasi. | Kesalahan ditangkap pada siraman, dicatat ERROR dengan nama event, siraman berlanjut ke listener berikutnya (CFR-FR-031). |
| Listener mati (pemilik dibebaskan). | Terdegradasi. | Dilewati; WARN; langganan pemilik dilepas otomatis. |
| Kedalaman rekursi immediate melebihi batas. | Pelanggaran kontrak. | Emit ditolak; ERROR. |
| `register_event` nama ganda. | Pelanggaran kontrak. | Ditolak `duplicate`; ERROR dan `push_error`. |

## 8. Kondisi Normal dan Gagal

Kondisi normal: emit immediate menyelesaikan seluruh listener sinkron; emit deferred terkirim paling cepat pada siraman frame berikutnya; jalur menganggur hanya memeriksa ukuran antrean tanpa alokasi. Kondisi gagal: seluruh baris tabel bagian 7 tetap meninggalkan EventBus dan aplikasi dalam keadaan dapat ditanyai; tidak ada kegagalan yang menelan kesalahan tanpa catatan.

## 9. Validasi dan Kasus Uji (`core_event_bus_tests.gd`)

| ID | Kasus | Requirement | Lulus Bila |
| --- | --- | --- | --- |
| EB-01 | Registrasi event baru dan penolakan nama ganda. | FR-011 | Baris kedua mengembalikan `duplicate`. |
| EB-02 | Emit dan subscribe pada nama tak terdaftar ditolak. | FR-011 | Status `unknown_event`; ERROR tercatat. |
| EB-03 | Urutan langganan immediate. | FR-012 | Listener dipanggil sinkron sesuai urutan. |
| EB-04 | Event deferred terkirim pada siraman berikutnya, bukan seketika. | FR-012 | Listener belum menerima sebelum `flush_deferred()`. |
| EB-05 | Emit di dalam siraman menunggu siraman berikutnya. | FR-012 | Tidak dieksekusi pada siraman berjalan. |
| EB-06 | Payload tanpa kunci wajib ditolak. | FR-011 | Status `invalid_payload`; nama kunci pada log. |
| EB-07 | Unsubscribe dan unsubscribe_owner membersihkan listener. | FR-013 | Listener tidak menerima event setelah pelepasan. |
| EB-08 | Listener dengan pemilik dibebaskan dilewati dengan WARN. | FR-013 | WARN tercatat; pemanggilan berlanjut. |
| EB-09 | Kegagalan listener tidak menghentikan listener lain. | FR-031 | Listener berikutnya tetap dipanggil; ERROR tercatat. |
| EB-10 | Emit tanpa listener mencatat INFO pada mode pengembangan. | FR-014 | Catatan DEBUG/INFO muncul bila tingkat aktif DEBUG. |
| EB-11 | Rekursi immediate melebihi batas ditolak. | FR-012 | Emit ditolak; ERROR tercatat. |
| EB-12 | `clear_all()` menegaskan keadaan kosong. | FR-013 | Seluruh register langganan kosong. |

## 10. Batasan

1. EventBus bukan jalur kueri: event tidak mengembalikan nilai; pola emit-kemudian-menunggu-balasan ditolak pada audit.
2. EventBus tidak berlangganan ke layanan mana pun; ia hanya memancarkan atas permintaan pemancar.
3. Urutan antrean lintas modul pada mode deferred tidak dijamin selain urutan masuk antrean.

## 11. Referensi

- EVENT-BUS-DESIGN seluruh bagian; SERVICE-DEPENDENCY-DESIGN bagian 3.4.
- LOGGING-SYSTEM-DESIGN (tingkat catatan diagnostik).
- CORE-FRAMEWORK-IMPLEMENTATION-SPEC bagian 5 (konvensi pelaporan kesalahan).

## 12. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
