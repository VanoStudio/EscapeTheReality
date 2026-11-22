========================================================================
KIRANA (DUNIA FANTASI) - SPRITESHEET ANIMASI GAMEPLAY GODOT 4 (LENGKAP)
========================================================================

Proyek: Escape the Reality - Prototype Hari 1 (Tugas Akhir)
Karakter: Kirana (Versi Dunia Fantasi dengan Kalung Jam Emas)
Style: 16-bit Chibi Pixel Art (~2.5 heads tall)

SELURUH 4 STATE ANIMASI MEMILIKI UKURAN KANVAS & SKALA 100% IDENTIK:
1. `idle_12f.png` : 12 Frame loop (napas halus, kedip mata, ayunan rambut/pita)
2. `walk_12f.png` : 12 Frame loop (siklus jalan lengkap, ayunan lengan & gaun)
3. `jump_12f.png` : 12 Frame (persiapan jongkok, loncatan, melayang di puncak)
4. `fall_12f.png` : 12 Frame (siklus jatuh melayang, landing impact crouch, berdiri)

STRUKTUR FOLDER:
├── spritesheets_strip_12x1/     <- STRIP HORIZONTAL UTAMA (TRANSPARAN)
│   ├── idle_12f.png             (3072 x 256 px, 12 sel x 256x256)
│   ├── walk_12f.png             (3072 x 256 px, 12 sel x 256x256)
│   ├── jump_12f.png             (3072 x 256 px, 12 sel x 256x256)
│   └── fall_12f.png             (3072 x 256 px, 12 sel x 256x256)
│
├── spritesheets_native_32x32/   <- VERSI NATIVE 32x32 PIXEL (384 x 32 px)
│   ├── idle_32x32.png
│   ├── walk_32x32.png
│   ├── jump_32x32.png
│   └── fall_32x32.png
│
└── individual_frames/           <- FRAME SATUAN PNG TRANSPARAN
    ├── idle/  (frame_01.png s/d frame_12.png)
    ├── walk/  (frame_01.png s/d frame_12.png)
    ├── jump/  (frame_01.png s/d frame_12.png)
    └── fall/  (frame_01.png s/d frame_12.png)

PANDUAN SETTING DI GODOT 4 (AnimatedSprite2D):
1. Salin folder ke direktori proyek: `res://assets/processed/characters/kirana_fantasi/`.
2. Di Inspector AnimatedSprite2D, atur `Texture Filter` = `Nearest` (wajib untuk pixel art).
3. Buka tab SpriteFrames di panel bawah:
   - Buat 4 animasi: "idle", "walk", "jump", "fall".
   - Klik ikon grid ("Add frames from a Sprite Sheet").
   - Pilih file strip (misal `walk_12f.png` atau `walk_32x32.png`).
   - Masukkan pengaturan potong:
       Horizontal: 12
       Vertical:   1
   - Klik "Select All Frames" -> "Add 12 Frame(s)".
   - Set Speed animasi ke 10 atau 12 FPS.
