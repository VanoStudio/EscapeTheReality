"""
Pipeline Pemrosesan Aset: Memproses raw assets ke assets/processed/
- Menghapus background magenta #FF00FF pada sobekan foto
- Memotong potret dialog webtoon (Kirana 4 ekspresi, Adik 2 ekspresi, Penjual, Kirana rumah)
- Memotong jam kalung 3 warna
- Menyiapkan background ruangan 7 room
- Menyiapkan komik opening 6 panel & ending 2 panel
"""
import os
import shutil
from pathlib import Path
from PIL import Image
import numpy as np

RAW_DIR = Path("assets/raw")
OUT_DIR = Path("assets/processed")

def ensure_dirs():
    for sub in ["rooms", "comic", "portraits", "props", "characters", "ui"]:
        (OUT_DIR / sub).mkdir(parents=True, exist_ok=True)

def process_rooms():
    room_map = {
        "14-1_ruang_bg1_ruang_tamu.png": "bg_r1.png",
        "14-2_ruang_bg2_teras.png": "bg_r2.png",
        "14-3_ruang_f1_pintu_masuk.png": "bg_f1.png",
        "14-4_ruang_f2_pasar_dapur.png": "bg_f2.png",
        "14-5_ruang_f3_tangga.png": "bg_f3.png",
        "14-6_ruang_f4_kamar.png": "bg_f4.png",
        "14-7_ruang_f5_ingatan.png": "bg_f5.png",
    }
    for src_name, dst_name in room_map.items():
        src_path = RAW_DIR / "rooms" / src_name
        dst_path = OUT_DIR / "rooms" / dst_name
        if src_path.exists():
            shutil.copy2(src_path, dst_path)
    print("Rooms processed.")

def process_comic():
    comic_map = {
        "08-1_opening_panel1.png": "comic_open_1.png",
        "08-2_opening_panel2.png": "comic_open_2.png",
        "08-3_opening_panel3.png": "comic_open_3.png",
        "08-4_opening_panel4.png": "comic_open_4.png",
        "08-5_opening_panel5.png": "comic_open_5.png",
        "08-6_opening_panel6.png": "comic_open_6.png",
        "09-1_ending_panel1.png": "comic_end_1.png",
        "09-2_ending_panel2.png": "comic_end_2.png",
    }
    for src_name, dst_name in comic_map.items():
        src_path = RAW_DIR / "comic" / src_name
        dst_path = OUT_DIR / "comic" / dst_name
        if src_path.exists():
            shutil.copy2(src_path, dst_path)
    print("Comic panels processed.")

def process_photo_scraps():
    src_path = RAW_DIR / "props" / "17_sobekan_foto.png"
    if not src_path.exists():
        return
    img = Image.open(src_path)
    arr = np.array(img.convert("RGBA"))
    
    # Chroma-key magenta removal
    is_magenta = (arr[:, :, 0] > 200) & (arr[:, :, 1] < 50) & (arr[:, :, 2] > 200)
    arr[is_magenta, 3] = 0
    clean_img = Image.fromarray(arr)
    
    # Slice objects:
    # Obj 0: y=[123:615], x=[1189:1562] (scrap 1)
    scrap_1 = clean_img.crop((1189, 123, 1562, 615))
    scrap_1.save(OUT_DIR / "props" / "scrap_1.png")
    
    # Obj 3: y=[314:725], x=[1576:1852] (scrap 2)
    scrap_2 = clean_img.crop((1576, 314, 1852, 725))
    scrap_2.save(OUT_DIR / "props" / "scrap_2.png")
    
    # Obj 4: y=[786:1426], x=[1203:1840] (scrap 3)
    scrap_3 = clean_img.crop((1203, 786, 1840, 1426))
    scrap_3.save(OUT_DIR / "props" / "scrap_3.png")
    
    # Obj 2: y=[149:723], x=[1935:2631] (empty frame)
    frame_empty = clean_img.crop((1935, 149, 2631, 723))
    frame_empty.save(OUT_DIR / "props" / "frame_empty.png")
    
    # Obj 5: y=[826:1420], x=[1935:2655] (framed complete photo)
    photo_done = clean_img.crop((1935, 826, 2655, 1420))
    photo_done.save(OUT_DIR / "props" / "photo_completed.png")
    
    print("Photo scraps sliced with transparency.")

def process_portraits():
    # Kirana 4 expressions sheet: 1024x572
    src_kakak = RAW_DIR / "portraits" / "19_potret_kakak_sheet.png"
    if src_kakak.exists():
        img = Image.open(src_kakak).convert("RGBA")
        expressions = ["biasa", "kesal", "sedih", "lega"]
        for i, expr in enumerate(expressions):
            crop = img.crop((i * 256, 0, (i + 1) * 256, 572))
            crop.save(OUT_DIR / "portraits" / f"portrait_kakak_{expr}.png")
            
    # Kirana rumah
    src_rumah = RAW_DIR / "portraits" / "20_potret_kakak_rumah.png"
    if src_rumah.exists():
        shutil.copy2(src_rumah, OUT_DIR / "portraits" / "portrait_kakak_rumah.png")
        
    # Adik 2 expressions
    src_adik = RAW_DIR / "portraits" / "21_potret_adik.png"
    if src_adik.exists():
        img_adik = Image.open(src_adik)
        # Adik 1 (biasa) & Adik 2 (kaget)
        adik_1 = img_adik.crop((226, 15, 1365, 1536))
        adik_2 = img_adik.crop((1490, 24, 2590, 1513))
        adik_1.save(OUT_DIR / "portraits" / "portrait_adik_biasa.png")
        adik_2.save(OUT_DIR / "portraits" / "portrait_adik_kaget.png")
        
    # Penjual
    src_penjual = RAW_DIR / "portraits" / "22_potret_penjual.png"
    if src_penjual.exists():
        shutil.copy2(src_penjual, OUT_DIR / "portraits" / "portrait_penjual.png")
        
    print("Portraits processed.")

def process_pocket_watches():
    src_watch = RAW_DIR / "props" / "06_jam_3_warna.png"
    if src_watch.exists():
        img = Image.open(src_watch)
        w, h = img.size
        # 3 watches across width:
        # Teal: 0 - 917
        # Orange: 917 - 1834
        # Red: 1834 - 2752
        w_teal = img.crop((0, 0, 917, h))
        w_orange = img.crop((917, 0, 1834, h))
        w_red = img.crop((1834, 0, 2752, h))
        
        w_teal.save(OUT_DIR / "props" / "pocket_watch_teal.png")
        w_orange.save(OUT_DIR / "props" / "pocket_watch_orange.png")
        w_red.save(OUT_DIR / "props" / "pocket_watch_red.png")
        print("Pocket watches processed.")

def main():
    ensure_dirs()
    process_rooms()
    process_comic()
    process_photo_scraps()
    process_portraits()
    process_pocket_watches()
    print("Asset processing complete.")

if __name__ == "__main__":
    main()
