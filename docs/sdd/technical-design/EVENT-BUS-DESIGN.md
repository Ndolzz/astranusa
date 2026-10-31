# EVENT-BUS-DESIGN: Desain Event Bus

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement terkait: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Basis audit: HEAD `ec3ccae` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini merancang EventBus: komunikasi publish-subscribe lintas modul yang tervalidasi, dengan dua mode pengiriman dan kebersihan listener yang terjaga. EventBus adalah mekanisme dekoping komunikasi sesuai prinsip arsitektur nomor 4. Ruang lingkup: register event, langganan, pengiriman immediate dan deferred, kebersihan listener, diagnostik, serta pengujian. Kebijakan kapan event dipakai dibanding pemanggilan langsung diatur pada SERVICE-DEPENDENCY-DESIGN bagian 3.4.

## 2. Requirement yang Dilayani

CFR-FR-011 (event tervalidasi), CFR-FR-012 (dua mode pengiriman), CFR-FR-013 (kebersihan listener), CFR-FR-014 (diagnostik event), CFR-FR-031 (tidak ada kegagalan senyap pada listener), CFR-NFR-005 (tanpa alokasi pada jalur menganggur).

## 3. Rancangan Teknis

### 3.1 Register Event

1. Seluruh event dideklarasikan pada satu register terpusat yang dapat diaudit: `core_events.gd` berisi konstanta nama event beserta mode pengiriman dan pemilik modul (CFR-FR-011).
2. Register SDD-02 minimal: `app.paused`, `app.resumed`, `app.ready`, `save.store_written`, `save.migration_completed`, `config.setting_changed`. Lapisan atas menambah event dengan mendaftarkan pada register melalui `register_event(name, mode, owner)` saat inisialisasi modulnya, bukan dengan string liar.
3. `emit` atau `subscribe` pada nama tak terdaftar ditolak dengan error eksplisit dan log ERROR.

### 3.2 Dua Mode Pengiriman (CFR-FR-012)

| Mode | Perilaku | Pemakaian |
| --- | --- | --- |
| Immediate | Listener dipanggil pada saat emit, berurutan sesuai urutan langganan. | Urutan logika yang harus segera konsisten (mis. `config.setting_changed` sebelum pembaca berikutnya). |
| Deferred | Payload dimasukkan ke antrean; seluruh antrean disiram sekali per frame pada `_process` EventBus; listener dipanggil setelah siraman dimulai, tidak seketika. | Penyebaran status yang tidak sensitif urutan (mis. `app.ready`, `save.store_written`). |

Ketentuan deferred: emit yang terjadi di dalam siraman antrean tidak dieksekusi pada siraman berjalan, melainkan menunggu siraman frame berikutnya, sehingga reentrancy dan rekursi lintas modul terputus.

### 3.3 Kebersihan Listener (CFR-FR-013)

1. `subscribe(name, callable)` menyimpan callable beserta referensi pemilik untuk pemeriksaan kehidupan objek; `unsubscribe(name, callable)` tersedia dan idempoten.
2. `unsubscribe_owner(owner)` melepas seluruh langganan milik satu objek; ini jalur utama pelepasan modul dan scene.
3. Listener dengan pemilik yang telah dibebaskan dilewati pada siraman berikutnya dan dicatat sebagai peringatan WARN.
4. Saat penutupan aplikasi, sisa listener aktif dicatat sebagai peringatan (CFR-FR-013); `clear_all()` tersedia untuk pengujian dan menegaskan keadaan kosong.

### 3.4 Diagnostik (CFR-FR-014)

Pada mode pengembangan, emit pada event terdaftar tanpa satu pun listener mencatat INFO dengan nama event, bukan error. Pada rilis dengan tingkat WARN bawaan, catatan ini tidak ditulis (selaras LOGGING-SYSTEM-DESIGN).

### 3.5 Payload dan Validasi

1. Payload dideklarasikan pada register sebagai daftar kunci opsional; emit memeriksa keberadaan kunci wajib; ketidaksesuaian menghasilkan error eksplisit dengan nama event dan kunci yang hilang.
2. Nilai payload tidak disalin mendalam; pemancar tidak mengubah payload setelah emit immediate (konvensi yang ditegakkan pada audit, bukan pada runtime).

### 3.6 Penanganan Kegagalan Listener (CFR-FR-031)

Kegagalan satu listener tidak menghentikan listener lain maupun aplikasi: kesalahan ditangkap pada siraman, dicatat ERROR dengan nama event dan listener, lalu siraman berlanjut ke listener berikutnya. Menelan kesalahan tanpa mencatat dilarang.

## 4. Kontrak Antarmodul

| Antarmuka | Rancangan |
| --- | --- |
| `register_event(name, mode, owner, required_keys)` | Menambah event terdaftar; dipanggil saat inisialisasi modul. |
| `subscribe(name, callable)` | Berlangganan; gagal bila nama tak terdaftar. |
| `unsubscribe(name, callable)` | Melepas satu langganan; idempoten. |
| `unsubscribe_owner(owner)` | Melepas seluruh langganan satu pemilik. |
| `emit(name, payload)` | Immediate atau deferred sesuai mode register. |
| `flush_deferred()` | Menyiram antrean; dipanggil per frame dan dapat dipanggil pengujian. |
| `clear_all()` | Pelepasan menyeluruh untuk pengujian. |

Ketergantungan EventBus hanya pada LogService (SERVICE-DEPENDENCY-DESIGN tabel 3.2); EventBus tidak berlangganan ke layanan mana pun.

## 5. Penanganan Kesalahan

| Kegagalan | Perlakuan |
| --- | --- |
| Nama event tak terdaftar pada emit atau subscribe. | Error eksplisit; operasi ditolak; log ERROR. |
| Payload tanpa kunci wajib. | Emit ditolak; log ERROR dengan rincian. |
| Listener melempar kesalahan. | Dicatat ERROR; siraman berlanjut (bagian 3.6). |
| Listener mati (pemilik dibebaskan). | Dilewati; WARN; sisa listener dilaporkan saat penutupan. |

## 6. Pertimbangan Performa

1. Jalur menganggur: tanpa event deferred tertunda, `_process` hanya memeriksa ukuran antrean (pemeriksaan integer; tanpa alokasi) sehingga memenuhi CFR-NFR-005.
2. Siraman antrean memakai wadah yang digunakan ulang; indeks siraman tidak mengalokasikan struktur baru per frame.
3. Immediate emit memanggil callable langsung; tidak ada penyalinan payload; biaya per emit sebanding pemanggilan fungsi.

## 7. Alternatif yang Dipertimbangkan

| Alternatif | Kelebihan | Keburangan | Alasan Tidak Dipilih |
| --- | --- | --- | --- |
| Signal Godot murni tanpa event bus. | Tanpa kode tambahan. | Daftar signal menyebar antar skrip; tidak ada register tunggal yang dapat diaudit; mode deferred harus dibangun tiap pemakai. | Melanggar CFR-FR-011 dan prinsip dekoping arsitektur nomor 4. |
| Event bus tanpa mode immediate (semua deferred). | Aturan tunggal. | Urutan logika yang harus segera konsisten terpaksa menunggu frame; kesalahan urutan sulit direproduksi. | Melanggar CFR-FR-012. |
| Event bertipe penuh dengan kelas event per nama. | Type safety. | Banyak kelas kecil; biaya konsistensi dengan register; GDScript tidak memberi keuntungan penuh. | Register dengan payload tervalidasi memadai untuk tahap ini. |

## 8. Risiko Teknis dan Mitigasi

| Risiko | Kemungkinan | Dampak | Mitigasi |
| --- | --- | --- | --- |
| Listener tertinggal menyebabkan kebocoran. | Sedang | Sedang | API `unsubscribe_owner`; peringatan penutupan; suite kebersihan listener (FR-013). |
| Urutan immediate listener implisit dimanfaatkan sebagai kontrak. | Sedang | Sedang | Konvensi: immediate tidak menjamin urutan lintas modul; kebutuhan urutan dinyatakan eksplisit pada rancangan pemakai. |
| Penyalahgunaan event untuk kueri (mengembalikan nilai). | Sedang | Sedang | Kebijakan komunikasi SERVICE-DEPENDENCY-DESIGN 3.4; audit menolak emit-kemudian-tunggu-pola balasan. |

## 9. Strategi Pengujian

`core_event_bus_tests.gd`: registrasi dan penolakan nama liar (FR-011), urutan immediate dan deferred serta pemutusan reentrancy (FR-012), daur hidup listener termasuk peringatan sisa (FR-013), diagnostik tanpa listener (FR-014), kesalahan listener tidak menelan (bagian 3.6). Seluruh pengujian headless tanpa scene.

## 10. Kriteria Penerimaan Desain

1. Register tunggal dan penolakan nama liar teruji (FR-011).
2. Dua mode pengiriman berperilaku sesuai spesifikasi dan teruji (FR-012).
3. Kebersihan listener dan peringatan penutupan teruji (FR-013).
4. Jalur menganggur tanpa alokasi (NFR-005) dinyatakan dan diperiksa pada audit.
5. Pemilik proyek menyetujui sebelum tahap Specification.

## 11. Referensi

- CORE-FRAMEWORK-REQUIREMENTS bagian 5.4, 8, 13, 15
- TECHNICAL_ARCHITECTURE bagian 3 (komunikasi antarmodul)
- SERVICE-DEPENDENCY-DESIGN bagian 3.4 (kebijakan komunikasi)
- LOGGING-SYSTEM-DESIGN (tingkat dan format catatan)

## 12. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
