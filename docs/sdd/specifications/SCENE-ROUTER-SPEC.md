# SCENE-ROUTER-SPEC: Spesifikasi Scene Router

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Dokumen desain: CORE-FRAMEWORK-ARCHITECTURE bagian 3.4 (Approved, 2026-10-31)
- Basis audit: HEAD `aa636633` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini menetapkan kontrak final SceneRouter: registry route, siklus transisi, pemuatan asinkron dengan batas waktu, kebijakan transisi bersamaan, pelepasan memori transisi, dan rekaman headless. Tanda tangan antarmuka berada pada SERVICE-API-SPEC bagian 9. SceneRouter bergantung hanya pada LogService, EventBus, AppState, dan CoreResourceLoader (SERVICE-DEPENDENCY-DESIGN tabel 3.2); tidak bergantung pada SaveService dan ConfigService.

## 2. Requirement Terkait

CFR-FR-005 (routing bernama), CFR-FR-006 (pemuatan asinkron), CFR-FR-007 (pelepasan memori transisi), CFR-FR-008 (routing headless), CFR-FR-010 (konsistensi status dan route), CFR-INT-007 (scene boot SDD-01 tetap).

## 3. Registry Route

1. Route terdaftar eksplisit melalui `register_route(name, scene_path)`; nama route memakai huruf kecil dengan kata dipisah tanda hubung (contoh `boot`); nama ganda atau path kosong ditolak.
2. Route awal SDD-02: satu route `boot` yang dipetakan ke scene boot SDD-01; router tidak melakukan transisi otomatis apa pun hingga lobby tersedia pada SDD-04 (CFR-INT-007). Route lain (mis. `lobby`) didaftarkan tahap pemiliknya dengan menambah baris pada SERVICE-RESPONSIBILITY-MATRIX terlebih dahulu.
3. Seluruh perpindahan scene pada kode hanya melalui `go_to`; pemanggilan `change_scene` di luar router adalah pelanggaran kontrak yang ditolak pada audit (CFR-FR-005).

## 4. Siklus Transisi

Urutan tetap satu siklus transisi:

1. Validasi: route terdaftar, tidak ada transisi berjalan, status aplikasi konsisten; pelanggaran menolak permintaan sebelum efek apa pun.
2. Pra-hook: pembersihan state transien pemanggil dan pemeriksaan status aplikasi; pra-hook dijalankan sinkron sebelum pemuatan dimulai.
3. Pemuatan asinkron: `CoreResourceLoader.request` dengan `timeout_ms` (bawaan 10000, keputusan SP-5) dan `poll` per frame; `progress_cb` (Callable menerima float 0.0 s.d. 1.0) dipanggil pada setiap perubahan kemajuan; frame utama tidak membeku (CFR-FR-006).
4. Aktivasi: scene baru menjadi scene aktif; route aktif diperbarui; AppState diperbarui oleh router melalui referensi yang disuntikkan (hanya pada transisi yang mengubah status aplikasi, ditetapkan tahap pemilik statusnya; pada SDD-02 hanya `mark_ready` langkah 10 yang mengubah status).
5. Pasca-hook: pemanggil dapat menjalankan penyiapan scene baru.
6. Pelepasan: `release_previous()` membebaskan scene lama dengan `queue_free()` dan menghapus referensi cache; dipanggil otomatis setelah aktivasi dan pasca-hook, dan dapat dipanggil eksplisit (CFR-FR-007).

### 4.1 Kebijakan Transisi Bersamaan (Keputusan SP-4)

1. Permintaan `go_to` saat transisi lain sedang berjalan ditolak dengan status `busy` dan ERROR pada log; transisi berjalan diselesaikan. Router tidak mengantrekan, tidak membatalkan, dan tidak menggantikan transisi berjalan.
2. Penolakan `busy` adalah status normal yang dapat ditanyai; lapisan app bertanggung jawab menahan permintaan ganda dari pengguna. Kebijakan penggantian dapat ditinjau pada SDD-04 atau SDD-05 bila kebutuhan antarmuka nyata muncul, melalui proses perubahan spesifikasi.

### 4.2 Batas Waktu dan Kegagalan Pemuatan

1. Batas waktu terlampaui: transisi dibatalkan, scene lama tetap aktif, status `timeout` dengan ERROR; permintaan loader kedaluwarsa diabaikan bila hasilnya datang terlambat.
2. Pemuatan gagal (`load_failed`): transisi dibatalkan, scene lama tetap aktif; ERROR dicatat dengan path.
3. Pembatalan tidak meninggalkan keadaan setengah: route aktif, status aplikasi, dan referensi scene tidak berubah dari keadaan sebelum permintaan.

## 5. Pelepasan Memori dan Batas Selama Transisi

1. Scene lama hanya dibebaskan setelah scene baru aktif dan pasca-hook selesai; referensi cache router atas scene lama dihapus sebelum `queue_free()` (CFR-FR-007).
2. Selama transisi, router tidak memuat resource tambahan di luar scene tujuan; batas memori selama transisi adalah satu scene lama dan satu scene baru; puncak memori transisi diukur pada verifikasi melalui penghitungan referensi sebelum dan sesudah.
3. `release_previous()` pada keadaan tanpa scene lama mengembalikan `no_previous`, bukan kegagalan.

## 6. Mode Headless dan Rekaman

1. Setiap transisi (berhasil, ditolak, gagal) direkam pada buffer riwayat internal: nama route, status, stempel waktu `Time.get_ticks_msec()`, durasi milidetik, dan batas waktu terpakai.
2. `transition_history()` mengembalikan salinan riwayat; pengujian CI mengasertasi urutan transisi tanpa rendering (CFR-FR-008).
3. Buffer riwayat dibatasi 64 entri terbaru; entri terlama dibuang saat penuh (diagnostik, bukan audit).

## 7. Penanganan Kesalahan

| Kegagalan | Kelas | Perlakuan |
| --- | --- | --- |
| Route tak terdaftar. | Pelanggaran kontrak. | `unknown_route`; ERROR dan `push_error`; route aktif dipertahankan. |
| `go_to` saat transisi berjalan. | Terdegradasi. | `busy`; ERROR; transisi berjalan lanjut. |
| Batas waktu pemuatan. | Data. | `timeout`; transisi dibatalkan; scene lama aktif. |
| Pemuatan gagal. | Data. | `load_failed`; transisi dibatalkan; scene lama aktif. |
| `register_route` nama ganda atau path kosong. | Pelanggaran kontrak. | `duplicate`/`invalid`; ERROR dan `push_error`. |
| Inisialisasi router gagal (dependensi null). | Fatal boot. | `"fatal"`; AppBootstrap menghentikan boot (langkah 9 kritis). |

## 8. Kondisi Normal dan Gagal

Kondisi normal: satu transisi berjalan dalam satu waktu; scene baru aktif; scene lama dilepas; riwayat merekam urutan. Kondisi gagal: seluruh baris tabel bagian 7 meninggalkan route aktif dan status aplikasi tidak berubah; tidak ada scene setengah aktif.

## 9. Validasi dan Kasus Uji (`core_scene_router_tests.gd`)

| ID | Kasus | Requirement | Lulus Bila |
| --- | --- | --- | --- |
| SR-01 | Route tak terdaftar ditolak eksplisit. | FR-005 | `unknown_route`; route aktif tetap. |
| SR-02 | Pemuatan asinkron dengan laporan kemajuan. | FR-006 | `progress_cb` menerima nilai meningkat; tanpa frame beku (durasi per poll di bawah anggaran). |
| SR-03 | Batas waktu mengembalikan kegagalan eksplisit. | FR-034, FR-006 | `timeout` dengan `time_source` suntik; scene lama tetap aktif. |
| SR-04 | Permintaan bersamaan ditolak. | FR-005 | `busy` pada permintaan kedua; transisi pertama selesai. |
| SR-05 | Pelepasan scene lama setelah aktivasi. | FR-007 | Jumlah referensi kembali ke tingkat sebelum transisi. |
| SR-06 | Riwayat transisi headless. | FR-008 | Riwayat sesuai urutan dan status. |
| SR-07 | Registrasi route ganda ditolak. | FR-005 | `duplicate`. |
| SR-08 | Route awal `boot` tanpa transisi otomatis. | INT-007 | `current_route() == "boot"` setelah inisialisasi; tidak ada transisi otomatis. |

## 10. Batasan

1. Router tidak mengelola layer overlay atau dialog; kebutuhan tersebut menyusul tahap antarmuka.
2. Router tidak memancarkan event transisi pada SDD-02 selain yang diperlukan; penambahan event mengikuti EVENT-BUS-SPEC register.
3. Router tidak memuat scene secara sinkron pada jalur transisi; `load_sync` hanya di luar jalur per-frame.

## 11. Referensi

- CORE-FRAMEWORK-ARCHITECTURE bagian 3.4; SERVICE-DEPENDENCY-DESIGN tabel 3.2.
- OBJECT-POOL-SPEC bagian 4 (kontrak CoreResourceLoader); SERVICE-API-SPEC bagian 9.
- INITIALIZATION-LIFECYCLE-DESIGN bagian 3.2 (langkah 9); CORE-FRAMEWORK-REQUIREMENTS bagian 12 nomor 3.

## 12. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
