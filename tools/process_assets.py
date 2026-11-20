"""
Pipeline Aset: Memproses raw assets (AI) ke processed/ (GDD Bagian 11)
- Menghapus background magenta #FF00FF atau hijau
- Resize nearest-neighbor: background 480x270, sprite 32x32
- Kunci palet warna maksimal 32 warna
- Potong frame sprite sheet dan sejajarkan baseline kaki
"""
import sys
from pathlib import Path

def main():
    print("Asset pipeline script initialized.")

if __name__ == "__main__":
    main()
