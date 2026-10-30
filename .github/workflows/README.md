# Rencana Workflow GitHub Actions

Direktori ini akan berisi definisi workflow CI/CD. Tidak ada file YAML yang dibuat pada tahap SDD-00 karena implementasi CI/CD merupakan lingkup tahap SDD-01, setelah spesifikasinya disetujui. Dokumen ini berfungsi sebagai rencana kerja.

## Workflow yang Direncanakan

| ID Sementara | Nama Workflow | Tujuan | Pemicu Rencana |
| --- | --- | --- | --- |
| W1 | validate-structure | Memastikan struktur repository dan proyek Godot sesuai ketentuan desain. | Push dan pull request. |
| W2 | gdscript-check | Pemeriksaan error dan konvensi kode GDScript secara headless. | Push dan pull request. |
| W3 | automated-tests | Menjalankan unit test, integration test, dan smoke test secara headless. | Push dan pull request. |
| W4 | validate-config | Validasi data konfigurasi (JSON dan Godot Resources) terhadap skema. | Push dan pull request, serta ketika file konfigurasi berubah. |
| W5 | export-android | Export APK Android dan menyimpannya sebagai workflow artifact. | Push ke `main` dan manual dispatch. |

## Prinsip Workflow

1. Seluruh versi Godot, export template, dan GitHub Actions dikunci agar build konsisten dan dapat direproduksi.
2. Tidak ada kredensial (keystore, password) yang disimpan pada repository; seluruhnya melalui GitHub Secrets.
3. Artifact APK disimpan sebagai workflow artifact, bukan pada repository.
4. Komposisi final workflow (apakah digabung atau dipisah per tujuan) ditetapkan pada desain SDD-01.
