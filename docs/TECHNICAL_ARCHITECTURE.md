# Technical Architecture — ASTRANUSA

Dokumen ini mendefinisikan arsitektur teknis awal proyek. Dokumen ini bersifat evolutif: setiap revisi mencatat alasannya pada [Decision Log](DECISION_LOG.md). Item yang belum final ditandai sebagai keputusan terbuka (O-xx) dan harus diselesaikan sebelum tahap implementasi terkait.

## 1. Prinsip Arsitektur

1. Modular dan terstruktur. Setiap sistem dipisahkan menjadi modul dengan tanggung jawab tunggal; kode monolitik dihindari.
2. Data-driven. Konten (hero, item, emblem, battle spell, rank) didefinisikan sebagai data, bukan hard-coded.
3. Testable. Logika simulasi pertandingan dapat dijalankan secara headless tanpa rendering, sehingga dapat diuji otomatis di CI.
4. Offline-first. Tidak ada ketergantungan pada layanan jaringan untuk fitur inti.
5. Efisiensi memori. Alokasi runtime diminimalkan melalui object pooling dan penghindaran pembuatan objek per frame.
6. Kompatibilitas Android. Setiap keputusan arsitektur dievaluasi terhadap perangkat Android kelas menengah.

## 2. Evaluasi dan Pilihan Teknologi

| Komponen | Pilihan | Rasio Pemilihan | Status |
| --- | --- | --- | --- |
| Game engine | Godot 4 | Open source tanpa royalti; export Android resmi; dukungan headless untuk CI; ukuran runtime lebih ringan dibanding engine besar lain. | Diterima (D-001). |
| Bahasa | GDScript | Iterasi cepat; integrasi langsung dengan engine; ukuran APK lebih kecil dibanding C# yang memerlukan runtime tambahan pada Android. | Diterima (D-002). |
| Rendering | Mobile Renderer | Dioptimalkan untuk perangkat seluler; mendukung fitur visual yang memadai untuk MOBA. | Diterima (D-003); opsi Compatibility Renderer untuk perangkat kelas bawah dicatat sebagai O-017. |
| Platform | Android | Sesuai kebutuhan proyek. Versi Android minimum ditetapkan pada SDD-01 (O-008). | Diterima (D-004). |
| Version control | Git dan GitHub | Pusat source code sesuai ketentuan proyek. | Diterima (D-005). |
| CI/CD | GitHub Actions | Gratis untuk repository publik; dukungan artifact dan secrets; tidak memerlukan layanan berbayar. | Diterima (D-005). |
| Pengujian | Godot headless testing | Pengujian otomatis tanpa perangkat fisik; framework spesifik ditetapkan pada SDD-01 (O-002). | Diterima, detail terbuka. |
| Data konfigurasi | JSON dan Godot Resources | JSON untuk data balance yang mudah diperiksa dan divalidasi di CI; Godot Resources untuk definisi yang terikat aset engine. Pembagian rinci ditetapkan pada SDD-03 (O-005). | Diterima, detail terbuka. |

## 3. Arsitektur Berlapis

Sistem disusun menjadi lima lapisan. Aturan ketergantungan: sebuah lapisan hanya boleh bergantung pada lapisan di bawahnya, tidak sebaliknya.

```
┌─────────────────────────────────────────────┐
│ presentation/   Lobby, HUD, 3D showcase, UI  │
├─────────────────────────────────────────────┤
│ app/            Scene routing, mode match,   │
│                 aplikasi                     │
├─────────────────────────────────────────────┤
│ simulation/     Logika pertandingan: unit,   │
│                 combat, ability, AI, sistem  │
│                 peta                        │
├─────────────────────────────────────────────┤
│ data/           Definisi data, loader,       │
│                 validasi konfigurasi        │
├─────────────────────────────────────────────┤
│ core/           Event bus, save service,     │
│                 config service, state        │
│                 machine, object pool, RNG   │
└─────────────────────────────────────────────┘
```

Ketentuan penting:

1. Lapisan `simulation/` tidak bergantung pada node visual. Logika pertandingan ditulis sebagai kelas GDScript murni yang dapat berjalan headless, dengan fixed timestep agar deterministik dan dapat diuji.
2. Lapisan `presentation/` membaca status simulasi dan menampilkannya; lapisan ini tidak memuat logika keputusan pertandingan.
3. Lapisan `core/` tidak mengetahui adanya gameplay; layanan-layanan bersifat generik.
4. Komunikasi antarmodul menggunakan signal atau event bus, bukan referensi langsung antar modul yang tidak terkait.

## 4. Rencana Struktur Direktori Proyek Godot

Struktur berikut adalah rencana awal untuk `game/` dan difinalkan pada desain SDD-01:

```
game/
├── project.godot
├── assets/                    # Aset: art, audio, font, theme UI
├── config/                    # Data JSON: heroes, items, emblems,
│                               # spells, ranks, nicknames
├── src/
│   ├── core/                   # Framework services
│   ├── app/                    # Scene routing, mode controllers
│   ├── data/                   # Loader dan validator data
│   ├── simulation/
│   │   ├── match/              # Siklus pertandingan, aturan menang
│   │   ├── units/              # Hero, minion, turret, monster
│   │   ├── combat/             # Damage pipeline, status effect
│   │   ├── abilities/          # Framework skill: passive, S1, S2, Ultimate
│   │   ├── systems/            # Ekonomi, respawn, concealment, objektif
│   │   └── ai/                 # AI berlapis
│   └── presentation/
│       ├── lobby/              # Bottom navigation, header, showcase
│       ├── match_ui/           # HUD pertandingan
│       └── shared/             # Komponen UI yang dapat dipakai ulang
├── tests/                      # Unit, integration, smoke tests
└── tools/                      # Skrip headless untuk CI
```

## 5. Desain Data-Driven

1. Data balance (statistik hero, item, emblem, battle spell, tier rank) disimpan sebagai JSON agar mudah diperiksa pada code review, dapat divalidasi otomatis di CI, dan dapat diedit tanpa membuka editor.
2. Definisi yang terikat aset engine (scene, animasi, audio) menggunakan Godot Resources (`.tres`/`.res`).
3. Seluruh data konfigurasi divalidasi pada saat pemuatan dan pada CI; data yang tidak valid harus menolak untuk dimuat dengan pesan error yang jelas, bukan dibiarkan dalam kondisi tidak terdefinisi.
4. Skema data dan alat validasinya ditetapkan pada SDD-03 (O-005, O-006).

## 6. Rencana Autoload dan Layanan

Autoload dibatasi minimum dan setiap penambahan harus beralasan. Rencana awal:

| Autoload | Tanggung Jawab |
| --- | --- |
| `EventBus` | Signal lintas modul untuk mendekopling komunikasi. |
| `SceneRouter` | Transisi antar scene utama (lobby, pertandingan, hasil). |
| `ConfigService` | Memuat dan memvalidasi data JSON, menyediakan akses baca. |
| `SaveService` | Membaca dan menulis data persisten lokal pada `user://`. |
| `AudioService` | Pengaturan dan pemutaran audio, termasuk announcer. |

Daftar final beserta antarmuka ditetapkan pada spesifikasi SDD-02. Format penyimpanan dan proteksi integritas data rank merupakan keputusan terbuka (O-009).

## 7. Arsitektur AI Bot

AI disusun menjadi tiga lapisan:

| Lapisan | Tanggung Jawab |
| --- | --- |
| Strategic | Keputusan makro: penempatan lane, rotasi, prioritas objektif, push, retreat. |
| Tactical | Pemilihan target, penggunaan ability, keterlibatan atau mundur dari pertempuran. |
| Operational | Eksekusi gerak: pathfinding, micro-positioning, kiting. |

Ketentuan tingkat kesulitan:

1. Tingkat kesulitan didefinisikan sebagai profile perilaku: waktu reaksi, akurasi kesadaran peta, kualitas prioritas objektif, tingkat koordinasi tim, dan tingkat kesalahan.
2. AI tidak memperoleh bonus HP atau damage pada tingkat kesulitan yang lebih tinggi.
3. Teknik implementasi inti (behavior tree, utility system, atau hibrida) merupakan keputusan terbuka (O-007) dan ditetapkan pada desain SDD-08.
4. AI diuji melalui simulasi headless: pertandingan penuh antar bot harus dapat dijalankan tanpa rendering untuk mengukur kualitas perilaku.

## 8. Strategi Pengujian

| Tingkat | Lingkup | Cara Eksekusi |
| --- | --- | --- |
| Unit | Logika murni: damage pipeline, economy, aturan rank, validator data. | Headless di CI. |
| Integration | Interaksi antar sistem: ability dan status effect, AI dan sistem peta. | Headless di CI. |
| Smoke | Satu pertandingan penuh antar bot berakhir dengan hancurnya Base Core. | Headless di CI. |
| Manual | Visual, kenyamanan kontrol, kinerja pada perangkat fisik. | Pada tahap verifikasi setiap tahap konten. |

Ketentuan:

1. Framework pengujian dipilih pada SDD-01 (O-002).
2. Setiap fitur yang diimplementasikan harus memiliki pengujian yang berjalan pada CI sebelum dinyatakan selesai.
3. Klaim selesai tidak sah tanpa bukti hasil pengujian yang dicatat pada laporan tahap.

## 9. Rencana CI/CD

Rencana workflow GitHub Actions dirinci pada [README workflows](../.github/workflows/README.md). Prinsip yang mengikat:

1. Versi Godot, export template, dan GitHub Actions dikunci pada versi spesifik; perubahan versi melewati Decision Log.
2. Seluruh validasi (struktur, GDScript, pengujian, konfigurasi) berjalan pada pull request; export APK berjalan pada `main` dan manual dispatch.
3. Kredensial Android (keystore) hanya melalui GitHub Secrets; tidak ada kredensial pada repository.
4. Hasil APK disimpan sebagai workflow artifact dengan masa retensi terdefinisi.

## 10. Anggaran Kinerja dan Memori

Target awal berikut divalidasi dengan profiling pada perangkat fisik dan diperbarui pada tahap SDD-12:

| Metrik | Target Awal |
| --- | --- |
| Target perangkat | Android kelas menengah; kelas perangkat final ditetapkan pada O-008. |
| Frame rate | 60 FPS pada perangkat target; 30 FPS sebagai batas bawah perangkat kelas bawah. |
| Memori runtime | Maksimal 1 GB RSS; target internal lebih rendah, diukur berkala. |
| Alokasi per frame | Tanpa alokasi objek besar pada loop utama; pooling untuk projectile dan efek. |
| Kompresi tekstur | ASTC dengan fallback ETC2 sesuai dukungan perangkat. |

## 11. Persistensi Data Lokal

1. Seluruh data tersimpan lokal pada `user://`.
2. Data yang tersimpan: profil pemain, progresi rank, pengaturan, dan hasil pertandingan untuk kebutuhan tampilan.
3. Format file dan proteksi integritas (khususnya data rank agar tidak dapat dimanipulasi secara sepele) merupakan keputusan terbuka (O-009) dan ditetapkan pada desain SDD-10.

## 12. Keamanan

1. Tidak ada kredensial pada source code; keystore dan kredensial export hanya melalui GitHub Secrets.
2. Tidak ada data pribadi yang dikumpulkan; proyek offline dan tanpa server.
3. Input yang berasal dari file konfigurasi divalidasi sebelum digunakan.

## 13. Register Risiko Teknis Awal

| Risiko | Dampak | Mitigasi Awal |
| --- | --- | --- |
| Volume produksi aset 3D (15 hero dan peta) besar. | Jadwal dan ukuran APK. | Blockout dan placeholder terlebih dahulu; pipeline aset dispesifikasikan sebelum tahap konten (O-010). |
| Kompleksitas AI MOBA tinggi. | Kualitas dan durasi pengembangan. | Arsitektur berlapis; pengujian melalui simulasi headless antar bot. |
| Drift versi Godot antar mesin pengembang dan CI. | Build tidak konsisten. | Versi dikunci; validasi struktur pada CI. |
| Determinisme simulasi tidak terjaga. | Pengujian tidak stabil. | Fixed timestep pada simulasi; pengujian deterministik pada lapisan `simulation/`. |

## 14. Keputusan Terbuka Terkait Arsitektur

Seluruh keputusan terbuka dikonsolidasikan pada [Decision Log](DECISION_LOG.md) beserta tahap batas penyelesaiannya.

## 15. Dokumen Terkait

- [Project Overview](PROJECT_OVERVIEW.md)
- [Decision Log](DECISION_LOG.md)
- [Roadmap](ROADMAP.md)
