# F2 (pasar dapur) — 4 lapisan parallax

Semua PNG RGBA 1920×1080, sejajar `bg_f2.png` (diskalakan dari 2752×1536). Susun belakang → depan di titik (0,0).

| File | Isi | Parallax |
|---|---|---|
| `01_back.png` | dinding retak + keramik + lantai kayu + void bertabur serpihan. Tanpa lentera, rak, wajan, kompor, guci, toples, periuk (diisi latar kosong, cahaya disamakan) | 0.2 |
| `02_mid.png` | 2 gugus lentera, rak piring + toples, rak wajan gantung (menempel di dinding) | 0.5 |
| `03_floor.png` | lantai kayu + papan pecah, meja dapur, kompor, guci tanah, toples + tumpukan piring (tempat Kirana jalan & lompat) | 1.0 |
| `04_fore.png` | 2 periuk besar kiri & kanan | 1.2 |

Catatan:
- `02_mid` v2: tepi dibersihkan dari halo (mask dihitung dari beda warna terhadap latar kosong, dikikis 1 px, warna tepi diganti warna piksel dalam terdekat). Isi di sela lentera/rak tetap piksel asli (dinding) supaya tidak bolong.
- Masih ada sisa tepi persegi tipis (dinding beige/teal) di sekitar lentera kiri dan atas rak; garis teal samar di sekitar lentera kiri memang ada di gambar aslinya. [PERLU DICEK di Godot].
- Saat lapisan bergeser berbeda, celah kecil di tepi objek bisa terlihat.
- Komposisi 4 lapisan ≈ aslinya (selisih besar hanya di tepi objek).

## Sumber & deklarasi media AI
- Sumber: `assets/processed/rooms/bg_f2.png` (aset gambar AI proyek).
- Latar kosong untuk `01_back` dibuat dengan `edit_image` (agy / Nano Banana, AI, `empty_f2.png`); cahaya disamakan dengan skrip. Lapisan lain = piksel asli dipotong dengan mask (GrabCut + beda warna).
- Gambar AI → wajib dideklarasikan untuk lomba/publikasi (tercatat di `CREDITS-AI.md`).
- Skrip: `outputs/k-261123-e2843f/f2_layers2.py`.
