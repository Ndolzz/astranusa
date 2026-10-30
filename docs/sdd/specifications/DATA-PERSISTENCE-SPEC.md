# DATA-PERSISTENCE-SPEC: Spesifikasi Penyimpanan Data Pemain

- Status: Approved (disetujui pemilik proyek pada 2026-10-30)
- Sistem: Save & Persistence
- Tahap roadmap terikat: SDD-02 (SaveService), SDD-03 (data layer), SDD-04 (profil), SDD-10 (rank dan progresi), SDD-13 (verifikasi pembaruan)
- Terakhir diperbarui: 2026-10-30

## 1. Tujuan

Spesifikasi ini mendefinisikan bagaimana ASTRANUSA menyimpan data pemain agar seluruh progres tetap tersedia ketika aplikasi diperbarui (APK baru dipasang di atas instalasi lama) dan ketika game dijalankan tanpa koneksi internet.

## 2. Ruang Lingkup

Dalam lingkup:

1. Kategori data pemain dan lokasi penyimpanannya.
2. Struktur berkas penyimpanan (store), versi schema, dan checksum.
3. Aturan penulisan yang aman (atomic write).
4. Kepemilikan akses terhadap penyimpanan.
5. Penanganan ruang penyimpanan tidak mencukupi.

Di luar lingkup:

1. Mekanisme migrasi antar versi schema (lihat [DATA-MIGRATION-SPEC](DATA-MIGRATION-SPEC.md)).
2. Alur pembaruan aplikasi secara keseluruhan (lihat [UPDATE-SYSTEM-SPEC](UPDATE-SYSTEM-SPEC.md)).
3. Kompatibilitas paket APK (lihat [APK-COMPATIBILITY-SPEC](APK-COMPATIBILITY-SPEC.md)).
4. Sinkronisasi cloud; proyek bersifat offline dan tidak menggunakan layanan cloud.

## 3. Prinsip Dasar

1. Data pemain tidak pernah disimpan di dalam APK atau direktori yang diganti ketika aplikasi diperbarui.
2. Seluruh data pemain berada pada penyimpanan lokal aplikasi yang bertahan melewati proses pembaruan APK.
3. Data pemain tidak pernah ditulis sebagai bagian dari aset game dan tidak pernah digabungkan dengan aset.
4. Satu-satunya penulis data pemain adalah layanan penyimpanan (SaveService); modul lain mengakses melalui antarmuka layanan.
5. Setiap penulisan dilakukan secara atomik: proses yang berhenti di tengah jalan tidak boleh menghasilkan berkas yang setengah tertulis.

## 4. Perilaku Penyimpanan Android

Ketentuan platform yang menjadi dasar spesifikasi ini:

1. Pada Android, direktori `user://` Godot dipetakan ke penyimpanan internal khusus aplikasi (app-specific storage).
2. Penyimpanan tersebut tetap utuh ketika APK baru dipasang di atas instalasi lama dengan `applicationId` yang sama (pembaruan normal).
3. Penyimpanan tersebut dihapus hanya ketika pengguna melakukan uninstall aplikasi atau membersihkan data aplikasi melalui pengaturan sistem; kedua peristiwa ini berada di luar kendali aplikasi dan didokumentasikan sebagai risiko pada [UPDATE-SYSTEM-SPEC](UPDATE-SYSTEM-SPEC.md).
4. Direktori `res://` berada di dalam APK: bersifat baca-saja dan diganti seluruhnya pada setiap pembaruan; karenanya `res://` tidak boleh digunakan untuk data pemain.

## 5. Pemisahan Kategori Data

| Kategori | Lokasi | Sifat | Bertahan Pembaruan APK |
| --- | --- | --- | --- |
| File instalasi aplikasi | APK (`res://`) | Baca-saja, diganti seluruhnya saat update. | Tidak relevan (selalu versi terbaru). |
| Data pemain | `user://saves/` | Baca-tulis, milik pemain. | Ya. |
| Aset bawaan game | `res://assets/` di dalam APK | Baca-saja. | Diganti dengan versi baru. |
| Aset tambahan yang dapat diperbarui | `user://assets_override/` | Baca-tulis, dikelola sistem aset. | Ya, dikelola melalui manifest (lihat UPDATE-SYSTEM-SPEC). |
| Cadangan migrasi | `user://saves/backup/` | Baca-tulis, dibuat otomatis sebelum migrasi. | Ya. |
| Berkas sementara | `user://tmp/` | Baca-tulis, dibersihkan pada saat boot. | Tidak dijamin (dapat dibuang). |

## 6. Data Pemain yang Wajib Dipertahankan

| No | Data | Store | Keterangan |
| --- | --- | --- | --- |
| 1 | Nickname dan profil pemain | `player_profile` | Termasuk pengidentifikasi profil lokal. |
| 2 | Level dan EXP | `player_profile` | Progresi akun. |
| 3 | Rank dan progres rank | `player_rank` | Tier, divisi, star, riwayat perubahan rank. |
| 4 | Hero dan skin yang dimiliki | `player_collection` | Termasuk sumber kepemilikan (default atau dibuka). |
| 5 | Emblem dan talent | `player_collection` | Konfigurasi emblem dan talent yang dimiliki. |
| 6 | Battle Spell | `player_collection` | Spell yang tersedia dan dipilih. |
| 7 | Build item tersimpan | `player_loadouts` | Build per hero beserta nama build. |
| 8 | Statistik pertandingan | `match_stats` | Agregat: jumlah main, menang, kalah, MVP, dan statistik per hero. |
| 9 | Riwayat pertandingan | `match_history` | Ringkasan per pertandingan, jumlah entri dibatasi (O-019). |
| 10 | Achievement | `player_achievements` | Progres dan status achievement. |
| 11 | Pengaturan grafis, audio, dan kontrol | `settings` | Termasuk bahasa dan preferensi tampilan. |
| 12 | Preferensi pemain lainnya | `settings` | Kategori tambahan yang didefinisikan tahap berikutnya; kunci baru harus memiliki nilai default aman. |

Pemisahan store dimaksudkan agar migrasi dan cadangan berlangsung per domain data: kegagalan pada satu store tidak merusak store lain.

## 7. Struktur Berkas Store

Setiap store adalah satu berkas JSON dengan amplop (envelope) berikut:

```json
{
  "schema_version": 1,
  "app_version_written": "0.1.0",
  "checksum": "<sha256 dari field data>",
  "data": { }
}
```

Ketentuan:

1. `schema_version`: versi schema store tersebut; menjadi dasar migrasi (lihat [DATA-MIGRATION-SPEC](DATA-MIGRATION-SPEC.md)).
2. `app_version_written`: versi aplikasi terakhir yang menulis berkas; digunakan untuk diagnostik.
3. `checksum`: SHA-256 atas representasi `data`; pemuatan menolak berkas dengan checksum tidak cocok dan memicu pemulihan cadangan.
4. `data`: muatan store; struktur dalam didefinisikan per store pada spesifikasi tahap terkait (misalnya struktur rank didefinisikan pada SDD-10).
5. Format JSON dipilih agar mudah diperiksa, dapat divalidasi, dan selaras dengan keputusan D-006 dan P-006.

Nama berkas store: `user://saves/<store_name>.store` (contoh: `user://saves/player_profile.store`).

## 8. Aturan Penulisan Aman

1. Penulisan mengikuti urutan: tulis ke berkas sementara `user://tmp/<store>.tmp` → pastikan penulisan selesai → ganti nama (rename) menjadi berkas store target secara atomik.
2. Tidak ada modul yang boleh menulis langsung ke berkas store target.
3. Sebelum menulis, layanan memeriksa ketersediaan ruang; jika ruang tidak mencukupi (lihat bagian 12), penulisan dibatalkan dengan error yang jelas dan data lama tetap utuh.
4. SaveService mempertahankan seluruh operasi tulis dalam satu antrean untuk mencegah penulisan bersamaan ke berkas yang sama.
5. Momen penulisan minimum yang diwajibkan: akhir pertandingan, perubahan pengaturan, perubahan rank, dan ketika aplikasi ditutup secara normal.

## 9. Kepemilikan Akses

1. Hanya SaveService yang boleh membuka berkas pada `user://saves/`.
2. Modul lain membaca dan menulis data melalui API SaveService, bukan melalui akses berkas langsung.
3. Konfigurasi statis game (hero, item, emblem, battle spell, rank tier) bukan data pemain dan dibaca melalui ConfigService dari `res://config/` atau `user://assets_override/`; data pemain hanya menyimpan referensi (identifikasi) terhadap konten tersebut, bukan menyalin definisinya. Dengan demikian konten boleh berubah antar versi tanpa merusak data pemain.

## 10. Integritas dan Batas Proteksi

1. Checksum mendeteksi kerusakan berkas dan penulisan yang gagal; ini adalah mekanisme keandalan, bukan batas keamanan.
2. Karena game offline pada perangkat milik pemain, manipulasi oleh pemain sendiri tidak dapat dicegah secara mutlak; proteksi tambahan data rank dievaluasi pada O-009 dan tidak dianggap prasyarat tahap ini.

## 11. Inisialisasi Pertama Kali

1. Ketika `user://saves/` kosong, aplikasi membuat store baru dengan `schema_version` sama dengan versi terkini dan nilai default yang aman.
2. Pembuatan default tidak boleh menimpa store yang sudah ada; keberadaan berkas diperiksa sebelum penulisan.
3. Nickname default dibentuk dari pola yang ditentukan pada spesifikasi profil (SDD-04); pemain dapat mengubahnya kemudian.

## 12. Ruang Penyimpanan Tidak Mencukupi

1. Sebelum penulisan store, layanan memeriksa ruang bebas pada `user://`.
2. Jika ruang bebas lebih kecil dari dua kali ukuran store terbesar, penulisan ditunda dan pengguna diberi pesan yang jelas; tidak ada penulisan parsial yang dibiarkan.
3. Jika pemeriksaan tidak dapat dilakukan pada perangkat tertentu, penulisan tetap menggunakan pola atomik sehingga kegagalan di tengah jalan tidak merusak data lama.

## 13. Acceptance Criteria

- [ ] Seluruh data pada bagian 6 tersimpan di bawah `user://saves/`, terpisah dari aset dan APK.
- [ ] Memasang APK baru di atas instalasi lama tidak mengubah isi `user://saves/`.
- [ ] Setiap store memiliki `schema_version`, `app_version_written`, dan checksum yang valid.
- [ ] Tidak ada penulisan non-atomik ke berkas store.
- [ ] Hanya SaveService yang mengakses `user://saves/`.
- [ ] Data pemain tidak menyimpan salinan definisi konten, hanya referensi identifikasi.
- [ ] Aplikasi pertama kali dijalankan membentuk store default tanpa menimpa data yang ada.
- [ ] Ruang penyimpanan tidak mencukupi tidak menghasilkan berkas setengah tertulis.

## 14. Referensi

- [DATA-MIGRATION-SPEC](DATA-MIGRATION-SPEC.md)
- [UPDATE-SYSTEM-SPEC](UPDATE-SYSTEM-SPEC.md)
- [APK-COMPATIBILITY-SPEC](APK-COMPATIBILITY-SPEC.md)
- [UPDATE-TEST-PLAN](../verification/UPDATE-TEST-PLAN.md)
- [Decision Log](../../DECISION_LOG.md): D-006, P-006, O-009, O-019
