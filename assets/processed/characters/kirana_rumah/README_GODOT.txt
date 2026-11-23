KIRANA RUMAH — sprite gameplay (idle 12f, walk 12f)
=====================================================

STATUS: strip/frames dibuat oleh tools/build_kirana_rumah.gd. Kalau folder
spritesheets_strip_12x1/ belum ada, skrip belum dijalankan (lihat "Cara bangun").

Format (sama dgn Kirana Fantasi)
- Strip 12x1: 3072x256, sel 256x256, kaki di baseline y=240.
- Tinggi badan ~208 px (fantasi idle frame_01 = 209).
- Grid piksel native 64x64, 1 piksel native = 4 px sel (nearest, tanpa anti-alias).
- Animasi (kirana_fantasy_frames.tres): idle_rumah (speed 10), walk_rumah (speed 12),
  AtlasTexture 12 region (0..2816 step 256, 256x256).
- scenes/actors/kirana.tscn: skala 0.35 dipakai bersama fantasi -> ukuran sama.

Sumber / hak cipta
- Konsep: media AI (dibuat dgn tool generate_image / agy, Antigravity), dideklarasikan.
  File asal: assets/raw/characters/kirana_rumah_konsep2.png (1024px, latar magenta).
- Diolah skrip tools/build_kirana_rumah.gd (chroma-key, downsample, segmen, animasi
  prosedural). Tanpa aset pihak ketiga. Catat di CREDITS.md: "Kirana Rumah — AI (agy) + diolah skrip".

Cara bangun ulang
1. Salin konsep ke assets/raw/characters/kirana_rumah_konsep2.png
   (asal: outputs/k-261123-e2843f/kirana-rumah-chibi-konsep-2.png).
2. godot_run scene tools/build_kirana_rumah.tscn (frames >= 5).
   Argumen opsional: --src= --out= --compare= --preview (preview = tanpa individual_frames & tanpa patch .tres).
3. Skrip menulis strip, individual_frames/, mem-patch kirana_fantasy_frames.tres,
   dan gambar perbandingan ke tools/_preview/perbandingan.png (di-gitignore).
4. Lihat log "BUILD_KIRANA_RUMAH>>" (tinggi, baseline, posisi mata).
