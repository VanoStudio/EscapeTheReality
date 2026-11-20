# Log Pertanyaan & Keputusan Desain (GDD vs Implementasi)

Dokumen ini mencatat hal ambigu, kontradiksi, atau keputusan teknis yang diambil selama pengembangan.

| # | Bagian GDD / Prompt | Masalah / Ambiguitas | Keputusan yang Diambil | Alasan Teknis |
|---|---|---|---|---|
| 1 | Konfig Prompt vs Environment | Prompt menyebut `PROJECT_DIR` di `D:\REPO\EscapeTheReality`, tetapi repositori lokal berada di `C:\REPO_GITHUB\EscapeTheReality`. | Menggunakan path `C:\REPO_GITHUB\EscapeTheReality`. | Drive D tidak memiliki folder repo tersebut, sedangkan repositori git aktif berada di drive C. |
| 2 | Konfig Godot Executable | Prompt mencari `*_console.exe` Godot 4.x stable. Godot yang terpasang di sistem adalah versi Steam: `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe` (v4.7.2.stable.steam). | Menggunakan binary Godot Steam dengan wrapper pipe pada script PowerShell. | Godot Steam Windows tidak menyertakan binary terpisah berkas console, tetapi mendukung mode `--headless` jika di-redirect/pipe. |
| 3 | M0 Test Runner | Prompt mengusulkan clone gdUnit4 atau membuat custom runner `tests/run_tests.gd`. | Membuat custom native test runner `tests/run_tests.gd` yang dijalankan via `godot --headless -s`. | gdUnit4 memiliki dependensi addon editor yang berat dan rentan isu versi di Godot 4.7.x, sedangkan native runner berjalan instan dan zero-dependency. |
