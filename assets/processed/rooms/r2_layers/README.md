# R2 (teras, dunia nyata) — 4 lapisan parallax

Semua PNG RGBA 1920×1080, sejajar `bg_r2.png` (diskalakan dari 2752×1536). Susun belakang → depan di titik (0,0).

| File | Isi | Parallax |
|---|---|---|
| `01_back.png` | langit malam, siluet, tembok pagar, gerbang, dinding rumah. Tanpa tiang lampu, 3 kelompok tanaman, jendela, lampu dinding | 0.2 |
| `02_mid.png` | jendela berbingkai + tirai, lampu dinding (sisanya transparan) | 0.5 |
| `03_floor.png` | lantai teras + jalan, tiang lampu, tanaman pot (tempat Kirana jalan) | 1.0 |
| `04_fore.png` | kosong (belum ada objek depan di gambar asli) | 1.2 |

Catatan:
- Komposisi 4 lapisan = aslinya (selisih kecil hanya di tepi objek).
- Tiang lampu & tanaman bawah yang menempel dinding juga ada di `01_back` (bekas inpaint), jadi tidak ada celah saat lapisan bergeser.
- Tepi tiang lampu atas (di langit) dipotong dengan aturan warna, bisa ada halo tipis; [PERLU DICEK di Godot saat parallax bergerak].

## Sumber & deklarasi media AI
- Sumber: `assets/processed/rooms/bg_r2.png` (aset gambar AI proyek).
- Latar kosong dibuat dengan `edit_image` (agy / Nano Banana, AI) menghapus objek; cahaya disamakan dengan skrip. Lapisan lain = piksel asli yang dipotong dengan mask (bukan AI).
- Gambar AI → wajib dideklarasikan untuk lomba/publikasi (tercatat di `CREDITS-AI.md`).
- Skrip: `outputs/k-261123-e2843f/r2f1_layers.py`. Preview: `outputs/k-261123-e2843f/r2-layers-preview.png`.
