# SERVICE-API-SPEC: Katalog Antarmuka Layanan Core Framework

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Dokumen desain: CORE-FRAMEWORK-ARCHITECTURE bagian 4 (kontrak rancangan) dan SERVICE-DEPENDENCY-DESIGN (tabel izin 3.2)
- Basis audit: HEAD `aa636633` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini adalah katalog tunggal tanda tangan antarmuka final seluruh layanan dan pustaka murni Core Framework. Setiap tanda tangan dicantumkan tepat satu kali pada dokumen ini; dokumen spesifikasi modul merinci semantik, validasi, penanganan kesalahan, dan kasus uji tanpa mengulang tabel tanda tangan. Konvensi pelaporan kesalahan mengikuti CORE-FRAMEWORK-IMPLEMENTATION-SPEC bagian 5: operasi yang dapat gagal secara operasional mengembalikan status; pelanggaran kontrak ditolak dengan ERROR dan `push_error`.

Ketentuan tipe: GDScript dinamis, namun tanda tangan pada dokumen ini mengikat tipe yang dinyatakan. `Dictionary` hasil memuat kunci `status` bertipe String dengan konstanta yang tercantum. Nama parameter pada dokumen ini adalah nama final.

## 2. AppBootstrap (Autoload)

| Tanda Tangan | Prasyarat | Kembalian | Efek Samping dan Kegagalan |
| --- | --- | --- | --- |
| `initialize() -> Dictionary` | Autoload aktif (langkah 1). | `{"status": "ready"\|"fatal", "degraded": Array[String], "boot_ms": int}` | Menjalankan langkah 2 s.d. 10 sesuai urutan; `"fatal"` menghentikan boot dengan pesan pemain; layanan sekunder gagal masuk `degraded` tanpa menghentikan boot (CFR-FR-001, CFR-FR-002). |
| `is_ready() -> bool` | - | `true` bila status aplikasi READY. | Tanpa efek samping. |
| `degraded_services() -> Array[String]` | - | Nama layanan mode terdegradasi. | Tanpa efek samping. |
| `current_app_state() -> String` | - | `"BOOT"` atau `"READY"`. | Kueri AppState. |
| `request_shutdown() -> void` | - | - | Menjalankan prosedur penutupan normal (CFR-FR-003). |
| `handle_pause() -> void` | - | - | Berhenti sementara audio, menonaktifkan pembacaan input, menyiram antrean tulis dan buffer log (CFR-INT-101). Dapat dipanggil pengujian langsung. |
| `handle_resume() -> void` | - | - | Memulihkan audio dan input (CFR-INT-102). |
| `handle_close_request() -> void` | - | - | Sama dengan `request_shutdown()` (CFR-INT-104). |

Konstanta status: `BOOT_READY = "ready"`, `BOOT_FATAL = "fatal"`. Tidak ada modul lain yang mengekspos seluruh layanan; akses layanan tetap melalui nama autoload masing-masing.

## 3. LogService (Autoload)

| Tanda Tangan | Prasyarat | Kembalian | Efek Samping dan Kegagalan |
| --- | --- | --- | --- |
| `initialize(logs_dir: String, base_level: String) -> Dictionary` | Autoload aktif. | `{"status": "ok"\|"fatal"}` | Membuat `user://logs/` dan berkas aktif. `"fatal"` menghentikan boot (layanan kritis, CFR-FR-002). |
| `debug(module: String, message: String) -> void` | - | - | Menambah baris DEBUG ke buffer bila lolos penyaringan tingkat. Tanpa I/O. |
| `info(module: String, message: String) -> void` | `info`/`warn`/`error` sepadan. | - | Sebagaimana `debug` dengan tingkat masing-masing. |
| `warn(module: String, message: String) -> void` | - | - | - |
| `error(module: String, message: String) -> void` | - | - | Tingkat ERROR selalu lolos penyaringan. |
| `set_level(level: String) -> void` | `level` salah satu `"DEBUG"`, `"INFO"`, `"WARN"`, `"ERROR"`. | - | Mengubah tingkat aktif. Nilai tidak sah: ditolak dengan ERROR dan `push_error`. |
| `current_level() -> String` | - | Tingkat aktif. | Kueri pengujian. |
| `flush() -> Dictionary` | - | `{"status": "ok"\|"fileless"|"error", "rotated": bool}` | Menyiram buffer ke berkas; dipanggil pada pause, penutupan, batas buffer, dan pengujian. |
| `file_mode_status() -> String` | - | `"ok"\|"fileless"` | Kueri mode setelah kegagalan penulisan. |

## 4. EventBus (Autoload)

| Tanda Tangan | Prasyarat | Kembalian | Efek Samping dan Kegagalan |
| --- | --- | --- | --- |
| `register_event(name: String, mode: String, owner: String, required_keys: Array[String]) -> Dictionary` | LogService siap. | `{"status": "ok"\|"duplicate"}` | Menambah register. `mode` salah satu `"immediate"`, `"deferred"`; nilai tidak sah ditolak dengan ERROR dan `push_error` (CFR-FR-011). |
| `subscribe(name: String, listener: Callable, owner: Object) -> Dictionary` | Event terdaftar. | `{"status": "ok"\|"unknown_event"}` | Menyimpan listener beserta pemilik. Event tak terdaftar ditolak (CFR-FR-011). |
| `unsubscribe(name: String, listener: Callable) -> void` | - | - | Idempoten; tidak ada efek bila tidak ditemukan (CFR-FR-013). |
| `unsubscribe_owner(owner: Object) -> int` | - | Jumlah langganan dilepas. | Jalur utama pelepasan modul dan scene. |
| `emit(name: String, payload: Dictionary) -> Dictionary` | Event terdaftar. | `{"status": "ok"\|"unknown_event"\|"invalid_payload"}` | Immediate: listener dipanggil saat emit. Deferred: masuk antrean dan disiram frame berikutnya. Kunci wajib hilang ditolak (CFR-FR-012). |
| `flush_deferred() -> int` | - | Jumlah event tersiram. | Menyiram antrean sekali; dipanggil `_process` per frame dan pengujian. Emit di dalam siraman menunggu siraman berikutnya. |
| `clear_all() -> void` | - | - | Pelepasan menyeluruh untuk pengujian; sisa listener saat penutupan dicatat sebagai peringatan (CFR-FR-013). |

Daftar event final SDD-02 pada EVENT-BUS-SPEC. EventBus tidak berlangganan ke layanan mana pun.

## 5. ConfigService (Autoload)

| Tanda Tangan | Prasyarat | Kembalian | Efek Samping dan Kegagalan |
| --- | --- | --- | --- |
| `initialize(logger: Node) -> Dictionary` | LogService siap. | `{"status": "ok"\|"fatal"}` | Langkah 3: memuat nilai default bawaan ke memori. `"fatal"` menghentikan boot (dasar kritis, CFR-FR-002). |
| `apply_player_settings() -> Dictionary` | SaveService siap. | `{"status": "ok"\|"degraded", "applied": int}` | Langkah 6: menerapkan pengaturan pemain dari store `settings`. Store `safe_mode` atau `deferred`: nilai default dengan peringatan, status `"degraded"`. |
| `load_config(file_name: String) -> Dictionary` | - | `{"status": "ok"\|"invalid"\|"missing_base", "data": Dictionary}` | Pemuatan bertingkat `res://config/<file_name>` dengan penimpa `user://assets_override/<file_name>`; penimpa rusak diabaikan dengan peringatan (CFR-FR-015); data tidak valid ditolak eksplisit (CFR-FR-016). |
| `get_setting(key: String, default: Variant) -> Variant` | - | Nilai pengaturan atau default. | Kunci tak dikenal pada berkas memakai nilai default dengan peringatan sekali per kunci (CFR-FR-018). |
| `set_setting(key: String, value: Variant) -> Dictionary` | - | `{"status": "ok"}` | Menulis memori, mengantrekan tulis store `settings` melalui SaveService, memancarkan signal (CFR-FR-017). |
| Signal `setting_changed(key: String, value: Variant)` | - | - | Dipancarkan setelah nilai memori diperbarui. |

## 6. SaveService (Autoload)

| Tanda Tangan | Prasyarat | Kembalian | Efek Samping dan Kegagalan |
| --- | --- | --- | --- |
| `initialize(logger: Node, space_probe: SaveSpaceProbe, app_version: String) -> Dictionary` | LogService siap. | `{"status": "ok"\|"fatal"}` | Langkah 5: bersihkan `user://tmp/`, jurnal dan pemulihan, migrasi, muat store, titik sedia manifest. `"fatal"` menghentikan boot (CFR-FR-002). |
| `get_store(name: String) -> Dictionary` | Store dimuat. | Salinan data store. | Store `safe_mode` mengembalikan nilai default; salinan mencegah modifikasi tanpa antrean. |
| `update_store(name: String, mutator: Callable) -> Dictionary` | Store dimuat. | `{"status": "ok"\|"safe_mode"\|"unknown_store"}` | Memanggil mutator atas data di memori lalu mengantrekan penulisan. Mutasi pada store `safe_mode` ditolak untuk penulisan namun boleh membaca. |
| `queue_write(name: String) -> Dictionary` | - | `{"status": "ok"\|"deferred"\|"error"}` | Momen simpan eksplisit (CFR-FR-021). `"deferred"` bila ruang tidak cukup. |
| `flush() -> Dictionary` | - | `{"status": "ok"\|"partial", "written": Array[String], "deferred": Array[String]}` | Menyiram antrean tulis; dipanggil momen aman, pause, penutupan, pengujian. |
| `store_status(name: String) -> String` | - | `"ok"\|"recovered"\|"safe_mode"\|"deferred"\|"error"` | Kueri status per store (CFR-FR-023). |
| `register_migration(store: String, from_version: int, to_version: int, step: Callable) -> Dictionary` | Sebelum boot. | `{"status": "ok"\|"duplicate"\|"invalid"}` | Mendaftarkan langkah rantai; `step` fungsi murni. Kenaikan selalu satu tingkat. |
| `free_space_report() -> Dictionary` | - | `{"status": "ok"\|"unknown"\|"insufficient", "bytes_free": int, "bytes_required": int}` | Hasil pemeriksaan ruang terakhir (CFR-FR-022). |

## 7. AudioService (Autoload)

| Tanda Tangan | Prasyarat | Kembalian | Efek Samping dan Kegagalan |
| --- | --- | --- | --- |
| `initialize(logger: Node, config: ConfigService) -> Dictionary` | Langkah 6 selesai. | `{"status": "ok"\|"degraded"\|"fatal"}` | Langkah 7: menerapkan volume tersimpan melalui nilai hasil ConfigService. Perangkat audio tidak tersedia (headless): `"degraded"` jalur tanpa node, API tetap valid (CFR-FR-026). |
| `play(stream: AudioStream, category: String) -> Dictionary` | - | `{"status": "ok"\|"rejected"\|"error", "handle": int}` | Mengambil node dari pool; batas polyphony tercapai atau stream tidak valid: `"rejected"` dengan alasan pada log (CFR-FR-025). |
| `stop(handle: int) -> Dictionary` | - | `{"status": "ok"\|"unknown_handle"}` | Menghentikan satu suara dan mengembalikan node ke pool. |
| `pause(category: String) -> void` | - | - | Menghentikan sementara seluruh suara satu kategori. |
| `resume(category: String) -> void` | - | - | Memulihkan kategori yang dijeda. |
| `pause_all() -> void` | - | - | Dipanggil AppBootstrap pada pause (CFR-INT-101). |
| `resume_all() -> void` | - | - | Dipanggil AppBootstrap pada resume (CFR-INT-102). |
| `set_volume(category: String, value: float) -> Dictionary` | `value` 0.0 s.d. 1.0. | `{"status": "ok"\|"invalid"}` | Menerapkan ke bus audio dan menulis melalui ConfigService (`audio/<kategori>`), bukan langsung ke SaveService (CFR-FR-024). |
| `voice_count(category: String) -> int` | - | Jumlah suara aktif. | Diagnostik pengujian batas polyphony. |

## 8. InputService (Autoload)

| Tanda Tangan | Prasyarat | Kembalian | Efek Samping dan Kegagalan |
| --- | --- | --- | --- |
| `initialize(action_config: Dictionary, logger: Node) -> Dictionary` | LogService siap. | `{"status": "ok"\|"degraded", "actions": int}` | Langkah 8: mendaftarkan action map ke `InputMap`. Pada SDD-02, `action_config` berasal dari data bawaan internal (keputusan SP-6); berkas konfigurasi menjadi sumber sejak SDD-03 tanpa perubahan antarmuka. Data tidak sah: `"degraded"` tanpa aksi (CFR-FR-002). |
| `is_action_pressed(action: String) -> bool` | - | Status aksi. | Saat pause mengembalikan `false` (CFR-INT-101). Aksi tak terdaftar: `false` dengan WARN sekali per aksi per sesi. |
| `is_action_just_pressed(action: String) -> bool` | - | Status tepi naik. | Sebagaimana di atas. |
| `is_action_just_released(action: String) -> bool` | - | Status tepi turun. | Sebagaimana di atas. |
| `get_axis(negative_action: String, positive_action: String) -> float` | - | Nilai poros. | Sebagaimana di atas. |
| `inject_press(action: String, strength: float) -> Dictionary` | Mode pengujian aktif. | `{"status": "ok"\|"unknown_action"\|"rejected"}` | Injeksi input sintetis; prioritas di atas keadaan engine (CFR-FR-028). Aksi tak terdaftar ditolak. |
| `inject_release(action: String) -> Dictionary` | Mode pengujian aktif. | `{"status": "ok"\|"unknown_action"}` | Mengakhiri satu injeksi. |
| `clear_injections() -> void` | - | - | Membersihkan seluruh injeksi; otomatis pada awal suite. |
| `set_paused(paused: bool) -> void` | - | - | Dipanggil AppBootstrap pada pause dan resume. |
| `registered_actions() -> Array[String]` | - | Daftar aksi terdaftar. | Diagnostik. |

## 9. SceneRouter (Autoload)

| Tanda Tangan | Prasyarat | Kembalian | Efek Samping dan Kegagalan |
| --- | --- | --- | --- |
| `initialize(logger: Node, event_bus: EventBus, app_state: AppState, loader: CoreResourceLoader) -> Dictionary` | Langkah 2 s.d. 8 selesai. | `{"status": "ok"\|"fatal"}` | Langkah 9: scene aktif (boot SDD-01) dinyatakan route awal. |
| `register_route(name: String, scene_path: String) -> Dictionary` | - | `{"status": "ok"\|"duplicate"\|"invalid"}` | Menambah registry route. Nama ganda atau path kosong ditolak. |
| `go_to(route: String, timeout_ms: int, progress_cb: Callable) -> Dictionary` | Route terdaftar; tidak ada transisi berjalan. | `{"status": "ok"\|"unknown_route"\|"busy"\|"timeout"\|"load_failed", "progress": float}` | Menjalankan siklus transisi. `timeout_ms` bawaan 10000 (SP-5). Permintaan saat transisi berjalan ditolak `"busy"` (SP-4). Route tak terdaftar ditolak eksplisit (CFR-FR-005). |
| `release_previous() -> Dictionary` | - | `{"status": "ok"\|"no_previous"}` | Titik pembersihan eksplisit scene lama (CFR-FR-007). |
| `transition_history() -> Array[Dictionary]` | - | Riwayat transisi. | Rekaman headless untuk asersi pengujian (CFR-FR-008). |
| `current_route() -> String` | - | Route aktif. | Kueri. |

## 10. Pustaka Murni

### 10.1 StateMachine (`class_name StateMachine`, RefCounted)

| Tanda Tangan | Kembalian | Kegagalan |
| --- | --- | --- |
| `StateMachine.new(logger: Node = null)` | Instansi. | Logger null diizinkan; penolakan hanya dicatat bila logger tersedia. |
| `add_state(name: String) -> Dictionary` | `{"status": "ok"\|"duplicate"}` | Nama ganda ditolak. |
| `add_transition(from: String, to: String, guard: Callable) -> Dictionary` | `{"status": "ok"\|"unknown_state"}` | State tak dikenal ditolak; `guard` boleh `Callable()` kosong (selalu lulus). Guard menerima Dictionary payload opsional. |
| `transition_to(name: String, payload: Dictionary = {}) -> Dictionary` | `{"status": "ok"\|"unknown_state"\|"rejected", "old": String, "new": String}` | Transisi tidak terdaftar atau guard gagal: ditolak tanpa efek samping, log WARN (CFR-FR-009). Payload diteruskan ke guard dan tidak disimpan. |
| `current() -> String` | State aktif. | - |
| Signal `state_changed(old: String, new: String)` | - | Dipancarkan setelah transisi berhasil. |

### 10.2 AppState (`class_name AppState`, RefCounted)

| Tanda Tangan | Kembalian | Kegagalan |
| --- | --- | --- |
| `AppState.new(logger: Node = null)` | Instansi dengan state `BOOT` dan `READY` terdaftar. | - |
| `current_state() -> String` | `"BOOT"` atau `"READY"`. | - |
| `is_in_state(name: String) -> bool` | Kueri. | - |
| `mark_ready() -> Dictionary` | `{"status": "ok"\|"rejected"}` | Satu-satunya transksi sah SDD-02 adalah `BOOT` ke `READY`; dipanggil AppBootstrap langkah 10. Transisi lain ditolak; state `LOBBY`, `MATCH`, `RESULT` didaftarkan tahap masing-masing tanpa mengubah pustaka. |
| Signal `state_changed(old: String, new: String)` | - | Diteruskan dari StateMachine internal. |

### 10.3 ObjectPool (`class_name ObjectPool`, RefCounted)

| Tanda Tangan | Kembalian | Kegagalan |
| --- | --- | --- |
| `ObjectPool.new(logger: Node = null)` | Instansi. | - |
| `setup(factory: Callable, reset: Callable, prewarm: int) -> Dictionary` | `{"status": "ok"\|"invalid"}` | `prewarm` negatif atau callable tidak sah ditolak. Alokasi prewarm terjadi di sini, di luar jalur per-frame (CFR-FR-032, SP-3). |
| `acquire() -> Variant` | Objek dari stok, atau `null`. | `null` berarti stok habis; pemanggil memutuskan `grow(n)` eksplisit atau menolak operasi; tidak ada alokasi implisit. |
| `release(obj: Variant) -> Dictionary` | `{"status": "ok"\|"double_release"\|"foreign"}` | Pelepasan dua kali atau objek bukan milik pool ditolak dengan ERROR dan `push_error`. |
| `grow(n: int) -> Dictionary` | `{"status": "ok"\|"rejected", "added": int}` | Pertumbuhan eksplisit; `n` tidak positif ditolak. |
| `clear() -> void` | - | Pengujian. |
| `active_count() -> int`, `stock_count() -> int` | Diagnostik. | - |

### 10.4 CoreResourceLoader (`class_name CoreResourceLoader`, RefCounted)

| Tanda Tangan | Kembalian | Kegagalan |
| --- | --- | --- |
| `CoreResourceLoader.new(logger: Node = null, time_source: Callable = Callable())` | Instansi. | `time_source` suntikan pengujian batas waktu; kosong memakai `Time.get_ticks_msec()`. |
| `request(path: String, timeout_ms: int) -> Dictionary` | `{"status": "ok"\|"error", "request_id": int}` | Memulai `ResourceLoader.load_threaded_request`; path tidak dapat diminta mengembalikan `"error"` (CFR-FR-034). |
| `poll(request_id: int) -> Dictionary` | `{"status": "loading"\|"done"\|"timeout"\|"error", "progress": float, "resource": Resource}` | Diperiksa per frame selama transisi; melewati `timeout_ms` (bawaan 10000, SP-5) mengembalikan `"timeout"` eksplisit; tidak pernah menggantung. |
| `load_sync(path: String) -> Dictionary` | `{"status": "ok"\|"error", "resource": Resource}` | Pemuatan sinkron di luar jalur per-frame; kegagalan eksplisit. |

### 10.5 Kelas Internal SaveService

SaveStore, SaveMigration, dan SaveSpaceProbe diinternalisasi di balik antarmuka SaveService dan dirinci pada SAVE-SERVICE-IMPLEMENTATION-SPEC; kelas-kelas tersebut dapat diinstansiasi langsung oleh pengujian dan skrip `--migrate-only` (tanpa autoload).

## 11. Aturan Penyuntikan dan Ketergantungan

1. Layanan autoload menerima dependensi eksplisit pada `initialize()` sesuai tabel izin SERVICE-DEPENDENCY-DESIGN 3.2; tidak ada layanan yang mengambil referensi layanan lain secara mandiri pada kode internalnya.
2. Pustaka murni menerima dependensi melalui parameter konstruksi; logger null diizinkan; pustaka tidak memegang referensi autoload.
3. `AudioService` menerima `ConfigService` dan membaca serta menulis volume hanya melalui ConfigService; tidak memanggil SaveService langsung.
4. `SceneRouter` menerima `EventBus` untuk memancarkan status transisi dan `AppState` untuk konsistensi status-route; tidak bergantung pada SaveService dan ConfigService.
5. Pemanggilan lintas layanan di luar tabel izin adalah pelanggaran kontrak: ditolak pada audit kode.

## 12. Acceptance Criteria Dokumen

- [ ] Setiap tanda tangan pada dokumen ini konsisten dengan dokumen modul dan tabel izin ketergantungan.
- [ ] Setiap operasi yang dapat gagal memiliki status kembalian terdefinisi; setiap kelas kegagalan memiliki perlakuan yang ditetapkan.
- [ ] Tidak ada antarmuka yang menambah fitur gameplay di luar ruang lingkup Core Framework.

## 13. Referensi

- CORE-FRAMEWORK-ARCHITECTURE bagian 4; SERVICE-DEPENDENCY-DESIGN bagian 3.2 dan 3.3.
- CORE-FRAMEWORK-IMPLEMENTATION-SPEC bagian 5 (konvensi pelaporan kesalahan) dan bagian 6 (kebijakan alokasi).
- Dokumen spesifikasi modul: EVENT-BUS-SPEC, STATE-MANAGEMENT-SPEC, OBJECT-POOL-SPEC, SCENE-ROUTER-SPEC, SAVE-SERVICE-IMPLEMENTATION-SPEC, AUDIO-SERVICE-SPEC, CONFIG-INPUT-LOG-SPEC.
- CORE-FRAMEWORK-REQUIREMENTS bagian 7, 8, 15.

## 14. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
