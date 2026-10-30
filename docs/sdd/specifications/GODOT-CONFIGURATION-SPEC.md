# GODOT-CONFIGURATION-SPEC: Konfigurasi Proyek Godot dan Export Android

- Status: Approved (disetujui pemilik proyek pada 2026-10-30)
- Sistem: Godot Project Configuration
- Tahap roadmap terikat: SDD-01; mengikat seluruh pengembangan
- Terakhir diperbarui: 2026-10-30

## 1. Tujuan

Mengunci versi engine dan konfigurasi proyek agar pengembangan lokal, CI, dan build APK konsisten serta dapat direproduksi pada setiap mesin.

## 2. Versi Godot (P-007; menyelesaikan O-001)

1. Versi terkunci: Godot 4.7.2-stable (dirilis 18 Agustus 2026; rilis pemeliharaan kedua seri 4.7).
2. Alasan: versi stabil terbaru pada saat keputusan dibuat; seri 4.7 telah melewati dua rilis pemeliharaan sehingga cacat mayor telah ditangani; Godot 4.8 masih beta dan tidak dipakai untuk produksi; pipeline export Android 4.7 memakai JDK 17 dengan template minSdk 24 dan targetSdk 36 yang stabil.
3. Konsekuensi: seluruh mesin pengembangan dan CI memakai editor dan export template 4.7.2; `config/features` pada `project.godot` memuat `4.7`; perubahan versi hanya melalui Decision Log.

## 3. Rendering (D-003)

1. `rendering/renderer/rendering_method="mobile"` berlaku pada seluruh platform.
2. Alasan: Mobile Renderer dioptimalkan untuk GPU perangkat seluler dan selaras dengan target Android kelas menengah.
3. `textures/vram_compression/import_etc2_astc=true` agar tekstur diimpor dengan kompresi ETC2/ASTC yang didukung perangkat seluler.
4. Fitur yang hanya tersedia pada Forward+ tidak digunakan. Opsi Compatibility Renderer untuk perangkat kelas bawah tetap tercatat pada O-017 (SDD-12).

## 4. Orientasi dan Resolusi (P-010)

1. Orientasi: landscape tetap (`window/handheld/orientation=0`). MOBA memerlukan bidang pandang horizontal; orientasi tetap mencegah rotasi tak terduga saat bermain.
2. Viewport dasar: 1280x720, resolusi kelas menengah yang lazim sebagai basis desain UI MOBA.
3. Stretch: `window/stretch/mode="canvas_items"` dan `window/stretch/aspect="expand"`; UI menskalakan penuh dan menoleransi rasio layar serta area notch yang berbeda antar perangkat.
4. Konsekuensi: seluruh UI dirancang pada basis 1280x720; pengujian pada rasio non-16:9 dilakukan mulai tahap UI (SDD-04).

## 5. Konfigurasi Performa Awal

1. Pengaturan performa sengaja minimal pada SDD-01; penyetingaan lanjutan (anggaran frame, memori, culling) dilakukan pada SDD-12 berdasarkan profil perangkat nyata.
2. Yang diterapkan sejak SDD-01: Mobile Renderer, kompresi tekstur ETC2/ASTC, physics tick bawaan 60.
3. Kebijakan alokasi objek dan object pool ditetapkan pada spesifikasi SDD-02.

## 6. Konfigurasi Export Android

1. `applicationId`: `com.ndolzz.astranusa` (P-003); dijaga identik pada preset export dan divalidasi CI.
2. `minSdk` 24 dan `targetSdk` 36: nilai bawaan export template 4.7.2 (P-009). Kelas perangkat QA: Android 8.0 (API 26) kelas menengah ke atas; perangkat di bawah kelas QA dapat memasang aplikasi tetapi tidak dijamin dan tidak diuji.
3. Arsitektur APK debug: `arm64-v8a` dan `armeabi-v7a` aktif. Penyempitan arsitektur untuk rilis dievaluasi pada SDD-13.
4. Preset SDD-01: `Android Debug`, memakai prebuilt template (`gradle_build/use_gradle_build=false`) agar build cepat dan rantai dependensi CI ringan; gradle build dievaluasi pada SDD-13 bila diperlukan.
5. `permissions/internet=false`: ASTRANUSA adalah aplikasi offline; tidak ada izin jaringan yang diperlukan untuk fitur inti (lihat [UPDATE-SYSTEM-SPEC](UPDATE-SYSTEM-SPEC.md)).
6. Keystore debug dibuat per eksekusi CI dengan parameter debug standar Android; APK debug tidak boleh didistribusikan sebagai pembaruan ([APK-COMPATIBILITY-SPEC](APK-COMPATIBILITY-SPEC.md) bagian 6).
7. `version/code` dan `version/name` pada preset disinkronkan dari `game/version.json` oleh `tools/apply_version.gd` sebelum export; nilai pada repository harus tetap identik dengan `version.json` dan dijaga oleh test harness.

## 7. Aturan Penaikan Versi

1. `versionName` mengikuti semantic versioning (P-005): segmen pra-rilis `0.x.y`; `1.0.0` ditetapkan pada rilis publik pertama.
2. PATCH dinaikkan untuk perbaikan; MINOR untuk konten atau fitur; MAJOR untuk perubahan besar.
3. `versionCode` wajib meningkat pada setiap rilis, tidak pernah menurun, dan hanya diubah melalui commit terdokumentasi (P-004).
4. `versionName` wajib konsisten antara `game/version.json`, `CHANGELOG.md`, dan tag rilis.

## 8. Acceptance Criteria

- [x] `project.godot` sesuai konfigurasi terkunci pada bagian 2 hingga 4 (divalidasi oleh test harness).
- [x] `export_presets.cfg` memuat `applicationId` terkunci dan versi identik dengan `version.json` (divalidasi oleh test harness).
- [ ] Hasil export diverifikasi pada artifact APK oleh workflow Android Build (memerlukan eksekusi CI).

## 9. Referensi

- [APK-COMPATIBILITY-SPEC](APK-COMPATIBILITY-SPEC.md)
- [CI-PIPELINE-SPEC](CI-PIPELINE-SPEC.md)
- [FOUNDATION-TEST-PLAN](../verification/FOUNDATION-TEST-PLAN.md)
- [Decision Log](../../DECISION_LOG.md): P-003, P-004, P-005, P-007, P-009, P-010
