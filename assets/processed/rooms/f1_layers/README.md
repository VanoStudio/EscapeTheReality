# F1 (pintu masuk, fantasi) — 4 lapisan parallax

Semua PNG RGBA 1920×1080, sejajar `bg_f1.png` (diskalakan dari 2752×1536). Susun belakang → depan di titik (0,0).

| File | Isi | Parallax |
|---|---|---|
| `01_back.png` | void berbintang penuh (opak), tanpa dinding retak, pintu, jendela/tirai, furnitur, lantai | 0.2 |
| `02_mid.png` | potongan dinding retak, pintu kiri, pintu terbuka tengah, jendela + tirai (transparan di luar objek) | 0.5 |
| `03_floor.png` | papan lantai melayang, furnitur (meja, TV, lemari, serpihan) tempat Kirana jalan | 1.0 |
| `04_fore.png` | kosong (belum ada objek depan di gambar asli) | 1.2 |

Catatan:
- Komposisi 4 lapisan = aslinya (selisih kecil hanya di tepi objek).
- Foto keluarga di sini = piksel asli `bg_f1.png` (belum diganti ke "2 saudari"; hanya R1 yang diganti).
- Pembagian mid/floor memakai poligon manual; tepi bisa kasar. [PERLU DICEK di Godot saat parallax bergerak].

## Sumber & deklarasi media AI
- Sumber: `assets/processed/rooms/bg_f1.png` (aset gambar AI proyek).
- Latar kosong di `01_back` dibuat dengan `edit_image` (agy / Nano Banana, AI). Lapisan lain = piksel asli yang dipotong dengan mask (bukan AI).
- Gambar AI → wajib dideklarasikan untuk lomba/publikasi (tercatat di `CREDITS-AI.md`).
- Skrip: `outputs/k-261123-e2843f/r2f1_layers.py`. Preview: `outputs/k-261123-e2843f/f1-layers-preview.png`.
