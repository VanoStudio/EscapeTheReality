# R1 (ruang tamu) — 4 lapisan parallax 2.5D

Semua PNG RGBA 1920×1080, posisi tetap (tumpuk di (0,0) tanpa offset). Urutan belakang → depan:

| File | Isi |
|---|---|
| `01_back.png` | Dinding, 2 pintu, tirai + jendela, lantai, plus dinding kosong di tempat bingkai/lampu/TV/tanaman. Tidak transparan. |
| `02_mid.png` | 2 bingkai foto di dinding (foto 2 saudari). Selain bingkai transparan. |
| `03_floor.png` | Lantai (opak) + meja lampu, lampu, TV + lemari, tanaman (area Kirana berjalan). Dinding di atasnya transparan. |
| `04_fore.png` | Kosong (transparan penuh), disiapkan untuk objek depan kalau nanti perlu. |

Tumpukan semua lapisan = tampilan asli `bg_r1.png`, tapi foto keluarga diganti jadi 2 saudari (kakak & adik).

## Sumber
- Dasar: `assets/processed/rooms/bg_r1.png` (dinormalkan ke 1920×1080).
- Dinding kosong: dibuat dengan `edit_image` (hapus bingkai/lampu/TV/tanaman), cahaya disesuaikan, tepi tambalan diperhalus lewat skrip Python.
- Foto bingkai: `r1-foto-kakak-1.jpg` (bingkai kiri) dan `r1-foto-adik-1.png` (bingkai kanan), digrayscale + dipikselkan agar cocok dengan gaya.
- Skrip: `outputs/k-261123-e2843f/r1_layers.py` → `r1_layers2.py` → `r1_clean.py`.

## Deklarasi media AI
Dinding kosong, foto kakak, dan foto adik dihasilkan/diedit dengan AI (agy / Nano Banana). Pakai untuk lomba/publikasi → wajib dideklarasikan sebagai aset buatan AI. Dicatat juga di `CREDITS-AI.md`. Bukan wajah orang nyata.

## Catatan
- Sisa halus: ada sedikit sisa cahaya samar di dasar dinding kiri lampu (x≈455–500, y≈715); tidak mengganggu di preview.
- `02_mid` memakai posisi bingkai asli (kakak di x=800,y=212; adik di x=990,y=194).
