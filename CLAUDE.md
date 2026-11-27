# Escape the Reality — Prototype (Hari 1)

## Ringkasan Game (5 Baris)
Escape the Reality adalah game 2D narrative platformer psikologis bertema fantasi emosional.
Pemain mengendalikan Kakak yang kabur dari rumah setelah bertengkar dengan adiknya.
Kakak tersedot jam kalung ke versi rumahnya yang terbelah dan melayang di kehampaan fantasi.
Pemain mengeksplorasi ruangan dan memilih respons dialog yang mengatur bar Emotional Stability (0–100).
Kakak hanya bisa pulang jika berhenti memendam dan berani jujur mengakui perasaannya.

## Perintah Kerja & Eksekusi
- **Run Game**: `& "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"`
- **Test Unit**: `powershell -ExecutionPolicy Bypass -File tools/test.ps1`
- **Smoke Test**: `powershell -ExecutionPolicy Bypass -File tools/smoke.ps1`
- **Screenshot CLI**: `powershell -ExecutionPolicy Bypass -File tools/shot.ps1 -Name <nama> [-Room <kode>] [-Stability <n>]`
- **Bot Autoplay**: `& "C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --bot=<jujur|pendam|sindir|ledak>`

## Aturan Dialog & Teks
- Dialog dan teks naskah disalin persis karakter demi karakter sesuai GDD Bagian 5, 7, dan prompt draf.
- Tidak boleh merapikan tanda baca, menerjemahkan, atau menulis ulang teks.
- Teks draf ditandai dengan field `"draft": true` pada JSON.

## Konvensi Folder & Penamaan
- `scenes/`: Berisi scene `.tscn` (`main.tscn`, `opening.tscn`, `ending.tscn`, `rooms/`, `actors/`, `ui/`).
- `scripts/autoload/`: Script global (`GameState.gd`, `DialogManager.gd`, `RoomManager.gd`, `AudioManager.gd`, `AssetRegistry.gd`).
- `data/dialog/`: File dialog JSON (`prolog.json`, `k1.json`, `k2.json`, `k3.json`, `rooms.json`, `system.json`).
- `data/`: `tuning.tres` dan `names.json`.
- `shaders/`: Shader visual `.gdshader`.
- `assets/processed/`: Aset game dengan prefix kode slot (contoh: `BG1.png`, `F3.png`, `P1.png`, `potret_kakak_kesel.png`).
- `tools/`: Skrip otomasi PowerShell dan Python pipeline.
- `tests/`: Test suite headless dan folder `screenshots/`.
- `docs/`: Dokumen referensi (`GDD_Escape_the_Reality.pdf`, `QUESTIONS.md`, `ASSET_SLOTS.md`, `REPORT_M0-M4.md`).

## Daftar Milestone
- **M0**: Setup project, input map, folder structure, tooling, test runner.
- **M1**: Tuning data, GameState autoload, JSON dialogs, unit test 100% PASS.
- **M2**: AssetRegistry placeholder system, player movement, 7 rooms, RoomManager, camera, CLI debug args.
- **M3**: DialogBox, ChoicePanel, event triggers, loop & rewind, tier visuals, puzzle foto F4, bot autoplay.
- **M4**: Motion comic opening & ending, main & pause menu, AudioManager, Windows export preset, final verification.

## Flow Kirana (rombak, FLOW KIRANA.pdf)
- Alur: opening comic -> `R2` depan rumah (jam muncul, tekan E) -> `F1` rumah dunia lain (portal kanan, Bayangan) -> `F2` pasar Mbok Luna (pilihan makan) -> `P1` menara parkour (4 kertas, zona trauma, menyatu Q) -> ending comic.
- Naskah: `data/dialog/flow.json` (teks tanpa `draft` = persis PDF). Tata letak parkour: `scripts/rooms/p1_layout.gd`.
- Tidak makan = `GameState.has_heavy_legs()` (lompat 0.9x, jalan 0.88x). Layout P1 dicek bisa dilompati di profil ini.
- Angka keseimbangan parkour (fisika, energi, damage, heal, bantuan): `scripts/rooms/p1_layout.gd`. Jangkauan lompatan dites di `tests/m5_test.gd`.
- Energi 0 di P1 -> bangun di F2 (Mbok Luna) lalu portal kembali ke tingkat pecahan berikutnya (pecahan tetap tersimpan).
- Aset: `tools/process_photo_and_sprite.py` (4 pecahan foto + sprite Kirana rumah dari zip), `tools/process_flow_assets.py` (latar, portal, pulau).
- Debug CLI: `--room=<id>`, `--pos=x,y` dan `--shot_delay=<detik>` (dipakai bersama `--shot=`), `--autotest` (R2/F2/P1), `--autotest_collapse` (P1 -> F2), `--debug_papers=N` (P1).
- R1, F3, F4, F5, K2, K3 tidak lagi di jalur utama (file disimpan).

## Main menu & kredit
- Main menu berlapis dari folder MAINMENU zip: `tools/process_menu_assets.py` -> `assets/processed/menu/`. Tombol gaya AAA: `scripts/ui/menu_button_fx.gd`.
- Kredit: satu sumber `data/credits.json`, adegan `scenes/credits.tscn` (dari ending dan tombol KREDIT). Kembali ke menu lewat `RoomManager.go_to_scene` (fade keluar-masuk).
- `--scene=credits` membuka kredit langsung.

## Rombak #4 (Percakapan_Dunia_Lain_Kirana_Adik.pdf)
- K1-K7 = gerbang gema di P1 (`ECHO_GATES` di `p1_layout.gd`, prop `scripts/props/echo_gate.gd`); K8 di depan portal terakhir. Teks persis di `flow.json` bagian `echo`. Hanya Jujur yang membuka; pilihan diacak, energi `ECHO_ENERGY`.
- Checkpoint P1 = `CHECKPOINTS` (hanya maju, dibatasi pecahan yang belum diambil). Jatuh > `DEEP_FALL` di bawah checkpoint = ditarik kembali. Tahan R = kembali ke checkpoint.
- Opening: Enter/klik memunculkan panel "E TO SKIP"; tahan E = langsung ke gameplay.
- F2: Kirana muncul dari kanan, jalur di depan warung (`LANE_Y`), kamera ikut (`owns_camera` membuat RoomFX tidak menggeser kamera). Bayangan hanya muncul saat ada perlu.

## Rombak #5
- Kotak pilihan: `scripts/ui/choice_card.gd` (gambar prosedural) + gaya di `data/choice_style.tres` (`ChoiceStyle`, ubah ukuran/warna/font/animasi lewat Inspector).
- Portal: `face_left` di `portal_gate.gd` (F1 & portal datang F2 = true, Kirana keluar ke kiri).
- F2: setelah Mbok, Bayangan berjalan menghampiri (`_shadow_come`), bicara, lalu kembali & membuka portal (`_shadow_return_and_open`).
- Gerbang gema: tirai shader `shaders/echo_veil.gdshader`; sosok sesuai pembicara naskah (`suara_adik` tanpa sosok, `adik`, `adik_cermin`, `bayangan_adik`). Tanpa kartu "K1:"; diganti bisikan Bayangan `flow.json` `echo_bridge` (draft).
- Finale K8: `FINALE_KIRANA_X`/`FINALE_SHADOW_X` di `p1_layout.gd`; yang bicara Bayangan Adik (sosok terpisah), bukan Bayangan Kirana.

## Build itch.io
- `python tools/build_itch.py` -> `build/itch/EscapeTheReality-windows.zip` (exe, pck tertanam) dan `EscapeTheReality-web.zip` (HTML5, single-threaded, tanpa SharedArrayBuffer).
- Preset di `export_presets.cfg`; template ekspor ikut editor Steam (`editor_data/export_templates/4.7.2.stable`). `assets/raw`, `tests`, `tools`, `docs` tidak ikut diekspor.
- Gambar lukisan besar (komik, potret, latar, menu) di-import lossy WebP 0.9 supaya web pck ~38 MB (itch: maks 200 MB per file). Sprite pixel tetap lossless.
- Di web tombol Keluar (menu utama & pause) disembunyikan (`OS.has_feature("web")`).
