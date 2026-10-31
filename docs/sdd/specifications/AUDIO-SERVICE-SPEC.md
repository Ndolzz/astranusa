# AUDIO-SERVICE-SPEC: Spesifikasi Audio Service

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Dokumen desain: CORE-FRAMEWORK-ARCHITECTURE bagian 3.7 (Approved, 2026-10-31)
- Basis audit: HEAD `aa636633` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini menetapkan kontrak final AudioService: kategori volume, kontrak pemutaran, pengelolaan voice, nilai polyphony final, perilaku headless, dan penanganan resource audio gagal. Tanda tangan antarmuka berada pada SERVICE-API-SPEC bagian 7. AudioService bergantung pada LogService dan menerima ConfigService untuk nilai volume (SERVICE-DEPENDENCY-DESIGN tabel 3.2 dan catata 1); ia tidak memanggil SaveService langsung. Konten audio (berkas suara, announcer) berada di luar cakupan SDD-02; layanan diuji dengan stream uji internal suite.

## 2. Requirement Terkait

CFR-FR-024 (kategori volume), CFR-FR-025 (API pemutaran terkendali dan polyphony), CFR-FR-026 (headless aman), CFR-INT-101, CFR-INT-102 (pause dan resume), CFR-AC-006 (volume bertahan), requirement bagian 12 nomor 6.

## 3. Kategori dan Volume

1. Kategori: `master`, `music`, `sfx`, `announcer`. Kategori `master` adalah bus keluaran global untuk pengaturan volume utama; ia bukan kategori pemutaran dan tidak memiliki voice atau batas polyphony.
2. Volume per kategori disimpan pada store `settings` dengan kunci `audio/<kategori>` bernilai 0.0 s.d. 1.0; penulisan hanya melalui ConfigService (CFR-FR-024).
3. `set_volume` memvalidasi rentang nilai; nilai di luar rentang ditolak `invalid` tanpa perubahan. Nilai diterapkan ke bus audio yang sesuai (`master` ke `AudioServer.set_bus_volume_db` bus utama; kategori lain ke bus kategori).
4. Pada langkah 7 boot, layanan membaca nilai volume dari ConfigService dan menerapkannya; store `safe_mode` atau `deferred` memakai nilai default 1.0 dengan peringatan (mode terdegradasi, CFR-FR-002).

## 4. Kontrak Pemutaran dan Pengelolaan Voice

1. `play(stream, category)`: `stream` adalah `AudioStream` yang telah dimuat oleh pemanggil; kategori hanya kategori pemutaran (`music`, `sfx`, `announcer`); `master` ditolak sebagai kategori pemutaran.
2. Suara aktif dikelola melalui ObjectPool per kategori: satu pool per kategori dengan prewarm sama dengan batas polyphony kategori; node diambil dengan `acquire()` dan dikembalikan dengan `release()` saat `stop` atau selesai diputar (CFR-FR-025).
3. Batas polyphony final (keputusan SP-1): `music` 1, `sfx` 8, `announcer` 2. Permintaan yang melampaui batas ditolak `rejected` dengan alasan pada log; pemanggil memutuskan menghentikan suara mana yang berjalan; layanan tidak melakukan penggantian otomatis dan tidak menumbuhkan pool.
4. `play` mengembalikan `handle` integer unik per sesi; `stop(handle)` menghentikan suara dan mengembalikan node ke pool; handle yang tidak dikenal mengembalikan `unknown_handle`, bukan kegagalan keras (handle boleh telah berakhir karena stream selesai).
5. `pause(category)` dan `resume(category)` bekerja per kategori; `pause_all()` dan `resume_all()` dipanggil AppBootstrap pada notifikasi pause dan resume (CFR-INT-101, CFR-INT-102). Jeda menyimpan daftar handle yang sedang berjalan agar resume memulihkan tepat yang dijeda.

## 5. Perilaku Headless (CFR-FR-026)

1. Saat driver audio tidak tersedia (mode headless CI), layanan memasuki jalur tanpa pembuatan node audio: seluruh API tetap valid; `play` mengembalikan handle dan status `ok`; tidak ada error dan tidak ada pengelolaan node nyata.
2. Deteksi dilakukan sekali saat `initialize`; hasilnya dapat ditanyai sebagai bagian status terdegradasi layanan.

## 6. Penanganan Resource Gagal

`play` dengan stream null, stream bukan `AudioStream`, atau kategori tidak dikenal ditolak `rejected` dengan ERROR; tidak ada suara mulai. Kegagalan pemuatan berkas audio milik pemanggil (pemuatan melalui CoreResourceLoader mengikuti OBJECT-POOL-SPEC); AudioService tidak memuat berkas pada SDD-02.

## 7. Penanganan Kesalahan

| Kegagalan | Kelas | Perlakuan |
| --- | --- | --- |
| Perangkat audio tidak tersedia. | Terdegradasi. | Jalur headless; API valid tanpa error (CFR-FR-026). |
| Stream tidak valid atau kategori tidak dikenal. | Pelanggaran kontrak. | `rejected`; ERROR dan `push_error`. |
| Batas polyphony tercapai. | Terdegradasi. | `rejected` dengan alasan; pemanggil memutuskan. |
| `handle` tidak dikenal pada `stop`. | Data. | `unknown_handle`; tanpa kegagalan keras. |
| Nilai volume di luar rentang. | Pelanggaran kontrak. | `invalid`; tanpa perubahan. |
| Inisialisasi gagal (ConfigService null). | Fatal boot. | `"fatal"` bila dependensi kritis null; AppBootstrap menghentikan boot (langkah 7 sekunder: kegagalan non-null lainnya masuk terdegradasi). |

## 8. Kondisi Normal dan Gagal

Kondisi normal: pemutaran mengambil node dari pool, mengembalikan handle, dan mengembalikan node saat berhenti; volume bertahan antar sesi melalui store `settings` (CFR-AC-006). Kondisi gagal: seluruh baris tabel bagian 7 meninggalkan layanan dapat ditanyai; node pool tidak bocor (setiap penolakan tidak mengambil node).

## 9. Validasi dan Kasus Uji (`core_audio_tests.gd`)

| ID | Kasus | Requirement | Lulus Bila |
| --- | --- | --- | --- |
| AU-01 | Volume per kategori diterapkan dan bertahan. | FR-024, AC-006 | Ubah-simpan-muat ulang mengembalikan nilai; bus menerima nilai. |
| AU-02 | Batas polyphony ditegakkan. | FR-025 | `voice_count` tidak melampaui batas; permintaan ke-9 kategori `sfx` ditolak. |
| AU-03 | Stop mengembalikan node ke pool. | FR-025 | `stock_count` pulih; handle berikutnya memakai node pool. |
| AU-04 | Headless tanpa perangkat audio. | FR-026 | Seluruh API valid tanpa error pada jalur headless. |
| AU-05 | Pause dan resume per kategori dan menyeluruh. | INT-101, INT-102 | Daftar yang dijeda dipulihkan tepat pada resume. |
| AU-06 | Stream tidak valid ditolak. | FR-025 | `rejected`; ERROR tercatat; tidak ada node diambil. |
| AU-07 | `master` ditolak sebagai kategori pemutaran. | FR-024 | `rejected` dengan ERROR. |

## 10. Batasan

1. Tidak ada pencampuran (crossfade) atau pengaturan pitch pada SDD-02; kebutuhan menyusul tahap konten audio (SDD-09, SDD-12).
2. Tidak ada pemuatan berkas audio oleh layanan pada SDD-02; pemanggil memuat stream.
3. Tidak ada penggantian suara otomatis saat batas tercapai; kebijakan penggantian menyusul kebutuhan nyata tahap audio.
4. Nilai polyphony dapat ditinjau pada SDD-12 bersama profil kinerja, melalui proses perubahan keputusan.

## 11. Referensi

- CORE-FRAMEWORK-ARCHITECTURE bagian 3.7; SERVICE-DEPENDENCY-DESIGN tabel 3.2 catatan 1.
- OBJECT-POOL-SPEC bagian 3.1 dan 3.4 (prewarm dan kebijakan pertumbuhan).
- CONFIG-INPUT-LOG-SPEC (jalur pengaturan volume); INITIALIZATION-LIFECYCLE-DESIGN bagian 3.2 langkah 7.
- Keputusan SP-1 (polyphony), disetujui pemilik proyek 2026-10-31.

## 12. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
