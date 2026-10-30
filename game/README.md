# Direktori game/

Root proyek Godot 4.7.2-stable (P-001, P-007). Struktur lengkap, aturan penamaan, dan jadwal pembuatan direktori ditetapkan pada [REPOSITORY-STRUCTURE-SPEC](../docs/sdd/specifications/REPOSITORY-STRUCTURE-SPEC.md). Konfigurasi engine dan export ditetapkan pada [GODOT-CONFIGURATION-SPEC](../docs/sdd/specifications/GODOT-CONFIGURATION-SPEC.md).

## Isi Saat Ini (SDD-01)

```
game/
├── project.godot           # Konfigurasi proyek (Mobile Renderer, landscape, 1280x720)
├── version.json            # Sumber kebenaran versi (P-004)
├── export_presets.cfg     # Preset export Android Debug (applicationId com.ndolzz.astranusa)
├── .gdlintrc               # Konfigurasi lint GDScript (P-011)
├── assets/
│   └── icon.svg            # Ikon proyek (orisinal)
├── src/
│   ├── core/
│   │   └── app_version.gd  # Pembaca dan validator metadata versi
│   └── app/
│       ├── boot.gd         # Skrip scene boot (smoke test, bukan gameplay)
│       └── boot.tscn      # Scene boot minimal
├── tests/
│   └── foundation_tests.gd # Test harness fondasi (P-008)
└── tools/
    └── apply_version.gd    # Penyinkron versi ke preset export (CI)
```

## Menjalankan Validasi Lokal

1. Gunakan Godot 4.7.2-stable; buka dan impor proyek ini.
2. Jalankan test harness fondasi:
   `godot --headless --script res://tests/foundation_tests.gd`
3. Jalankan lint (memerlukan gdtoolkit 4.5.0):
   `gdlint src tools tests`

## Ketentuan

1. Dokumentasi tidak ditempatkan di dalam direktori ini; seluruh dokumentasi berada pada `docs/`.
2. Gameplay, hero, AI bot, lobby, dan sistem pertandingan tidak diimplementasikan pada tahap SDD-01.
3. `tests/` dan `tools/` dikecualikan dari export APK melalui `exclude_filter` pada preset export.
