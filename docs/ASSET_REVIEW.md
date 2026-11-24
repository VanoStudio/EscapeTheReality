# Review Aset Visual — untuk Erina

Tanggal review: 23 November 2026. Batas aset final: **27 November** (GDD bagian 12).
Urutan di bawah sudah diurutkan dari yang paling berpengaruh ke tampilan game.

## Aturan umum supaya semua aset menyatu

1. **Satu ukuran piksel untuk semua.** Dunia game berukuran 480×270 lalu diperbesar 4×. Background sekarang punya "1 piksel seni ≈ 1 piksel dunia". Sprite karakter dan prop harus mengikuti ukuran yang sama: **1 piksel seni = 1 piksel di dunia 480×270**, tanpa diperhalus.
2. **Ukuran karakter.** Pintu di background tingginya ±120 px dunia, jadi karakter idealnya **±80 px tinggi**. GDD menulis frame 32×32, tapi itu terlalu kecil untuk skala background sekarang. Usul: **frame 96×96 px, karakter ±80 px tinggi, kaki di baris yang sama di setiap frame**.
3. **Background transparan yang bersih.** Jangan pakai latar magenta/hijau kalau bisa. Kalau terpaksa, pastikan tidak ada pinggiran warna yang tersisa (lihat poin B1).
4. **Garis tepi (outline) dan palet sama** antara Kirana rumah, Kirana fantasi, dan penjual.

## A0. Background yang merusak feel jalan karakter (PALING PENTING)

**Masalah:** beberapa background digambar dengan sudut pandang 3/4 (lantai terlihat dari atas dan dalam, seperti diorama), sedangkan karakter adalah side-view yang berjalan di satu garis lurus. Akibatnya jalur jalan terasa aneh, karakter terlihat "ditempel" atau melayang, dan lantai bawah kosong.

| Ruangan | Kondisi | Perlu dibuat ulang? |
|---|---|---|
| F4 Kamar | Lantai pecah-pecah, Kirana berjalan di atas kehampaan | **Ya, wajib** |
| R1 Ruang tamu | Lantai perspektif makan ±30% layar bawah, kosong | **Ya** |
| R2 Teras | Lantai teras dan halaman perspektif miring | **Ya** |
| F2 Pasar dapur | Pulau lantai oke; panci di tepi kiri/kanan menutupi titik masuk | Sebaiknya (geser panci ke dalam) |
| F3 Tangga | Tangga 3D diagonal hanya dekorasi, lantai jalan oke | Tidak wajib |
| F1, F5 | Sudah cukup pas | Tidak |

**Spesifikasi background baru (side-view):**
- Kamera lurus dari samping, setinggi dada karakter (bukan dari atas). Dinding tampak depan, **lantai hanya berupa strip tipis**.
- Ukuran tetap 2752×1536. **Garis jalan (atas lantai) di y ≈ 1050–1080 px** dari atas gambar (= y 185–190 di dunia 480×270). Strip lantai di bawahnya maksimal ±250 px, sisanya boleh gelap/kehampaan.
- Tepi kiri dan kanan (±340 px dari tiap tepi) **bebas dari perabot setinggi badan**, karena itu titik masuk dan keluar Kirana.
- Perabot yang dipakai sebagai pijakan (rak, pecahan lantai F4) dibuat **sprite terpisah**, jangan menyatu di background.
- Ukuran piksel sama dengan background sekarang (1 piksel seni ≈ 1 piksel dunia).

## A. Prioritas tinggi

### A1. Sprite Kirana versi rumah — `characters/kirana_rumah*.png`
- **Masalah:** gayanya beda dengan Kirana fantasi. Pikselnya jauh lebih halus, outline tipis, proporsinya lebih "anime", sedangkan Kirana fantasi kepalanya besar dan pikselnya tebal. Di layar terlihat seperti dua game berbeda.
- **Minta:** gambar ulang dengan gaya, ukuran piksel, dan proporsi yang **sama persis** dengan Kirana fantasi. Yang beda hanya rambut (sebahu + jepit rambut), baju, dan belum ada jam kalung (GDD bagian 3).
- **Animasi:** idle (4–6 frame) dan walk (6–8 frame). Di rumah Kirana tidak bisa lompat, jadi tidak perlu jump/fall.

### A2. Sprite Kirana versi fantasi — `characters/kirana_fantasi/*`
- **Masalah:** ukuran pikselnya ±1,4 piksel dunia (sedikit lebih kasar dari background), dan walk cycle terasa kaku.
- **Minta (opsional, kalau sempat):** export ulang di frame 96×96 dengan ukuran piksel 1:1 (aturan umum 1–2). Animasi yang sudah ada (idle, walk, jump, fall) tetap dipakai. Kalau tidak sempat, versi sekarang **masih bisa dipakai**.

### A3. Sprite penjual — `characters/penjual.png`
- **Masalah:** sama seperti A1, pikselnya terlalu halus dibanding dunia fantasi.
- **Minta:** gambar ulang dengan ukuran piksel dan outline sama seperti Kirana fantasi. Cukup 1 pose idle (GDD: "1 sprite pixel"). Kalau sempat, tambah 2 frame idle bernapas.

### A4. Background F4 Kamar — `rooms/14-6_ruang_f4_kamar.png`
- **Masalah:** lantai di gambar berupa pecahan papan yang terpisah, tapi tempat berpijak di game adalah lantai rata. Akibatnya Kirana terlihat berjalan di atas kehampaan. Puzzle F4 butuh pijakan di beberapa ketinggian (lantai, atas rak buku, pecahan lantai melayang).
- **Minta:** salah satu dari dua ini.
  1. Background F4 tanpa pecahan lantai (hanya ruangan + kehampaan), lalu **pecahan lantai dan rak buku sebagai sprite terpisah** (ini aset P1–P5 di GDD yang statusnya masih "Belum"). Opsi ini lebih baik.
  2. Background F4 yang lantainya jelas menyambung di bagian bawah, ditambah 2–3 pecahan lantai melayang di ketinggian berbeda.

## B. Prioritas sedang

### B1. Sobekan foto, bingkai kosong, foto utuh — `props/scrap_1-3.png`, `frame_empty.png`, `photo_completed.png`
- **Masalah:** ada **pinggiran magenta/pink** sisa latar chroma key di sekeliling gambar, terlihat jelas di game. Sobekan juga lebih besar dari skala dunia.
- **Minta:** export ulang dengan background transparan bersih. Ukuran sobekan di dunia ±16–20 px, bingkai ±32 px. Tetap 3 sobekan, dan potongannya harus pas membentuk `photo_completed`.

### B2. Jam di lantai teras — `props/ground_watch.png` dan ikon jam
- **Masalah:** jam digambar gaya ilustrasi halus (bukan pixel art) dan ada noda putih di belakangnya. Tidak cocok di teras pixel.
- **Minta:** versi pixel art jam saku emas tergeletak ±16 px dunia, background transparan, tutup berukir dua bintang dan tiga titik di pinggir dial (GDD bagian 3). Kalau sempat, tambah versi bercahaya 2–3 frame untuk denyut.

### B3. Panel opening 2 — `comic/08-2_opening_panel2.png`
- **Masalah:** gambarnya punya bingkai hitam + margin putih sendiri. Di game sudah ada bingkai panel, jadi terlihat dobel.
- **Minta:** export ulang tanpa bingkai (full-bleed), tapi balon kosong di kiri atas tetap ada. Teks balon diisi oleh Godot.

## C. Untuk efek 2.5D (opsional, tapi sangat membantu)

Background sekarang satu gambar datar. Efek kedalaman saat ini dibuat di Godot (cahaya, debu, pecahan siluet di depan, kamera bergeser sedikit). Kalau background dipecah per lapisan, efek parallax bisa jauh lebih kuat.

### C1. Lapisan background per ruangan (mulai dari F1, F2, F5)
Export setiap ruangan sebagai 3 file PNG berukuran sama (2752×1536, area kosong transparan):
1. `*_far.png` — kehampaan ungu-teal, bintang, nebula (paling belakang).
2. `*_mid.png` — rumah/ruangan dan lantai (yang sekarang).
3. `*_near.png` — benda di depan Kirana: tepi pecahan lantai, perabot depan, serpihan melayang dekat kamera.

### C2. Panel komik berlapis (opsional)
Untuk panel 1, 4, dan 6 opening: pisahkan **latar** dan **tokoh** jadi 2 PNG. Kamera 3D bisa menggerakkan keduanya dengan kecepatan beda, ala Live2D.

## D. Sudah bagus — tidak perlu diubah

- Background R1, R2, F1, F2, F3, F5: gaya pixel konsisten, warnanya sesuai moodboard.
- Panel komik opening 1, 3, 4, 5, 6 dan ending 1–2. Ending 2 sudah punya tiga titik di dial dengan titik pertama menyala, pas dengan GDD.
- Potret dialog (Kirana 4 ekspresi, Kirana rumah, adik, penjual).
- UI: frame dialog, banner pilihan, bar stability + ikon jam.
- Bayangan **tidak perlu aset baru**, karena dibuat dari sprite Kirana yang digelapkan lewat shader (GDD bagian 3).

## Cara menyerahkan

Taruh file mentah di `assets/raw/` dengan nama slot GDD yang sama (contoh `14-6_ruang_f4_kamar.png`, `S1_kirana_rumah_walk.png`). Vano akan memproses ke `assets/processed/`.
