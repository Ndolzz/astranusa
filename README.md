# ASTRANUSA

ASTRANUSA adalah game MOBA 5v5 offline melawan AI bot dengan inspirasi mitologi, legenda, dan budaya Nusantara. Proyek ini dikembangkan dengan Godot 4.7.2 untuk platform Android, menggunakan pendekatan Spec-Driven Development (SDD).

## Status Proyek

| Tahap | Deskripsi | Status |
| --- | --- | --- |
| SDD-00 | Project Foundation | Accepted (2026-10-30) |
| SPEC Batch | Update System & Data Persistence | Approved (2026-10-30) |
| SDD-01 | Repository & CI Foundation | Accepted (2026-10-30) |

## Dokumentasi

- [Project Overview](docs/PROJECT_OVERVIEW.md) — konsep game, mode, konten, dan target rilis awal.
- [Technical Architecture](docs/TECHNICAL_ARCHITECTURE.md) — arsitektur teknis awal dan rencana CI/CD.
- [Decision Log](docs/DECISION_LOG.md) — daftar keputusan teknis beserta status keputusan terbuka.
- [Roadmap](docs/ROADMAP.md) — tahapan implementasi bertahap dari fondasi hingga release candidate.
- [Proses SDD](docs/sdd/README.md) — metodologi, struktur dokumentasi, dan aturan gerbang tahapan.
- [Changelog](CHANGELOG.md) — catatan perubahan versi.
- [Laporan Tahap](docs/sdd/reports/SDD-01-FOUNDATION-REPORT.md) — laporan pekerjaan tahap SDD-01.

## Spesifikasi Sistem

- [DATA-PERSISTENCE-SPEC](docs/sdd/specifications/DATA-PERSISTENCE-SPEC.md) — penyimpanan data pemain yang bertahan pembaruan.
- [DATA-MIGRATION-SPEC](docs/sdd/specifications/DATA-MIGRATION-SPEC.md) — migrasi schema data antar versi.
- [UPDATE-SYSTEM-SPEC](docs/sdd/specifications/UPDATE-SYSTEM-SPEC.md) — alur pembaruan aplikasi dan pengelolaan aset.
- [APK-COMPATIBILITY-SPEC](docs/sdd/specifications/APK-COMPATIBILITY-SPEC.md) — identitas paket, versi, signing, dan workflow build APK.
- [REPOSITORY-STRUCTURE-SPEC](docs/sdd/specifications/REPOSITORY-STRUCTURE-SPEC.md) — struktur repository dan proyek Godot.
- [GODOT-CONFIGURATION-SPEC](docs/sdd/specifications/GODOT-CONFIGURATION-SPEC.md) — konfigurasi proyek Godot dan export Android.
- [CI-PIPELINE-SPEC](docs/sdd/specifications/CI-PIPELINE-SPEC.md) — pipeline validasi dan build APK.
- [UPDATE-TEST-PLAN](docs/sdd/verification/UPDATE-TEST-PLAN.md) — skenario pengujian pembaruan dan persistensi data.
- [FOUNDATION-TEST-PLAN](docs/sdd/verification/FOUNDATION-TEST-PLAN.md) — skenario pengujian fondasi SDD-01.

## Prinsip Pengembangan

1. Setiap fitur diimplementasikan hanya setelah spesifikasi terkait tersedia dan disetujui.
2. Setiap implementasi disertai pengujian otomatis yang berjalan pada GitHub Actions.
3. Tidak ada commit atau push tanpa persetujuan pemilik proyek.
4. Kompatibilitas Android dan efisiensi memori merupakan prioritas teknis utama.
5. Tidak ada dependensi yang tidak diperlukan dan tidak ada layanan berbayar sebagai ketergantungan inti.

## Struktur Repository

```
astranusa/
├── README.md
├── CHANGELOG.md
├── .gitignore
├── docs/                     # Dokumentasi SDD
│   ├── PROJECT_OVERVIEW.md
│   ├── TECHNICAL_ARCHITECTURE.md
│   ├── DECISION_LOG.md
│   ├── ROADMAP.md
│   ├── sdd/                  # Proses, laporan tahap, spesifikasi, dan arsip SDD
│   └── templates/            # Template dokumen SDD
├── game/                     # Root proyek Godot 4.7.2
│   ├── project.godot
│   ├── version.json          # Sumber kebenaran versi
│   ├── export_presets.cfg   # Preset export Android
│   ├── assets/               # Aset game
│   ├── src/                  # Kode sumber (core, app, data, simulation, presentation)
│   ├── tests/                # Test harness dan pengujian otomatis
│   └── tools/                # Skrip headless untuk CI
└── .github/
    └── workflows/            # validation.yml dan android-build.yml
```
