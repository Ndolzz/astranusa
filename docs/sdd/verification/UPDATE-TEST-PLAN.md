# UPDATE-TEST-PLAN: Rencana Pengujian Sistem Pembaruan dan Persistensi Data

- Status: Approved (disetujui pemilik proyek pada 2026-10-30)
- Sistem: Update System, Save & Persistence, Migration
- Tahap roadmap terikat: SDD-02 (unit test store dan migrasi), SDD-10 (data rank), SDD-13 (uji pembaruan pada perangkat)
- Terakhir diperbarui: 2026-10-30

## 1. Tujuan

Rencana ini memverifikasi bahwa pembaruan ASTRANUSA mempertahankan seluruh data pemain, migrasi berjalan aman, dan kegagalan apa pun tidak menghilangkan data.

## 2. Kriteria Masuk dan Keluar

Kriteria masuk:

1. Spesifikasi terkait telah disetujui.
2. Build APK dua versi berbeda tersedia (versi lama dan versi baru dengan `versionCode` lebih tinggi).
3. Perangkat Android fisik atau emulator tersedia untuk skenario instalasi.

Kriteria keluar:

1. Seluruh skenario T-01 hingga T-12 berstatus lulus atau memiliki catatan penyimpangan yang disetujui.
2. Tidak ada skenario yang menghasilkan kehilangan data tanpa pemulihan.

## 3. Perkakas

| Perkakas | Fungsi |
| --- | --- |
| Perangkat Android atau emulator | Instalasi dan pembaruan APK. |
| `adb install -r` | Memasang APK pembaruan di atas instalasi lama. |
| Skrip fixture data | Membuat store versi lama dengan data contoh yang dapat diperiksa. |
| Godot headless (`--migrate-only`) | Menjalankan migrasi di CI tanpa perangkat. |
| `aapt dump badging` | Memverifikasi `applicationId`, `versionCode`, dan `versionName` APK. |

## 4. Matriks Skenario

| ID | Skenario | Jenis | Dieksekusi Pada |
| --- | --- | --- | --- |
| T-01 | Instalasi pertama | Manual perangkat | SDD-13 (dan setiap build awal). |
| T-02 | Membuat profil pemain | Manual + unit test | SDD-04. |
| T-03 | Menyelesaikan pertandingan | Manual | SDD-09. |
| T-04 | Mendapatkan EXP dan perubahan rank | Manual + unit test | SDD-10. |
| T-05 | Menyimpan pengaturan | Manual + unit test | SDD-04. |
| T-06 | Memasang APK versi baru di atas versi lama | Manual perangkat | SDD-13. |
| T-07 | Seluruh data tetap tersedia setelah pembaruan | Manual perangkat | SDD-13. |
| T-08 | Migrasi schema berhasil | Otomatis CI + manual | SDD-02, SDD-13. |
| T-09 | Migrasi gagal dan pemulihan cadangan | Otomatis CI + manual | SDD-02, SDD-13. |
| T-10 | Proses pembaruan/migrasi terhenti di tengah jalan | Otomatis CI + manual | SDD-02, SDD-13. |
| T-11 | Pembaruan dengan ruang penyimpanan hampir penuh | Manual perangkat | SDD-13. |
| T-12 | Pembaruan beberapa versi sekaligus | Otomatis CI + manual | SDD-02, SDD-13. |

## 5. Rincian Skenario

### T-01: Instalasi pertama

- Prasyarat: perangkat bersih tanpa ASTRANUSA.
- Langkah: pasang APK rilis; jalankan game.
- Diharapkan: game berjalan; store default terbentuk di `user://saves/`; tidak ada berkas cadangan; lobby tampil.
- Lulus bila: seluruh store terbentuk dengan `schema_version` terkini dan nilai default aman.

### T-02: Membuat profil pemain

- Prasyarat: T-01 selesai.
- Langkah: ubah nickname; periksa berkas `player_profile.store`.
- Diharapkan: nickname baru tersimpan dan checksum berkas diperbarui.
- Lulus bila: setelah aplikasi ditutup dan dibuka kembali, nickname tetap sama.

### T-03: Menyelesaikan pertandingan

- Prasyarat: T-02 selesai.
- Langkah: mainkan satu pertandingan hingga layar hasil; tutup aplikasi segera setelah layar hasil (tanpa menunggu).
- Diharapkan: hasil pertandingan tersimpan ke `match_history` dan `match_stats` sebelum keluar dari layar hasil.
- Lulus bila: riwayat dan statistik pertandingan tercatat setelah aplikasi dibuka kembali.

### T-04: Mendapatkan EXP dan perubahan rank

- Prasyarat: T-03 selesai; mode Ranked tersedia.
- Langkah: mainkan pertandingan Ranked; amati perubahan EXP dan rank.
- Diharapkan: EXP, level, tier, divisi, dan star tersimpan pada store `player_rank` dan `player_profile`.
- Lulus bila: perubahan bertahan setelah aplikasi ditutup paksa dan dibuka kembali.

### T-05: Menyimpan pengaturan

- Prasyarat: T-01 selesai.
- Langkah: ubah pengaturan grafis, audio, dan kontrol; tutup aplikasi dengan segera.
- Diharapkan: seluruh perubahan tersimpan pada `settings.store` pada saat perubahan dilakukan, bukan hanya saat keluar.
- Lulus bila: pengaturan tetap setelah aplikasi dibuka kembali.

### T-06: Memasang APK versi baru di atas versi lama

- Prasyarat: data pemain dari T-02 hingga T-05 ada; APK versi baru dengan `versionCode` lebih tinggi, `applicationId` sama, dan signing key sama.
- Langkah: `adb install -r <apk-baru>`; buka game.
- Diharapkan: Android memasang pembaruan tanpa meminta uninstall; game versi baru berjalan; layar berjalan melewati urutan boot pembaruan (cek jurnal, cek schema).
- Lulus bila: pemasangan berhasil tanpa peringatan OS dan tanpa kehilangan data aplikasi.

### T-07: Seluruh data tetap tersedia setelah pembaruan

- Prasyarat: T-06 selesai pada data yang sama.
- Langkah: periksa seluruh data pada bagian 6 DATA-PERSISTENCE-SPEC: nickname, level, EXP, rank, hero dan skin, emblem dan talent, battle spell, build item, statistik, riwayat, achievement, pengaturan, preferensi.
- Diharapkan: seluruh nilai identik dengan sebelum pembaruan.
- Lulus bila: tidak ada satu pun kategori data yang berubah nilai atau hilang.

### T-08: Migrasi schema berhasil

- Prasyarat: fixture store versi lama (misalnya `schema_version` 1) yang dibuat oleh versi aplikasi lama; versi baru mendefinisikan schema 2.
- Langkah: jalankan game versi baru; periksa berkas store, cadangan, dan jurnal.
- Diharapkan: migrasi berjalan otomatis; `schema_version` menjadi 2; cadangan `v1` ada; jurnal `completed`; data bermigrasi sesuai aturan langkah migrasi.
- Lulus bila: nilai data hasil migrasi sesuai fixture yang diharapkan dan boot berikutnya tidak menjalankan migrasi ulang.

### T-09: Migrasi gagal dan pemulihan cadangan

- Prasyarat: fixture store versi lama dengan langkah migrasi yang sengaja dibuat gagal (data tidak lolos validasi).
- Langkah: jalankan game versi baru.
- Diharapkan: cadangan dipulihkan; data lama tetap ada dan tidak dihapus; pesan kegagalan tampil; game tetap dapat dijalankan sesuai mode aman.
- Lulus bila: tidak ada data yang hilang dan percobaan migrasi berikutnya tetap dimungkinkan setelah langkah migrasi diperbaiki.

### T-10: Proses pembaruan terhenti di tengah jalan

- Prasyarat: fixture store versi lama.
- Langkah: mulai migrasi, lalu matikan proses game secara paksa (kill) sebelum rename atomik selesai; jalankan game kembali.
- Diharapkan: jurnal `in_progress` terdeteksi; cadangan dipulihkan; migrasi diulang satu kali dan berhasil; berkas sementara dibersihkan.
- Lulus bila: data akhir sama dengan hasil migrasi normal dan tidak ada berkas setengah tertulis tersisa.

### T-11: Pembaruan dengan ruang penyimpanan hampir penuh

- Prasyarat: perangkat dengan ruang bebas sangat kecil (misalnya diisi hingga tersisa beberapa megabita).
- Langkah: pasang APK pembaruan dan jalankan game sehingga migrasi dan penulisan store terjadi.
- Diharapkan: pemeriksaan ruang menolak penulisan sebelum data ditulis; pesan yang jelas tampil; data lama tetap utuh; aplikasi tidak mati.
- Lulus bila: setelah ruang dibebaskan, pemain dapat memainkan game dan migrasi berjalan normal.

### T-12: Pembaruan beberapa versi sekaligus

- Prasyarat: fixture store versi 1; aplikasi terbaru mendefinisikan schema versi 4 dengan rantai 1 → 2 → 3 → 4.
- Langkah: jalankan aplikasi terbaru langsung atas data versi 1 (melambangkan pemain yang melewati beberapa pembaruan).
- Diharapkan: seluruh rantai langkah dijalankan berurutan; hasil akhir schema versi 4; cadangan versi 1 dibuat; tidak ada langkah yang terlewat.
- Lulus bila: data hasil migrasi identik dengan hasil migrasi bertahap 1 → 2 → 3 → 4 pada fixture yang sama.

### Catatan tambahan (T-13, dokumentasi)

Uninstall aplikasi menghapus `user://` sepenuhnya; ini adalah perilaku sistem operasi di luar kendali aplikasi dan didokumentasikan pada UPDATE-SYSTEM-SPEC, bukan kecacatan yang diuji.

## 6. Otomatisasi

1. T-08, T-09, T-10, dan T-12 dijalankan otomatis di CI melalui Godot headless dengan fixture store dan mode `--migrate-only`.
2. T-01 hingga T-07 dan T-11 memerlukan perangkat dan dilakukan manual pada tahap verifikasi; hasil dicatat pada laporan tahap terkait.
3. Hasil pengujian dicatat pada laporan tahap; skenario yang gagal menghambat acceptance tahap terkait.

## 7. Referensi

- [DATA-PERSISTENCE-SPEC](../specifications/DATA-PERSISTENCE-SPEC.md)
- [DATA-MIGRATION-SPEC](../specifications/DATA-MIGRATION-SPEC.md)
- [UPDATE-SYSTEM-SPEC](../specifications/UPDATE-SYSTEM-SPEC.md)
- [APK-COMPATIBILITY-SPEC](../specifications/APK-COMPATIBILITY-SPEC.md)
