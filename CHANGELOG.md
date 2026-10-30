# Changelog

Seluruh perubahan penting proyek ASTRANUSA didokumentasikan pada berkas ini. Skema versi mengikuti semantic versioning (P-005) dengan segmen pra-rilis `0.x.y`; setiap rilis memuat ringkasan perubahan yang dipakai sebagai lampiran artifact APK oleh workflow Android Build.

## [0.1.0] - 2026-10-30

### Ditambahkan

- Inisialisasi proyek Godot 4.7.2-stable pada `game/` (SDD-01).
- Metadata versi `game/version.json` (versionCode 1, versionName 0.1.0) sebagai sumber kebenaran versi (P-004).
- Konfigurasi proyek: Mobile Renderer, orientasi landscape, viewport dasar 1280x720, stretch canvas_items/expand (P-010).
- Preset export Android Debug dengan applicationId `com.ndolzz.astranusa` (P-003, P-009).
- Scene boot minimal beserta pembaca metadata versi untuk smoke test perangkat.
- Test harness fondasi `game/tests/foundation_tests.gd` (P-008).
- Skrip penyinkron versi `game/tools/apply_version.gd` untuk export headless.
- Workflow GitHub Actions `Validation` dan `Android Build` dengan toolchain terkunci (P-012).
- Spesifikasi SDD-01: struktur repository, konfigurasi Godot, pipeline CI, dan rencana pengujian fondasi.
