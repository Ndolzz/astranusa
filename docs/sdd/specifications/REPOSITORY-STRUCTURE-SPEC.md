# REPOSITORY-STRUCTURE-SPEC: Struktur Repository dan Proyek Godot

- Status: Approved (disetujui pemilik proyek pada 2026-10-30)
- Sistem: Repository Layout
- Tahap roadmap terikat: SDD-01; mengikat seluruh tahap berikutnya
- Terakhir diperbarui: 2026-10-31

## 1. Tujuan

Menetapkan struktur direktori repository secara final agar setiap sistem memiliki tempat yang jelas, terpisah dari dokumentasi, mudah diaudit, dan dapat divalidasi otomatis oleh CI.

## 2. Ruang Lingkup

Dalam lingkup: tata letak root repository, struktur internal `game/`, aturan penamaan berkas, aturan pembuatan direktori bertahap, dan subset struktur wajib yang divalidasi oleh test harness fondasi.

Di luar lingkup: arsitektur lapisan kode (lihat [Technical Architecture](../../TECHNICAL_ARCHITECTURE.md)) dan konfigurasi engine (lihat [GODOT-CONFIGURATION-SPEC](GODOT-CONFIGURATION-SPEC.md)).

## 3. Struktur Root Repository

```
astranusa/
├── README.md                 # Ringkasan proyek, status tahap, indeks dokumentasi.
├── CHANGELOG.md              # Catatan perubahan versi (P-005).
├── .gitignore
├── docs/                     # Seluruh dokumentasi SDD; tidak ada di dalam game/.
│   ├── PROJECT_OVERVIEW.md
│   ├── TECHNICAL_ARCHITECTURE.md
│   ├── DECISION_LOG.md
│   ├── ROADMAP.md
│   ├── sdd/
│   │   ├── specifications/   # Spesifikasi sistem.
│   │   ├── verification/    # Rencana dan hasil pengujian.
│   │   └── reports/         # Laporan tahap.
│   └── templates/
├── game/                     # Root proyek Godot 4.7.2 (P-001, P-007).
└── .github/
    └── workflows/            # validation.yml dan android-build.yml.
```

Ketentuan:

1. Dokumentasi tidak ditempatkan di dalam `game/` (P-001).
2. `game/version.json` adalah satu-satunya sumber kebenaran versi (P-004).
3. Direktori `docs/sdd/requirements/`, `technical-design/`, `audits/`, dan `acceptance/` dibuat ketika dokumen pertamanya tersedia, sesuai [Proses SDD](../README.md); tidak ada direktori kosong.

## 4. Struktur Internal game/

Struktur berikut adalah target arsitektur final. Direktori dibuat hanya ketika berkas pertamanya tersedia pada tahap yang berwenang; tidak ada direktori kosong dan tidak ada berkas pengisi.

```
game/
├── project.godot             # Konfigurasi proyek.
├── version.json              # Sumber kebenaran versi (P-004).
├── export_presets.cfg        # Preset export Android.
├── .gdlintrc                 # Konfigurasi lint GDScript (P-011).
├── assets/                   # Aset: ikon, art, audio, font, theme UI.
├── config/                   # Data JSON: heroes, items, emblems, spells, ranks, nicknames.
├── src/
│   ├── core/                 # Layanan generik: event bus, save, config, state machine, pool.
│   ├── app/                  # Scene routing dan mode controller.
│   ├── data/                 # Loader dan validator data konfigurasi.
│   ├── simulation/           # Logika pertandingan headless.
│   │   ├── match/            # Siklus pertandingan dan aturan menang.
│   │   ├── units/            # Hero, minion, turret, monster.
│   │   ├── combat/           # Damage pipeline dan status effect.
│   │   ├── abilities/        # Framework skill: passive, S1, S2, Ultimate.
│   │   ├── systems/          # Ekonomi, respawn, concealment, objektif.
│   │   └── ai/               # AI berlapis.
│   └── presentation/         # Lobby, HUD, komponen UI bersama.
│       ├── lobby/
│       ├── match_ui/
│       └── shared/
├── tests/                    # Test harness dan pengujian otomatis.
└── tools/                    # Skrip headless untuk CI; bukan runtime game.
```

## 5. Jadwal Pembuatan Direktori

| Direktori | Tahap Pembuatan | Isi Pertama |
| --- | --- | --- |
| `assets/` | SDD-01 | `icon.svg`. |
| `src/core/` | SDD-01 | `app_version.gd`. |
| `src/app/` | SDD-01 | `boot.gd`, `boot.tscn` (scene smoke, bukan gameplay). |
| `tests/` | SDD-01 | `foundation_tests.gd`. |
| `tools/` | SDD-01 | `apply_version.gd`. |
| `src/data/`, `config/` | SDD-03 | Skema dan validator data konfigurasi. |
| `src/presentation/` | SDD-04 | Lobby shell. |
| `src/simulation/` | SDD-05 | Match skeleton. |
| `src/simulation/ai/` | SDD-08 | AI berlapis. |

## 6. Aturan Penamaan

1. Skrip GDScript: `snake_case.gd`; nama kelas global (`class_name`) menggunakan PascalCase.
2. Scene: `PascalCase.tscn`.
3. Data JSON pada `config/`: lowercase dengan tanda hubung, contoh `heroes.json`.
4. Test harness: `<lingkup>_tests.gd`.
5. Skrip tools: kata kerja dan objek, contoh `apply_version.gd`.
6. Penamaan teknis berbahasa Inggris; narasi dokumentasi berbahasa Indonesia.

## 7. Aturan Isi

1. Tidak ada direktori atau berkas kosong yang dibuat hanya untuk memenuhi struktur.
2. Subset direktori wajib tahap berjalan divalidasi oleh test harness fondasi pada CI.
3. `tests/` dan `tools/` dikecualikan dari export APK melalui `exclude_filter` pada preset export.

## 8. Acceptance Criteria

- [x] Struktur root repository sesuai bagian 3.
- [x] Struktur `game/` sesuai jadwal bagian 5 untuk cakupan SDD-01.
- [x] Tidak ada direktori kosong yang dipertahankan untuk memenuhi struktur.
- [x] Test harness fondasi memvalidasi direktori wajib SDD-01 (diverifikasi pada CI).

## 9. Referensi

- [GODOT-CONFIGURATION-SPEC](GODOT-CONFIGURATION-SPEC.md)
- [CI-PIPELINE-SPEC](CI-PIPELINE-SPEC.md)
- [FOUNDATION-TEST-PLAN](../verification/FOUNDATION-TEST-PLAN.md)
- [Decision Log](../../DECISION_LOG.md): P-001, P-004, P-007, P-011
