# Proses Spec-Driven Development (SDD)

Dokumen ini mendefinisikan metodologi SDD proyek ASTRANUSA, struktur dokumentasi, konvensi penamaan, dan aturan gerbang antar tahap.

## Tahapan SDD

Setiap sistem atau fitur diimplementasikan melalui tujuh tahap berurutan:

1. Requirement Analysis. Kebutuhan diekstraksi dan didefinisikan, termasuk acceptance criteria. Hasil: dokumen requirement.
2. Technical Design. Solusi teknis dirancang, alternatif dipertimbangkan, risiko diidentifikasi. Hasil: dokumen design.
3. Specification. Antarmuka, perilaku terperinci, penanganan error, dan rencana pengujian ditetapkan. Hasil: dokumen spesifikasi.
4. Implementation. Kode ditulis hanya setelah spesifikasi disetujui.
5. Verification. Pengujian dijalankan dan hasilnya dicatat.
6. Code Audit. Kode diperiksa terhadap spesifikasi, keamanan, dan kualitas.
7. Acceptance. Pemilik proyek menerima atau menolak pekerjaan berdasarkan bukti verifikasi.

## Aturan Gerbang

1. Implementation dilarang sebelum spesifikasi terkait disetujui.
2. Sebuah tahap roadmap (SDD-xx) tidak boleh dimulai sebelum tahap sebelumnya berstatus Accepted.
3. Sebuah fitur tidak boleh dinyatakan selesai tanpa bukti hasil pengujian.
4. Tidak ada commit atau push tanpa persetujuan pemilik proyek.
5. Setiap pekerjaan diakhiri dengan laporan tahap.

## Pemetaan Dokumen ke Direktori

| Jenis Dokumen | Awalan | Direktori |
| --- | --- | --- |
| Requirement | `REQ-` | `docs/sdd/requirements/` |
| Technical Design | `DES-` | `docs/sdd/design/` |
| Specification | `SPEC-` | `docs/sdd/specifications/` |
| Verification (rencana dan hasil pengujian) | `VER-` | `docs/sdd/verification/` |
| Code Audit | `AUD-` | `docs/sdd/audits/` |
| Acceptance | `ACC-` | `docs/sdd/acceptance/` |
| Laporan tahap | `SDD-XX-report.md` | `docs/sdd/reports/` |

Direktori `requirements/`, `design/`, `specifications/`, `verification/`, `audits/`, dan `acceptance/` dibuat pada tahap ketika dokumen pertamanya tersedia, agar repository tidak berisi direktori kosong.

## Konvensi Penamaan Dokumen

1. Identifikasi dokumen: `<AWALAN>-<SISTEM>` dengan `SISTEM` ditulis dalam huruf besar dan camel case tanpa spasi. Contoh: `REQ-COMBAT.md`, `SPEC-AI-STRATEGY.md`.
2. Nama file menggunakan huruf besar untuk identifikasi dan dipisahkan dengan tanda hubung. Contoh: `REQ-RANK.md`, `DES-CONCEALMENT.md`.
3. Laporan tahap menggunakan penomoran roadmap: `SDD-05-report.md`.

## Status Dokumen

Setiap dokumen SDD memiliki salah satu status berikut pada bagian atas dokumen:

- `Draft`: sedang disusun.
- `In Review`: menunggu peninjauan pemilik proyek.
- `Approved`: disetujui dan mengikat; implementasi boleh dilanjutkan.
- `Rejected`: ditolak; alasan wajib dicantumkan.
- `Superseded`: digantikan dokumen lain; tautan pengganti wajib dicantumkan.

## Format Laporan Tahap

Setiap laporan tahap wajib memuat delapan bagian berikut, sesuai ketentuan proyek:

1. Scope pekerjaan.
2. File yang dibuat atau diubah.
3. Keputusan teknis.
4. Hasil pengujian.
5. Hasil audit.
6. Kendala.
7. Status acceptance.
8. Rekomendasi tahap berikutnya.

Template tersedia pada [TEMPLATE-REPORT](../templates/TEMPLATE-REPORT.md).

## Template Dokumen

- [TEMPLATE-REQ](../templates/TEMPLATE-REQ.md) untuk requirement analysis.
- [TEMPLATE-DESIGN](../templates/TEMPLATE-DESIGN.md) untuk technical design.
- [TEMPLATE-SPEC](../templates/TEMPLATE-SPEC.md) untuk specification.
- [TEMPLATE-REPORT](../templates/TEMPLATE-REPORT.md) untuk laporan tahap.

## Dokumen Fondasi

- [Project Overview](../PROJECT_OVERVIEW.md)
- [Technical Architecture](../TECHNICAL_ARCHITECTURE.md)
- [Decision Log](../DECISION_LOG.md)
- [Roadmap](../ROADMAP.md)
