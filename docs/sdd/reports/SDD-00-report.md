# Laporan Tahap SDD-00: Project Foundation

- Tanggal: 2026-10-30
- Status acceptance: Accepted (disetujui pemilik proyek pada 2026-10-30, melalui persetujuan push dan usulan P-001)

## 1. Scope Pekerjaan

1. Audit kondisi repository ASTRANUSA pada GitHub.
2. Identifikasi status repository: kosong atau sudah memiliki file.
3. Penentuan struktur dokumentasi SDD.
4. Penyusunan dokumen project overview.
5. Penyusunan technical architecture awal.
6. Penyusunan daftar keputusan teknis yang masih terbuka.
7. Penyusunan roadmap implementasi bertahap.

Pekerjaan sengaja dibatasi pada fondasi dokumentasi; tidak ada kode game yang dibuat pada tahap ini.

## 2. File yang Dibuat atau Diubah

| File | Tindakan | Keterangan |
| --- | --- | --- |
| `README.md` | Dibuat | Titik masuk repository, status proyek, dan prinsip pengembangan. |
| `.gitignore` | Dibuat | Standar Godot 4, output Android, dan pengecualian kredensial. |
| `docs/PROJECT_OVERVIEW.md` | Dibuat | Konsep game, mode, konten rilis awal, dan non-goals. |
| `docs/TECHNICAL_ARCHITECTURE.md` | Dibuat | Arsitektur berlapis, rencana direktori, strategi pengujian, rencana CI/CD, anggaran kinerja, dan register risiko. |
| `docs/DECISION_LOG.md` | Dibuat | Enam keputusan diterima, dua usulan disetujui, dan tujuh belas keputusan terbuka dengan tahap batas. |
| `docs/ROADMAP.md` | Dibuat | Empat belas tahap SDD-00 hingga SDD-13 beserta kriteria keluar dan ketergantungan. |
| `docs/sdd/README.md` | Dibuat | Definisi proses SDD, aturan gerbang, pemetaan direktori, konvensi penamaan, dan format laporan. |
| `docs/sdd/reports/SDD-00-report.md` | Dibuat | Dokumen ini. |
| `docs/templates/TEMPLATE-REQ.md` | Dibuat | Template requirement analysis. |
| `docs/templates/TEMPLATE-DESIGN.md` | Dibuat | Template technical design. |
| `docs/templates/TEMPLATE-SPEC.md` | Dibuat | Template specification. |
| `docs/templates/TEMPLATE-REPORT.md` | Dibuat | Template laporan tahap. |
| `game/README.md` | Dibuat | Penanda root proyek Godot 4 yang akan diinisialisasi pada SDD-01. |
| `.github/workflows/README.md` | Dibuat | Rencana lima workflow CI/CD beserta prinsip pengunciannya. |

## 3. Keputusan Teknis

Keputusan diterima (bersumber dari kebutuhan proyek, dicatat sebagai D-001 hingga D-006 pada Decision Log):

1. Godot 4 sebagai game engine (D-001).
2. GDScript sebagai bahasa pemrograman (D-002).
3. Mobile Renderer sebagai renderer (D-003).
4. Android sebagai platform target (D-004).
5. Git, GitHub, dan GitHub Actions untuk version control dan CI/CD (D-005).
6. JSON dan Godot Resources untuk data konfigurasi (D-006).

Keputusan usulan yang disetujui pemilik proyek pada 2026-10-30:

1. P-001: Root proyek Godot ditempatkan pada subdirektori `game/`.
2. P-002: Struktur dokumentasi SDD sebagaimana didefinisikan pada `docs/sdd/README.md`.

Keputusan teknis yang masih terbuka dirangkum dalam tujuh belas butir (O-001 hingga O-017), masing-masing dengan tahap batas penyelesaian. Empat keputusan pertama (versi Godot, framework pengujian, tooling lint, komposisi workflow) wajib diselesaikan sebelum SDD-01.

## 4. Hasil Pengujian

Tahap ini tidak menghasilkan kode, sehingga tidak terdapat pengujian perangkat lunak yang dapat dijalankan. Verifikasi yang dilakukan bersifat dokumenter:

1. Seluruh tautan internal antar dokumen telah diperiksa dan mengarah ke path yang benar.
2. Konsistensi terminologi dan penamaan (identifikasi teknis berbahasa Inggris, narasi berbahasa Indonesia) telah diperiksa.
3. Struktur direktori yang dibuat telah diverifikasi sesuai daftar pada bagian 2.

## 5. Hasil Audit

1. Repository `Ndolzz/astranusa` pada GitHub berstatus ada namun kosong: tidak memiliki branch, commit, maupun file. Repository masih menggunakan branch default `main` yang belum terinisialisasi.
2. Tidak ditemukan pekerjaan sebelumnya yang berisiko tertimpa; seluruh file pada tahap ini bersifat baru.
3. Perbedaan (diff) tahap ini adalah seluruh file baru; tidak ada file yang diubah atau dihapus.
4. Push ke GitHub dilakukan hanya setelah persetujuan pemilik proyek, sesuai aturan pengembangan nomor 11.

## 6. Kendala

1. Versi Godot 4 stabil terbaru yang akan dikunci belum ditetapkan karena menuntut konfirmasi stabilitas export Android; dicatat sebagai O-001 dengan batas SDD-01.
2. Durasi estimasi tahap sengaja tidak dinyatakan dalam satuan waktu; roadmap diukur berdasarkan kriteria keluar.
3. Keputusan konseptual yang belum ditetapkan spesifikasinya (parameter Custom Match, mekanisme star rank, divisi Legenda Nusantara, aturan draft) dicatat sebagai pertanyaan terbuka pada Project Overview agar tidak dijawab dengan asumsi.

## 7. Status Acceptance

Accepted. Persetujuan diberikan pemilik proyek pada 2026-10-30 untuk:

1. Keputusan usulan P-001 dan P-002.
2. Publikasi seluruh file tahap ini ke branch `main` pada GitHub.

## 8. Rekomendasi Tahap Berikutnya

1. Menyelesaikan keputusan O-001 hingga O-004, O-008, dan O-016 pada tahap requirement dan design SDD-01.
2. Memulai SDD-01 (Repository & CI Foundation): inisialisasi proyek Godot 4 pada `game/`, pembuatan workflow validasi, dan penguncian versi.
3. Menjaga lingkup SDD-01 tetap sempit: proyek kosong yang lolos CI, tanpa fitur gameplay.
