# STATE-MANAGEMENT-SPEC: Spesifikasi State Machine dan Status Aplikasi

- Status: Approved (disetujui pemilik proyek pada 2026-10-31)
- Tahap roadmap: SDD-02 (Core Framework)
- Dokumen requirement: CORE-FRAMEWORK-REQUIREMENTS (Approved, 2026-10-30)
- Dokumen desain: CORE-FRAMEWORK-ARCHITECTURE bagian 3.5 (Approved, 2026-10-31)
- Basis audit: HEAD `aa636633` (branch tunggal `main`)
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan dan Ruang Lingkup

Dokumen ini menetapkan kontrak final pustaka StateMachine generik dan AppState, status aplikasi tingkat atas. Tanda tangan antarmuka berada pada SERVICE-API-SPEC bagian 10.1 dan 10.2. Pustaka ini murni: tanpa referensi autoload, tanpa prasyarat layanan; logger disuntik dan boleh null (SERVICE-DEPENDENCY-DESIGN bagian 3.3).

## 2. Requirement Terkait

CFR-FR-009 (pustaka state machine generik), CFR-FR-010 (status aplikasi eksplisit), CFR-NFR-008 (tanggung jawab tunggal), requirement bagian 8 ketentuan 2 (pustaka murni dapat dipakai tanpa inisialisasi layanan lain).

## 3. Kontrak StateMachine

### 3.1 Status

1. Status adalah nama string unik dalam satu instansi; ditambahkan dengan `add_state(name)`.
2. Instansi baru tanpa status: `current()` mengembalikan string kosong `""`; transisi dari status apa pun menuju status pertama didaftarkan melalui `add_transition` dengan sisi `from` bernilai `""` sehingga titik masuk eksplisit.

### 3.2 Transisi dan Guard

1. `add_transition(from, to, guard)`: mendaftarkan tepi terarah tunggal; `from` boleh `""` (dari keadaan tanpa status). Tepi ganda `from`-`to` yang sama: yang terakhir menimpa definisi sebelumnya dan dicatat WARN.
2. `guard` adalah `Callable` yang menerima payload opsional Dictionary dan mengembalikan bool; guard gagal (mengembalikan `false` atau melempar kesalahan) menolak transisi dengan status `rejected` tanpa efek samping dan log WARN.
3. `transition_to(name)`: status `ok` bila tepi dari status aktif ke `name` terdaftar dan guard lulus; memancarkan signal `state_changed(old, new)` setelah status aktif diperbarui.
4. Transisi menuju status aktif saat ini: ditolak `rejected` dengan WARN (bukan no-op senyap) kecuali tepi eksplisit `from == to` didaftarkan; pendaftaran tepi `from == to` dicatat WARN karena umumnya menandakan kekeliruan.

### 3.3 Transisi Tidak Sah

1. Status tujuan tidak dikenal: `unknown_state`; tanpa efek samping; ERROR dicatat bila logger tersedia.
2. Tepi tidak terdaftar dari status aktif: `rejected`; tanpa efek samping; log WARN (CFR-FR-009).
3. Seluruh penolakan tidak memancarkan signal `state_changed`.

## 4. Kontrak AppState

1. Konstruksi mendaftarkan status `BOOT` dan `READY` beserta tepi `BOOT` ke `READY` tanpa guard; `current()` awal `BOOT`.
2. `mark_ready()` dipanggil AppBootstrap pada langkah 10; setelah berhasil, `current_state()` mengembalikan `READY` dan `is_in_state("READY")` bernilai benar; pemanggilan kedua ditolak `rejected` dengan WARN.
3. Status `LOBBY`, `MATCH`, dan `RESULT` didaftarkan pada tahap pemiliknya (SDD-04, SDD-05, SDD-09) melalui antarmuka pustaka tanpa mengubah berkas `state_machine.gd`; penambahan tersebut menambah baris pada SERVICE-RESPONSIBILITY-MATRIX terlebih dahulu.
4. Konsistensi status dan route (CFR-FR-010): SceneRouter memperbarui referensi AppState yang disuntikkan pada konstruksinya, bukan sebaliknya; AppState tidak mengetahui route. Kueri konsistensi berada pada SCENE-ROUTER-SPEC.

## 5. Integrasi dengan EventBus

1. StateMachine dan AppState tidak berlangganan event mana pun (pustaka murni).
2. Perubahan status aplikasi yang perlu diketahui lintas modul dipancarkan oleh pemilik kejadian: AppBootstrap memancarkan `app.ready` setelah `mark_ready()` berhasil; pemancaran melalui EventBus, bukan oleh AppState.

## 6. Penanganan Kesalahan

| Kegagalan | Kelas | Perlakuan |
| --- | --- | --- |
| `add_state` nama ganda. | Pelanggaran kontrak. | `duplicate`; ERROR bila logger tersedia. |
| `add_transition` status tidak dikenal. | Pelanggaran kontrak. | `unknown_state`; ERROR bila logger tersedia. |
| `transition_to` status tidak dikenal. | Pelanggaran kontrak. | `unknown_state`; tanpa efek samping. |
| Tepi tidak terdaftar atau guard gagal. | Terdegradasi. | `rejected`; log WARN; tanpa efek samping. |
| Guard melempar kesalahan. | Terdegradasi. | Diperlakukan guard gagal; WARN. |
| `mark_ready` setelah READY. | Terdegradasi. | `rejected`; WARN. |

## 7. Kondisi Normal dan Gagal

Kondisi normal: transisi sah memperbarui status aktif tepat satu kali dan memancarkan signal sekali. Kondisi gagal: seluruh bentuk kegagalan pada tabel bagian 6 meninggalkan status aktif tidak berubah dan tidak memancarkan signal; aplikasi tetap dapat menanyai `current()`.

## 8. Validasi dan Kasus Uji (`core_state_tests.gd`)

| ID | Kasus | Requirement | Lulus Bila |
| --- | --- | --- | --- |
| SM-01 | Transisi terdaftar berhasil. | FR-009 | Status aktif berubah; signal terpancar dengan pasangan lama-baru yang benar. |
| SM-02 | Transisi tidak terdaftar ditolak tanpa efek samping. | FR-009 | `rejected`; status tidak berubah; WARN tercatat. |
| SM-03 | Guard gagal menolak transisi. | FR-009 | `rejected`; status tidak berubah. |
| SM-04 | Status tidak dikenal ditolak. | FR-009 | `unknown_state`. |
| SM-05 | `add_state` ganda ditolak. | FR-009 | `duplicate`. |
| SM-06 | Pustaka berfungsi tanpa logger. | Bagian 8 req. nomor 2 | Seluruh operasi tetap ber perilaku; penolakan tanpa catatan. |
| SM-07 | AppState: BOOT ke READY sekali. | FR-010 | `mark_ready()` pertama `ok`; kedua `rejected`. |
| SM-08 | Konsistensi kueri `current_state` dan `is_in_state`. | FR-010 | Kedua kueri konsisten sebelum dan sesudah transisi. |
| SM-09 | Suite berjalan tanpa autoload aktif. | Bagian 15 req. nomor 1 | Suite hijau pada konteks tanpa autoload. |

## 9. Batasan

1. Tidak ada histori transisi pada pustaka; histori yang dibutuhkan pengujian direkam oleh pemakai (SceneRouter merekam riwayat route).
2. Tidak ada dukungan status paralel atau hierarki; kebutuhan menyusul tahap yang membutuhkan dan melalui proses desain.
3. Pustaka tidak menyimpan payload transisi; guard menerima payload dari pemanggil `transition_to(name, payload)` melalui parameter opsional yang tidak disimpan.

## 10. Referensi

- CORE-FRAMEWORK-ARCHITECTURE bagian 3.5; INITIALIZATION-LIFECYCLE-DESIGN bagian 3.2 (langkah 10).
- SERVICE-DEPENDENCY-DESIGN bagian 3.3 (pola penyuntikan pustaka murni).
- EVENT-BUS-SPEC bagian 3 (pemancaran `app.ready` oleh AppBootstrap).

## 11. Persetujuan

- Pemilik proyek: Ndolzz — Status: Disetujui pada 2026-10-31
