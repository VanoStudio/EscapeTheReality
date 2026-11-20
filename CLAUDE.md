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
