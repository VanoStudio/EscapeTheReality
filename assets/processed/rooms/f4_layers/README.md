# F4 (kamar) — 4 lapisan parallax

Semua PNG RGBA 1920×1080, sejajar `bg_f4.png` (diskalakan dari 2752×1536). Susun belakang → depan di titik (0,0).

| File | Isi | Parallax |
|---|---|---|
| `01_back.png` | latar kosong: void berbintang, dinding retak, pintu, gambar krayon, papan lantai. Tanpa rak, kuda goyang, jam, lampu gantung, 5 bingkai foto | 0.2 |
| `02_mid.png` | rak buku miring + kuda goyang, lampu gantung batik, **5 bingkai foto puzzle (isi tidak diubah, posisi asli)** | 0.5 |
| `03_floor.png` | papan lantai melayang + jam weker dan serpihannya | 1.0 |
| `04_fore.png` | kosong (belum ada objek depan di gambar asli) | 1.2 |

Catatan:
- Bingkai foto/sobekan puzzle ada di `02_mid`, piksel identik dengan aslinya. Hotspot puzzle tetap di koordinat asli.
- Komposisi 4 lapisan = aslinya (selisih kecil hanya di tepi objek).
- Papan lantai juga ada di `01_back` (duplikat), jadi tidak ada celah saat lapisan bergeser.
- Sisa halo tipis di sekitar jam & lampu (terang di latar kosong); [PERLU DICEK di Godot saat parallax bergerak].

## Sumber & deklarasi media AI
- Sumber: `assets/processed/rooms/bg_f4.png` (aset gambar AI proyek).
- Latar kosong di `01_back` dibuat dengan `edit_image` (agy / Nano Banana, AI) menghapus objek; cahaya disamakan dengan skrip. Lapisan lain = piksel asli yang dipotong dengan mask (bukan AI).
- Gambar AI → wajib dideklarasikan untuk lomba/publikasi (tercatat di `CREDITS-AI.md`).
- Skrip: `outputs/k-261123-e2843f/f45_layers.py` (+ `f4_fix.py`).
