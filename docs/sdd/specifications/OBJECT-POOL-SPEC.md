# OBJECT-POOL-SPEC: Spesifikasi Object Pool dan Pemuat Resource

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Dokumen desain: CORE-FRAMEWORK-ARCHITECTURE bagian 3.8 (Approved, 2026-10-31)
- Basis audit: HEAD `aa636633` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini menetapkan kontrak final ObjectPool generik dan CoreResourceLoader, serta nilai prewarm dan kebijakan pertumbuhan pool. Tanda tangan antarmuka berada pada SERVICE-API-SPEC bagian 10.3 dan 10.4. Kedua kelas adalah pustaka murni tanpa referensi autoload; logger disuntik dan boleh null.

## 2. Requirement Terkait

CFR-FR-032 (object pool generik), CFR-FR-033 (kebijakan alokasi per-frame), CFR-FR-034 (pemuatan resource terjadwal), CFR-NFR-005 (tanpa alokasi pada jalur menganggur), CFR-INT-005 (penetapan kebijakan alokasi pada spesifikasi SDD-02).

## 3. Kontrak ObjectPool

### 3.1 Setup dan Prewarm

1. `setup(factory, reset, prewarm)` wajib dipanggil sekali sebelum operasi; pemanggilan operasional sebelum setup ditolak sebagai pelanggaran kontrak.
2. `factory: Callable -> Variant` membuat objek baru; `reset: Callable(obj) -> void` mengembalikan objek ke keadaan netral saat dilepas.
3. Prewarm mengalokasikan `prewarm` objek sekaligus di luar jalur per-frame; nilai prewarm ditetapkan oleh pemilik pool. Prewarm SDD-02: AudioService membuat satu pool per kategori pemutaran dengan prewarm sama dengan batas polyphony kategori (music 1, sfx 8, announcer 2, sesuai keputusan SP-1 dan AUDIO-SERVICE-SPEC).

### 3.2 Acquire dan Release

1. `acquire()` mengembalikan objek dari stok dalam urutan LIFO (objek terakhir dilepas adalah yang pertama diambil, memaksimalkan kehangatan cache) dan menandai objek aktif.
2. Stok habis: `acquire()` mengembalikan `null` tanpa alokasi apa pun; pemanggil memutuskan `grow(n)` eksplisit atau menolak operasi (CFR-FR-032; CORE-FRAMEWORK-IMPLEMENTATION-SPEC bagian 6 nomor 3).
3. `release(obj)` memanggil `reset(obj)` lalu mengembalikan objek ke stok dan menghapus tanda aktif. Objek yang tidak dikenal (bukan hasil `acquire` dari pool ini) ditolak `foreign`; objek yang sudah berada di stok ditolak `double_release`; keduanya ERROR dan `push_error`, tanpa menimbulkan keadaan ganda pada stok.

### 3.3 Kepemilikan dan Siklus Hidup

1. Selama aktif, objek dipinjamkan kepada pemanggil; pool tetap pemilik tunggal referensi stok. Pemanggil tidak boleh menyimpan referensi objek setelah `release`; pelanggaran ditemukan pada audit (referensi menggantung adalah tanggung jawab pemanggil).
2. `clear()` membuang seluruh stok (dipanggil pengujian dan penutupan AudioService pada penutupan normal); objek aktif yang belum dilepas saat `clear()` dicatat WARN dan tidak dikembalikan ke stok.
3. `active_count()` dan `stock_count()` adalah kueri diagnostik tanpa efek samping.

### 3.4 Kebijakan Pertumbuhan

1. Pertumbuhan hanya eksplisit melalui `grow(n)` dengan `n` positif; `grow` mengalokasikan di luar jalur per-frame sensitif dan dicatat INFO pada log.
2. Pada SDD-02, AudioService tidak menumbuhkan pool: permintaan melampaui batas polyphony ditolak (AUDIO-SERVICE-SPEC); kebijakan pertumbuhan runtime dievaluasi ulang pada tahap yang memiliki data pengukuran.
3. Tidak ada penyusutan otomatis; stok maksimum tidak dibatasi kode, dibatasi disiplin pemanggil.

## 4. Kontrak CoreResourceLoader

### 4.1 Permintaan dan Batas Waktu

1. `request(path, timeout_ms)` membungkus `ResourceLoader.load_threaded_request`; kegagalan permintaan (path tidak ada, tidak dapat dibaca) mengembalikan `{"status": "error"}` seketika tanpa permintaan berjalan.
2. `poll(request_id)` memeriksa `load_threaded_get_status` dan kemajuan; hasil `loading` berarti masih berjalan; `done` mengembalikan resource; `error` adalah kegagalan pemuatan; `timeout` tercapai bila `time_source()` melampaui `timeout_ms` sejak permintaan (bawaan 10000 ms sesuai keputusan SP-5).
3. Batas waktu ditegakkan dengan pemeriksaan pada setiap `poll`, bukan utas terpisah; permintaan kedaluwarsa tidak membatalkan utas pemuatan engine, namun tidak pernah lagi mengembalikan hasil: statusnya tetap `timeout` hingga dihapus, dan hasil yang mungkin datang kemudian diabaikan.
4. `time_source` suntikan mengembalikan milidetik integer; suntikan memungkinkan pengujian batas waktu tanpa tidur nyata (requirement bagian 15 nomor 2).

### 4.2 Pemuatan Sinkron

`load_sync(path)` tersedia untuk konteks di luar jalur per-frame (pengujian, alat headless); kegagalan mengembalikan `error` eksplisit; tidak dipakai SceneRouter pada jalur transisi.

### 4.3 Kepemilikan Hasil

Resource yang berhasil dimuat dipegang pemanggil; CoreResourceLoader hanya menyimpan peta permintaan berjalan yang dibersihkan setelah `done`, `timeout`, atau `error`.

## 5. Penanganan Kesalahan

| Kegagalan | Kelas | Perlakuan |
| --- | --- | --- |
| Operasi sebelum `setup`. | Pelanggaran kontrak. | Ditolak; ERROR dan `push_error`. |
| `acquire` saat stok habis. | Terdegradasi. | `null`; tanpa alokasi; keputusan pada pemanggil. |
| `release` objek asing atau ganda. | Pelanggaran kontrak. | `foreign`/`double_release`; ERROR dan `push_error`. |
| `grow` dengan nilai tidak positif. | Pelanggaran kontrak. | `rejected`; ERROR. |
| `request` path tidak dapat diminta. | Data. | `error` eksplisit dengan path pada log. |
| `poll` melewati batas waktu. | Data. | `timeout` eksplisit; pemanggil menentukan kebijakan lanjutan (CFR-FR-034). |
| `poll` pada permintaan tidak dikenal. | Pelanggaran kontrak. | `error`; ERROR dan `push_error`. |

## 6. Kondisi Normal dan Gagal

Kondisi normal: acquire berturut-turut dalam stok tidak memicu alokasi baru (identitas objek berasal dari prewarm); release mengembalikan objek netral ke stok; pemuatan selesai `done` sebelum batas waktu. Kondisi gagal: seluruh baris tabel bagian 5 meninggalkan pool dan loader dalam keadaan konsisten dan dapat ditanyai; tidak ada keadaan objek ganda pada stok.

## 7. Validasi dan Kasus Uji (`core_pool_tests.gd`)

| ID | Kasus | Requirement | Lulus Bila |
| --- | --- | --- | --- |
| OP-01 | Prewarm mengisi stok sesuai jumlah. | FR-032 | `stock_count() == prewarm`; `active_count() == 0`. |
| OP-02 | Acquire berturut-turut tidak mengalokasikan objek baru. | FR-032, FR-033 | Objek yang dikembalikan selalu anggota himpunan prewarm. |
| OP-03 | Acquire pada stok habis mengembalikan null. | FR-032 | `null` tanpa perubahan jumlah. |
| OP-04 | Release memanggil reset dan mengembalikan ke stok. | FR-032 | Objek netral; `stock_count` naik satu. |
| OP-05 | Double release dan objek asing ditolak. | FR-032 | `double_release`/`foreign`; stok tidak berubah. |
| OP-06 | Grow eksplisit menambah stok. | FR-033 | `added == n`; tercatat INFO. |
| OP-07 | Suite berjalan tanpa autoload aktif. | Bagian 15 req. nomor 1 | Suite hijau tanpa layanan. |
| RL-01 | Request dan poll hingga done. | FR-034 | Resource valid dikembalikan; progres meningkat. |
| RL-02 | Batas waktu tercapai mengembalikan timeout eksplisit. | FR-034 | `timeout` dengan `time_source` suntik; tidak menunggu tanpa batas. |
| RL-03 | Path tidak dapat dimuat mengembalikan error eksplisit. | FR-034 | `error` dengan path pada pesan. |
| RL-04 | Poll pada permintaan selesai tetap konsisten. | FR-034 | Permintaan selesai tidak berubah status. |

## 8. Batasan

1. Pool tidak generik terhadap tipe: satu instansi pool melayani satu bentuk objek dari satu factory; validasi tipe adalah tanggung jawab factory dan pemanggil.
2. Tidak ada statistik alokasi runtime; bukti bebas alokasi diperoleh lewat kasus uji identitas objek dan audit.
3. CoreResourceLoader tidak menyediakan pembatalan utas engine; penanganan kedaluwarsa mengikuti bagian 4.1 nomor 3.

## 9. Referensi

- CORE-FRAMEWORK-ARCHITECTURE bagian 3.8 dan bagian 6 (kebijakan alokasi).
- CORE-FRAMEWORK-IMPLEMENTATION-SPEC bagian 6 (kebijakan alokasi objek pada loop utama).
- AUDIO-SERVICE-SPEC (prewarm pool per kategori); SCENE-ROUTER-SPEC (pemakaian loader pada transisi).
- GODOT-CONFIGURATION-SPEC bagian 5 nomor 3 (mandat kebijakan).

## 10. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
