import os
import numpy as np
from PIL import Image

props_dir = 'd:/REPO/EscapeTheReality/assets/processed/props'
ui_dir = 'd:/REPO/EscapeTheReality/assets/processed/ui'
os.makedirs(props_dir, exist_ok=True)
os.makedirs(ui_dir, exist_ok=True)

# ==========================================
# 1. PROCESS 17_sobekan_foto.png
# ==========================================
img_foto = Image.open('d:/REPO/EscapeTheReality/ESCAPE THE REALITY ASSETS/15-17/17_sobekan_foto.png').convert('RGBA')
arr = np.array(img_foto)

# Magenta mask: R > 170, G < 70, B > 170
mask = (arr[:, :, 0] > 170) & (arr[:, :, 1] < 70) & (arr[:, :, 2] > 170)
arr[mask, 3] = 0

cleaned_foto = Image.fromarray(arr)

# Crop elements:
# Scrap 1: Kirana head top left
# Coordinates in 2752x1536:
# Full photo on left: (165, 135, 1030, 980)
full_photo = cleaned_foto.crop((165, 135, 1030, 980))
full_photo.save(os.path.join(props_dir, 'family_photo_full.png'))

# Scrap 1 (Kirana head):
scrap1 = cleaned_foto.crop((1190, 135, 1550, 580))
bbox1 = scrap1.getbbox()
if bbox1: scrap1 = scrap1.crop(bbox1)
scrap1.save(os.path.join(props_dir, 'scrap_1.png'))

# Scrap 2 (Adik head):
scrap2 = cleaned_foto.crop((1560, 290, 1850, 700))
bbox2 = scrap2.getbbox()
if bbox2: scrap2 = scrap2.crop(bbox2)
scrap2.save(os.path.join(props_dir, 'scrap_2.png'))

# Scrap 3 (Holding hands bottom):
scrap3 = cleaned_foto.crop((1200, 780, 1830, 1370))
bbox3 = scrap3.getbbox()
if bbox3: scrap3 = scrap3.crop(bbox3)
scrap3.save(os.path.join(props_dir, 'scrap_3.png'))

# Frame Empty (top right):
frame_empty = cleaned_foto.crop((1930, 140, 2620, 690))
bbox_fe = frame_empty.getbbox()
if bbox_fe: frame_empty = frame_empty.crop(bbox_fe)
frame_empty.save(os.path.join(props_dir, 'frame_empty.png'))

# Photo Completed in Frame (bottom right):
photo_comp = cleaned_foto.crop((1930, 800, 2650, 1360))
bbox_fc = photo_comp.getbbox()
if bbox_fc: photo_comp = photo_comp.crop(bbox_fc)
photo_comp.save(os.path.join(props_dir, 'photo_completed.png'))

print("Scraps and frames extracted successfully.")

# ==========================================
# 2. PROCESS 06a_desain_jam.png for ground_watch
# ==========================================
img_jam = Image.open('d:/REPO/EscapeTheReality/ESCAPE THE REALITY ASSETS/1-7/06a_desain_jam.png').convert('RGBA')
arr_jam = np.array(img_jam)

# Remove grey background (close to 206, 207, 210)
bg_jam = (arr_jam[:, :, 0] > 195) & (arr_jam[:, :, 0] < 225) & \
         (arr_jam[:, :, 1] > 195) & (arr_jam[:, :, 1] < 225) & \
         (arr_jam[:, :, 2] > 195) & (arr_jam[:, :, 2] < 225)
arr_jam[bg_jam, 3] = 0

cleaned_jam = Image.fromarray(arr_jam)
# 2nd watch is glowing open watch: x: 840..1440, y: 300..1120
watch_glow = cleaned_jam.crop((840, 300, 1440, 1120))
bbox_wg = watch_glow.getbbox()
if bbox_wg: watch_glow = watch_glow.crop(bbox_wg)
# Scale down appropriately for room prop
watch_glow.save(os.path.join(props_dir, 'ground_watch.png'))
print("Ground watch extracted successfully.")

# ==========================================
# 3. PROCESS 16_mockup_dialog.png FOR UI
# ==========================================
img_mock = Image.open('d:/REPO/EscapeTheReality/ESCAPE THE REALITY ASSETS/15-17/16_mockup_dialog.png').convert('RGBA')
# Crop Single Choice Banner
# Look at the 2nd choice banner (completely clear without any background behind corners):
banner = img_mock.crop((1728, 482, 2538, 598))
# Remove the dark blue background outside the banner
arr_ban = np.array(banner)
# Dark teal/blue background is around R < 35, G < 35, B < 65
bg_ban = (arr_ban[:, :, 0] < 45) & (arr_ban[:, :, 1] < 60) & (arr_ban[:, :, 2] < 90)
arr_ban[bg_ban, 3] = 0
banner_clean = Image.fromarray(arr_ban)
banner_clean.save(os.path.join(ui_dir, 'choice_banner.png'))

# Crop HUD watch & bar:
hud_crop = img_mock.crop((44, 48, 622, 196))
arr_hud = np.array(hud_crop)
bg_hud = (arr_hud[:, :, 0] < 45) & (arr_hud[:, :, 1] < 40) & (arr_hud[:, :, 2] < 70)
arr_hud[bg_hud, 3] = 0
hud_clean = Image.fromarray(arr_hud)
hud_clean.save(os.path.join(ui_dir, 'hud_stability_frame.png'))

# Crop Dialog Frame
# Dialog box frame runs from x: 100 to 2650, y: 1060 to 1480
# Notice that left side has grandma portrait cutout. We can create a modular dialog box:
# Or take the frame without portrait by mirroring the right side cog or using the full frame.
dlg_crop = img_mock.crop((100, 1050, 2650, 1480))
arr_dlg = np.array(dlg_crop)
bg_dlg = (arr_dlg[:, :, 0] < 40) & (arr_dlg[:, :, 1] < 40) & (arr_dlg[:, :, 2] < 80)
arr_dlg[bg_dlg, 3] = 0
dlg_clean = Image.fromarray(arr_dlg)
dlg_clean.save(os.path.join(ui_dir, 'dialog_frame.png'))

print("All props and UI extracted successfully!")
