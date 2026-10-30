# Laporan Tahap: Batch Spesifikasi Update System & Data Persistence

- Tanggal: 2026-10-30
- Status acceptance: Accepted (disetujui pemilik proyek pada 2026-10-30)

## 1. Scope Pekerjaan

1. Audit repository ASTRANUSA (GitHub dan salinan kerja lokal).
2. Penyusunan lima dokumen: DATA-PERSISTENCE-SPEC, DATA-MIGRATION-SPEC, UPDATE-SYSTEM-SPEC, APK-COMPATIBILITY-SPEC, dan UPDATE-TEST-PLAN.
3. Pencatatan keputusan baru pada Decision Log (P-003 hingga P-006, O-018 hingga O-021).
4. Penambahan rujukan silang pada Roadmap dan README.

Sesuai batasan, tidak ada implementasi kode pada pekerjaan ini; kelima spesifikasi berstatus Approved dan siap menjadi rujukan implementasi.

## 2. File yang Dibuat atau Diubah

| File | Tindakan | Keterangan |
| --- | --- | --- |
| `docs/sdd/specifications/DATA-PERSISTENCE-SPEC.md` | Dibuat | Struktur penyimpanan `user://saves/`, pemisahan kategori data, amplop store, aturan penulisan atomik, dan acceptance criteria. |
| `docs/sdd/specifications/DATA-MIGRATION-SPEC.md` | Dibuat | Versi schema per store, rantai langkah migrasi, cadangan, jurnal migrasi, pemulihan kegagalan, dan anti-migrasi berulang. |
| `docs/sdd/specifications/UPDATE-SYSTEM-SPEC.md` | Dibuat | Model distribusi APK, alur pembaruan end-to-end, pengelolaan aset dengan manifest, urutan boot, dan register risiko kehilangan data. |
| `docs/sdd/specifications/APK-COMPATIBILITY-SPEC.md` | Dibuat | Penguncian `applicationId`, kebijakan versionCode/versionName, signing key, konfigurasi export, dan rancangan workflow build. |
| `docs/sdd/verification/UPDATE-TEST-PLAN.md` | Dibuat | Dua belas skenario pengujian wajib beserta matriks, perkakas, dan rencana otomatisasi CI. |
| `docs/DECISION_LOG.md` | Diubah | Menambah Bagian 2B (P-003 hingga P-006, disetujui) dan empat keputusan terbuka baru (O-018 hingga O-021); O-016 diselesaikan oleh P-005 dan O-009 dipersempit sisa lingkupnya oleh P-006. |
| `docs/ROADMAP.md` | Diubah | Menambah bagian Spesifikasi Sistem Lintas Tahap; kriteria keluar SDD-11 dan SDD-13 diperbarui dengan keputusan O-018, O-020, O-021. |
| `README.md` | Diubah | Menambah baris status batch dan bagian Spesifikasi Sistem. |
| `docs/sdd/reports/SDD-SPEC-UPDATE-SYSTEM-report.md` | Dibuat | Dokumen ini. |

## 3. Keputusan Teknis

Keputusan yang diusulkan dan disetujui pemilik proyek pada 2026-10-30:

1. P-003: `applicationId` dikunci pada `com.ndolzz.astranusa`.
2. P-004: sumber kebenaran versi adalah `game/version.json`; versionCode divalidasi meningkat oleh CI.
3. P-005: versionName mengikuti semantic versioning (menyelesaikan O-016).
4. P-006: store data pemain berformat JSON dengan amplop `schema_version`, checksum SHA-256, dan penulisan atomik (mempersempit O-009 menjadi evaluasi proteksi anti-manipulasi tingkat lanjut).

Keputusan terbuka baru: O-018 (provisioning keystore produksi), O-019 (retensi riwayat pertandingan), O-020 (cakupan aset tambahan rilis awal), O-021 (fallback referensi konten lama).

Perancangan utama: data pemain disimpan pada `user://saves/` yang bertahan pembaruan APK dan tidak pernah disentuh proses aset; migrasi berbasis versi schema per store dengan cadangan sebelum migrasi, jurnal untuk ketahanan gangguan, dan pemulihan otomatis; distribusi pembaruan berupa APK penuh tanpa mekanisme unduh atau pasang otomatis.

## 4. Hasil Pengujian

Pekerjaan ini tidak menghasilkan kode, sehingga tidak terdapat pengujian perangkat lunak. Verifikasi yang dijalankan:

1. Seluruh tautan internal antar dokumen diperiksa; empat kesalahan path relatif rujukan Decision Log ditemukan dan diperbaiki sebelum publikasi.
2. Konsistensi rujukan keputusan (P-xxx dan O-xxx) antar dokumen diperiksa.
3. Skenario pengujian wajib pada permintaan (dua belas skenario) terpetikan lengkap pada UPDATE-TEST-PLAN sebagai T-01 hingga T-12.

## 5. Hasil Audit

1. Branch `main` berada pada commit `66bb6c5` (hasil SDD-00); tidak ada perubahan baru dari pemilik proyek sejak SDD-00, sehingga tidak ada pekerjaan yang tertimpa.
2. Salinan kerja lokal ditemukan kosong (ter-reset oleh lingkungan kerja); seluruh isi dipulihkan dari GitHub sebelum melakukan perubahan, sehingga pengubahan berbasis isi repository terkini.
3. Perubahan pada file yang sudah ada bersifat tambahan terarah: DECISION_LOG (bagian dan baris baru), ROADMAP (bagian dan dua sel tabel), README (baris baru); tidak ada konten lama yang dihapus selain dua sel kriteria keluar yang diperluas.

## 6. Kendala

1. Skenario pengujian pembaruan (T-06 hingga T-12 perangkat) baru dapat dieksekusi setelah ada dua build APK berbeda; repository belum memiliki proyek Godot (menunggu SDD-01).
2. Dokumen menggunakan nama file sesuai permintaan pemilik proyek (misalnya `DATA-PERSISTENCE-SPEC.md`), yang sedikit menyimpang dari konvensi `SPEC-` pada `docs/sdd/README.md`; penyimpangan ini dicatat di sini dan diterima sebagai pengecualian atas permintaan.

## 7. Status Acceptance

Accepted. Persetujuan diberikan pemilik proyek pada 2026-10-30 atas:

1. Keputusan usulan P-003 hingga P-006.
2. Isi kelima dokumen spesifikasi.
3. Publikasi seluruh perubahan batch ini ke branch `main` pada GitHub.

## 8. Rekomendasi Tahap Berikutnya

1. Melanjutkan ke SDD-01 (Repository & CI Foundation) dengan menyerap ketentuan versi dari APK-COMPATIBILITY-SPEC: berkas `game/version.json`, penguncian versi Godot (O-001), dan validasi CI dasar.
2. Implementasi SaveService dan kerangka migrasi dimulai pada SDD-02 dengan merujuk DATA-PERSISTENCE-SPEC dan DATA-MIGRATION-SPEC yang telah disetujui.
3. Menyelesaikan keputusan O-018 (provisioning keystore) sebelum build rilis pertama yang ditandatangani produksi, dan keputusan O-019 hingga O-021 pada tahap batasnya masing-masing.
