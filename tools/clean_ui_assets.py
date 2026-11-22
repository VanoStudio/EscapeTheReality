import numpy as np
from PIL import Image

ui_dir = 'd:/REPO/EscapeTheReality/assets/processed/ui'

# Clean choice_banner.png:
# Any pixel on the outer border that is dark bluish (R<50, G<60, B<90) should be transparent
img_ban = Image.open(f'{ui_dir}/choice_banner.png').convert('RGBA')
arr_ban = np.array(img_ban)
# Clean outer noise
dark_mask = (arr_ban[:, :, 0] < 55) & (arr_ban[:, :, 1] < 65) & (arr_ban[:, :, 2] < 95)
arr_ban[dark_mask, 3] = 0
clean_ban = Image.fromarray(arr_ban)
bbox = clean_ban.getbbox()
if bbox:
    clean_ban = clean_ban.crop(bbox)
clean_ban.save(f'{ui_dir}/choice_banner.png')
print("Cleaned choice_banner.png:", clean_ban.size)

# Create hover version with golden glow / brighter border:
arr_hover = np.array(clean_ban)
# Boost border and fill slightly for hover effect
glow = arr_hover[:, :, 3] > 0
# Warm golden highlight
arr_hover[glow, 0] = np.clip(arr_hover[glow, 0].astype(int) + 20, 0, 255)
arr_hover[glow, 1] = np.clip(arr_hover[glow, 1].astype(int) + 20, 0, 255)
arr_hover[glow, 2] = np.clip(arr_hover[glow, 2].astype(int) + 10, 0, 255)
hover_ban = Image.fromarray(arr_hover)
hover_ban.save(f'{ui_dir}/choice_banner_hover.png')
print("Created choice_banner_hover.png")

# Clean dialog_frame.png:
img_dlg = Image.open(f'{ui_dir}/dialog_frame.png').convert('RGBA')
arr_dlg = np.array(img_dlg)
dark_dlg = (arr_dlg[:, :, 0] < 50) & (arr_dlg[:, :, 1] < 50) & (arr_dlg[:, :, 2] < 85)
arr_dlg[dark_dlg, 3] = 0
clean_dlg = Image.fromarray(arr_dlg)
bbox_dlg = clean_dlg.getbbox()
if bbox_dlg:
    clean_dlg = clean_dlg.crop(bbox_dlg)
clean_dlg.save(f'{ui_dir}/dialog_frame.png')
print("Cleaned dialog_frame.png:", clean_dlg.size)

# Create HUD elements:
# hud_watch (circle) and hud_bar (gold frame)
img_hud = Image.open(f'{ui_dir}/hud_stability_frame.png').convert('RGBA')
arr_hud = np.array(img_hud)
dark_hud = (arr_hud[:, :, 0] < 50) & (arr_hud[:, :, 1] < 50) & (arr_hud[:, :, 2] < 85)
arr_hud[dark_hud, 3] = 0
clean_hud = Image.fromarray(arr_hud)
bbox_hud = clean_hud.getbbox()
if bbox_hud:
    clean_hud = clean_hud.crop(bbox_hud)
clean_hud.save(f'{ui_dir}/hud_stability_frame.png')

# Create clean fill texture for the stability progress bar
# Size: 100 x 20, solid white so modulate can tint it (Teal, Orange, Red)
fill_img = Image.new('RGBA', (32, 32), (255, 255, 255, 255))
fill_img.save(f'{ui_dir}/hud_fill.png')
print("Created hud_fill.png")
