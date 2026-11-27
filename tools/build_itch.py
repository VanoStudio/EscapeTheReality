"""Build Windows (.exe) dan Web (HTML5) lalu bungkus jadi zip siap upload ke itch.io.

Pakai:  python tools/build_itch.py
Hasil:  build/itch/EscapeTheReality-windows.zip  dan  build/itch/EscapeTheReality-web.zip
"""
import os
import subprocess
import sys
import zipfile

GODOT = r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")

TARGETS = [
    ("Windows Desktop", os.path.join(BUILD, "windows", "EscapeTheReality.exe"), "EscapeTheReality-windows.zip"),
    ("Web", os.path.join(BUILD, "web", "index.html"), "EscapeTheReality-web.zip"),
]


def main() -> int:
    os.makedirs(os.path.join(BUILD, "itch"), exist_ok=True)
    # Supaya Godot tidak meng-import isi folder build sebagai aset proyek.
    open(os.path.join(BUILD, ".gdignore"), "a").close()
    for preset, out, zip_name in TARGETS:
        os.makedirs(os.path.dirname(out), exist_ok=True)
        print("== export", preset)
        r = subprocess.run([GODOT, "--headless", "--path", ROOT, "--export-release", preset, out])
        if r.returncode != 0 or not os.path.exists(out):
            print("export gagal:", preset)
            return 1
        src = os.path.dirname(out)
        zpath = os.path.join(BUILD, "itch", zip_name)
        with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as z:
            for name in sorted(os.listdir(src)):
                if name.endswith(".import"):
                    continue
                z.write(os.path.join(src, name), name)
        print("   ", zpath, os.path.getsize(zpath) // 1_000_000, "MB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
