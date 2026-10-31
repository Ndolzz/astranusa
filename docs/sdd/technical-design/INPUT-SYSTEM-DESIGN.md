# INPUT-SYSTEM-DESIGN: Desain Sistem Input

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement terkait: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Basis audit: HEAD `ec3ccae` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini merancang InputService sebagai façade minimal berbasis action map Godot dengan dukungan input sintetis untuk pengujian headless. Desain ini menetapkan pilihan OJ-3: façade minimal pada SDD-02, dengan perluasan ke butuh pertandingan menyusul pada SDD-05 (disetujui pemilik proyek 2026-10-31, usulan P-021). Ruang lingkup: pembacaan status aksi, pendaftaran action map data-driven, injeksi input sintetis, dan aturan audit pembacaan input pada lapisan app dan core. Kontrol pertandingan (skema kontrol sentuh final, joystick virtual, tombol keterampilan) berada di luar lingkup dan dirancang pada SDD-05; kontrol antarmuka lobby SDD-04 tetap memakai mekanisme Control bawaan Godot.

## 2. Requirement yang Dilayani

CFR-FR-027 (façade input terpusat; prioritas Should), CFR-FR-028 (input sintetis untuk pengujian; prioritas Should), CFR-INT-101 dan CFR-INT-102 (input diabaikan saat pause dan aktif kembali saat resume, melalui status `paused` dari AppBootstrap).

## 3. Rancangan Teknis

### 3.1 Façade Berbasis Action Map

1. Aksi dideklarasikan data-driven: daftar aksi (nama, tipe, pemetaan input) dibaca dari berkas konfigurasi dan didaftarkan ke `InputMap` milik engine saat langkah 8 boot; penambahan aksi baru tidak mengubah kode façade.
2. Aksi generik SDD-02 terbatas pada navigasi antarmuka yang mungkin dipakai lapisan app (mis. `ui_confirm`, `ui_cancel`); tidak ada aksi pertandingan yang didesain pada tahap ini.
3. API pembacaan: `is_action_pressed(action)`, `is_action_just_pressed(action)`, `is_action_just_released(action)`, `get_axis(negative, positive)`. Seluruh pembacaan menerima status `paused` dari AppBootstrap: saat pause, hasil pembacaan adalah kondisi dilepas (CFR-INT-101), dan saat resume, hasil kembali normal (CFR-INT-102).

### 3.2 Input Sintetis (CFR-FR-028)

1. Lapisan injeksi: `inject_press(action, strength)`, `inject_release(action)`, `clear_injections()`. Nilai injeksi disimpan pada peta kecil dan dipakai oleh API pembacaan dengan prioritas di atas keadaan engine.
2. `clear_injections()` dipanggil otomatis pada awal tiap suite pengujian; injeksi tidak pernah bertahan lintas sesi.
3. Alur berbasis input pada pengujian headless dipicu murni melalui injeksi sehingga CI tidak memerlukan layar sentuh maupun perangkat input.

### 3.3 Batas Tanggung Jawab

1. InputService tidak memuat logika gameplay, pengetahuan scene, maupun pemetaan sentuh ke tindakan pertandingan; ia hanya membaca status aksi dan menyediakan injeksi.
2. Kontrol sentuh konkret pada antarmuka (SDD-04) ditangani node Control bawaan Godot dan tidak melalui façade; façade melayani pembacaan terprogram pada lapisan app dan core.
3. Perluasan SDD-05 menambah aksi dan pemetaan pada data konfigurasi, bukan mengganti antarmuka inti façade; bila SDD-05 menuntut perubahan antarmuka, perubahan melewati proses desain tahap tersebut.

### 3.4 Aturan Audit (CFR-FR-027)

Tidak ada pembacaan input mentah (pemanggilan `Input.*` langsung) pada kode lapisan app dan core di luar InputService; pemeriksaan ini menjadi butir audit kode dan dapat diperiksa otomatis dengan pencarian pola pada tinjauan CI. Pengecualian: kode presentation yang menangani event UI node Control miliknya sendiri (praktik bawaan Godot, bukan pembacaan input pemain terprogram).

## 4. Kontrak Antarmodul

| Antarmuka | Rancangan |
| --- | --- |
| `initialize(action_config)` | Mendaftarkan action map dari data; dipanggil AppBootstrap langkah 8. |
| `is_action_pressed(action) -> bool` | Status aksi; menghormati status pause. |
| `is_action_just_pressed(action) -> bool` | Aksi baru ditekan frame ini; menghormati status pause. |
| `is_action_just_released(action) -> bool` | Aksi baru dilepas frame ini; menghormati status pause. |
| `get_axis(negative, positive) -> float` | Nilai poros dari dua aksi. |
| `inject_press(action, strength)` | Injeksi untuk pengujian; hanya aktif bila mode pengujian diizinkan. |
| `inject_release(action)` | Mengakhiri injeksi satu aksi. |
| `clear_injections()` | Membersihkan seluruh injeksi. |

Ketergantungan: hanya LogService yang disuntik (opsional); InputService tidak memanggil layanan lain (SERVICE-DEPENDENCY-DESIGN tabel 3.2).

## 5. Penanganan Kesalahan

| Kegagalan | Perlakuan |
| --- | --- |
| Aksi tak terdaftar ditanya. | Mengembalikan false dengan WARN sekali per aksi per sesi; tidak error berulang untuk mencegah banjir log. |
| Konfigurasi aksi rusak saat boot. | Layanan sekunder: boot berlanjut mode terdegradasi tanpa aksi (CFR-FR-002); peringatan tercatat. |
| Injekeksi aksi tak terdaftar. | Error eksplisit pada mode pengujian; injeksi ditolak. |

## 6. Pertimbangan Performa

Pembacaan status aksi adalah operasi kamus dan boolean tanpa alokasi; peta injeksi dialokasikan sekali dan hanya tumbuh saat pengujian. Jalur per-frame framework yang memakai façade tidak menimbulkan alokasi (CFR-NFR-005). Pada jalur menganggur tanpa injeksi, pemeriksaan injeksi adalah pemeriksaan kamus kosong.

## 7. Alternatif yang Dipertimbangkan

| Alternatif | Kelebihan | Kekurangan | Alasan Tidak Dipilih |
| --- | --- | --- | --- |
| Façade penuh sejak SDD-02 (OJ-3 opsi a). | Tanpa penulisan ulang nanti. | Mendesain kontrol tanpa kebutuhan pertandingan nyata; berisiko salah total pada SDD-05; melampaui prioritas Should. | Ditolak pemilik proyek 2026-10-31. |
| Tunda seluruhnya ke SDD-05 (OJ-3 opsi c). | Paling ringan. | Pembacaan input tersebar selama SDD-03 dan SDD-04; keputusan kembali terbuka. | FR-027 dan FR-028 akan tertinggal tanpa pemilik. |
| Pembacaan `Input` langsung tanpa façade. | Tanpa lapisan tambahan. | Tidak dapat diuji headless; tersebar; sulit diaudit. | Melanggar FR-027 dan FR-028. |

## 8. Risiko Teknis dan Mitigasi

| Risiko | Kemungkinan | Dampak | Mitigasi |
| --- | --- | --- | --- |
| Antarmuka injeksi berubah saat kontrol nyata tiba (SDD-05). | Rendah | Sedang | Permukaan minimal generik terhadap action map; SDD-05 memperluas data, bukan antarmuka. |
| Lapisan atas mengabaizi façade dan membaca `Input` langsung. | Sedang | Sedang | Butir audit 3.4; pemeriksaan pola pada tinjauan; contoh pemakaian pada dokumen spesifikasi. |
| Status pause tidak diperiksa pemanggil. | Rendah | Sedang | Pemeriksaan pause berada di dalam façade, bukan pada tiap pemanggil. |

## 9. Strategi Pengujian

`core_input_tests.gd`: registrasi aksi dari data, pembacaan pressed, just_pressed, just_released, get_axis; prioritas injeksi di atas keadaan engine; clear_injections; perilaku saat status pause aktif (INT-101, INT-102); penolakan injeksi aksi tak terdaftar. Seluruh suite headless; integration test alur berbasis input memakai injeksi (FR-028).

## 10. Kriteria Penerimaan Desain

1. Façade menutup FR-027 dan FR-028 tanpa logika gameplay dan tanpa pengetahuan scene.
2. Input sintetis terbukti memicu alur pada CI headless.
3. Perilaku pause dan resume pada pembacaan teruji (INT-101, INT-102).
4. Jalur perluasan SDD-05 dinyatakan eksplisit.
5. Pemilik proyek menyetujui sebelum tahap Specification.

## 11. Referensi

- CORE-FRAMEWORK-REQUIREMENTS bagian 5.8, 10, 15
- SERVICE-DEPENDENCY-DESIGN tabel 3.2 (ketergantungan InputService)
- INITIALIZATION-LIFECYCLE-DESIGN bagian 3.5 (status pause)
- DECISION_LOG: P-021 (usulan; OJ-3)

## 12. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
