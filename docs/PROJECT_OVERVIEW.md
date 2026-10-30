# Project Overview — ASTRANUSA

Dokumen ini adalah rujukan tingkat tinggi untuk seluruh proyek. Perubahan pada dokumen ini memerlukan persetujuan pemilik proyek dan dicatat pada [Decision Log](DECISION_LOG.md).

## 1. Ringkasan Produk

ASTRANUSA adalah game MOBA 5v5 offline melawan AI bot dengan inspirasi mitologi, legenda, dan budaya Nusantara. Satu pemain manusia bermain bersama dan melawan sembilan bot. Seluruh fitur inti berjalan tanpa koneksi internet dan tanpa server.

## 2. Pilar Desain

1. Identitas Nusantara. Hero, penamaan, dan elemen visual mengacu pada mitologi, legenda, dan budaya Nusantara.
2. Offline-first. Seluruh mode, progresi, dan penyimpanan data berjalan secara lokal pada perangkat.
3. Ritme pertandingan terkendali. Rata-rata durasi pertandingan sekitar 15 menit; pertandingan hanya berakhir ketika Base Core salah satu tim dihancurkan.
4. AI yang adil dan terbaca. Kesulitan AI meningkat berdasarkan kemampuan strategis, bukan berdasarkan penambahan HP atau damage.

## 3. Konsep Inti

| Aspek | Ketentuan |
| --- | --- |
| Genre | MOBA 5v5. |
| Mode dominan | Offline versus AI: satu pemain manusia dan sembilan bot. |
| Role | Assassin, Fighter, Mage, Support, Marksman. |
| Posisi jungler | Posisi atau fungsi dalam pertandingan, bukan role keenam. |
| Kondisi menang | Base Core tim lawan dihancurkan. |
| Durasi target | Rata-rata sekitar 15 menit per pertandingan. |
| Jumlah hero rilis awal | 15 hero. |
| Kit hero | Satu passive, Skill 1, Skill 2, dan Ultimate. |

## 4. Peta

Peta pertandingan memiliki komponen berikut:

1. Tiga lane.
2. Area jungle.
3. Turret sebagai struktur pertahanan.
4. Jungle monster.
5. Rumput dengan mekanisme concealment.

## 5. Sistem dan Fitur Inti Rilis Awal

1. Item: peralatan yang dapat dibeli selama pertandingan.
2. Emblem: konfigurasi penguat yang disiapkan sebelum pertandingan.
3. Battle spell: kemampuan tambahan yang dipilih sebelum pertandingan.
4. Rank: sistem progresi kompetitif lokal.
5. Nickname bot: nama tampilan untuk sembilan bot.
6. Announcer: suara pengisi pertandingan berbahasa Inggris.

## 6. Mode Permainan

| Mode | Deskripsi | Pengaruh Rank |
| --- | --- | --- |
| Classic 5v5 | Pertandingan standar 5v5 melawan AI. | Tidak mempengaruhi rank. |
| Ranked 5v5 | Pertandingan kompetitif melawan AI dengan tingkat kesulitan yang terkait dengan tier rank. | Mempengaruhi progresi rank. |
| Practice | Mode latihan bebas untuk pembelajaran hero dan mekanik. | Tidak mempengaruhi rank. |
| Custom Match | Pertandingan dengan pengaturan khusus. Parameter terperinci didefinisikan pada tahap requirement SDD-09. | Tidak mempengaruhi rank. |

Seluruh mode dapat dimainkan tanpa koneksi internet.

## 7. Sistem Ranked

| Tier | Identifikasi Internal | Divisi |
| --- | --- | --- |
| Perunggu | `BRONZE` | III hingga I. |
| Perak | `SILVER` | III hingga I. |
| Emas | `GOLD` | IV hingga I. |
| Platinum | `PLATINUM` | IV hingga I. |
| Berlian | `DIAMOND` | IV hingga I. |
| Mitos | `MYTHIC` | V hingga I. |
| Legenda Nusantara | `LEGEND_NUSANTARA` | Tier tertinggi; ketentuan divisi ditetapkan pada tahap requirement SDD-10. |

Ketentuan tambahan:

1. Kesulitan AI pada Ranked meningkat seiring tier rank pemain, melalui peningkatan kualitas strategis.
2. Mekanisme star, promosi, dan demosi tier ditetapkan pada tahap requirement SDD-10.

## 8. Konsep Lobby

1. Visual utama berupa 3D Character Showcase dengan hero 3D sebagai pusat perhatian.
2. Navigasi berbentuk bottom navigation.
3. Header menampilkan profil, nickname, level, dan rank.
4. Lima navigasi: Home, Heroes, Preparation, Profile, Settings.
5. Lobby mendukung akses ke empat mode permainan.
6. Profil dan progresi tersimpan secara lokal.
7. Tidak membutuhkan server untuk fitur inti.

## 9. Platform dan Target Teknis

1. Platform target: Android.
2. Rendering: Mobile Renderer Godot 4.
3. Bahasa pemrograman: GDScript.
4. Prioritas teknis: kompatibilitas Android dan efisiensi memori.

## 10. Non-Goals Rilis Awal

Berikut hal-hal yang secara eksplisit berada di luar lingkup rilis awal:

1. Multiplayer online atau fitur yang membutuhkan server.
2. Platform selain Android.
3. Monetisasi, pembelian dalam aplikasi, dan iklan.
4. Layanan berbayar sebagai ketergantungan inti.

## 11. Pertanyaan Terbuka Terkait Konsep

Pertanyaan berikut harus dijawab pada tahap requirement sistem terkait, bukan dijawab dengan asumsi:

1. Parameter terperinci Custom Match (SDD-09).
2. Mekanisme star, promosi, dan demosi rank (SDD-10).
3. Ketentuan divisi tier Legenda Nusantara (SDD-10).
4. Aturan draft dan pemilihan hero pada setiap mode (SDD-09).

## 12. Dokumen Terkait

- [Technical Architecture](TECHNICAL_ARCHITECTURE.md)
- [Decision Log](DECISION_LOG.md)
- [Roadmap](ROADMAP.md)
