# F3 (tangga berputar) — 4 lapisan parallax

Semua PNG RGBA 1920×1080, sejajar `bg_f3.png` (diskalakan dari 2752×1536). Susun belakang → depan di titik (0,0).

| File | Isi | Parallax |
|---|---|---|
| `01_back.png` | void kosmik ungu–teal bertabur bintang + dinding batu retak, tanpa tangga/pintu/lantai (opak penuh) | 0.2 |
| `02_mid.png` | dekor tengah: ruang melayang atas, tangga miring kanan atas, ruang jauh, ruang tengah, jam saku | 0.5 |
| `03_floor.png` | tempat Kirana berjalan/lompat: lantai kayu panjang, tangga utama kiri & kanan + pendaratan, pintu kiri & kanan, pot + pijakan | 1.0 |
| `04_fore.png` | puing kayu melayang di bawah lantai (transparan di tempat lain) | 1.2 |

Catatan:
- Nama `03_floor.png` (versi lama bernama `03_floor_stairs.png`).
- Tepi mask polygon + warna (hangat) bisa agak kasar di tangga tipis dan puing; [PERLU DICEK di Godot].
- Saat lapisan bergeser berbeda, celah kecil di tepi objek bisa terlihat (latar kosong hasil AI tidak persis sama dengan aslinya di area objek).

## Sumber & deklarasi media AI
- Sumber: `assets/processed/rooms/bg_f3.png` (aset gambar AI proyek).
- **F3 = hasil edit AI**: `01_back` berasal dari `edit_image` (agy / Nano Banana, AI, `f3_empty_raw.png`) yang menghapus tangga, pintu, lantai, ruang melayang, jam, tanaman, dan puing. Lapisan 02–04 = piksel asli dipotong dengan mask polygon + warna.
- Gambar AI → wajib dideklarasikan untuk lomba/publikasi (tercatat di `CREDITS-AI.md`).
- Skrip: `outputs/k-261123-e2843f/f3_layers.py` (dijalankan via `f3_run.py` yang mengganti nama 03).
