# F5 (ruang ingatan) — 4 lapisan parallax

Semua PNG RGBA 1920×1080, sejajar `bg_f5.png` (diskalakan dari 2752×1536). Susun belakang → depan di titik (0,0).

| File | Isi | Parallax |
|---|---|---|
| `01_back.png` | dinding, 2 pintu, jendela + tirai, lantai kayu, cahaya dinding. Tanpa furnitur & foto | 0.2 |
| `02_mid.png` | 4 bingkai potret di dinding | 0.5 |
| `03_floor.png` | meja samping + lampu batik, lemari TV + TV miring, tanaman pot, bayangan lantai | 1.0 |
| `04_fore.png` | benda melayang: kertas, pulpen, cangkir + percikan air, remote | 1.2 |

Catatan:
- Furnitur juga ada di `01_back`? Tidak: `01_back` kosong di area itu. Saat lapisan bergeser berbeda, celah kecil di tepi objek bisa terlihat; [PERLU DICEK di Godot].
- Kertas kiri bertumpuk dengan lampu; lampu tetap utuh di `03_floor` (duplikat piksel di `04_fore`).
- Komposisi 4 lapisan = aslinya (selisih kecil hanya di tepi objek).

## Sumber & deklarasi media AI
- Sumber: `assets/processed/rooms/bg_f5.png` (aset gambar AI proyek).
- Latar kosong `01_back` dibuat dengan `edit_image` (agy / Nano Banana, AI); cahaya disamakan dengan skrip. Lapisan lain = piksel asli dipotong dengan mask.
- Gambar AI → wajib dideklarasikan untuk lomba/publikasi (tercatat di `CREDITS-AI.md`).
- Skrip: `outputs/k-261123-e2843f/f45_layers.py`.
