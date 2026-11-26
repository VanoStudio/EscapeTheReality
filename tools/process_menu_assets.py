"""Lapisan main menu dari zip (folder MAINMENU) -> assets/processed/menu/.

Pemakaian:
    python -I tools/process_menu_assets.py "<folder MAINMENU>"

- menu_bg.jpg       latar ruang terbelah + pusaran jam (ccm5r5)
- menu_swirl.jpg    pusaran cahaya di latar hitam (umf0r4)  -> dipakai blend add
- menu_bokeh.jpg    debu bokeh di latar hitam (7pd7wh)      -> blend add
- menu_mist.jpg     kabut di latar hitam (wrr28j)           -> blend add
- menu_frame.png    bingkai depan (xh35dv), latar putih dibuang
- menu_kirana.png   Kirana + jam (w2c3er), latar kotak-kotak palsu dibuang
- menu_logo.png     logo (17g4ou), latar putih dibuang, kilau tepi dijaga
"""
import os
import sys
from collections import deque

from PIL import Image

OUT = "assets/processed/menu"
FILES = {
    "bg": "Gemini_Generated_Image_ccm5r5ccm5r5ccm5.jpeg",
    "swirl": "Gemini_Generated_Image_umf0r4umf0r4umf0.jpeg",
    "bokeh": "Gemini_Generated_Image_7pd7wh7pd7wh7pd7.jpeg",
    "mist": "Gemini_Generated_Image_wrr28jwrr28jwrr2.jpeg",
    "frame": "Gemini_Generated_Image_xh35dvxh35dvxh35.jpeg",
    "kirana": "Gemini_Generated_Image_w2c3erw2c3erw2c3.jpeg",
    "logo": "Gemini_Generated_Image_17g4ou17g4ou17g4.jpeg",
}
WIDTH = 1920


def fit(im, w=WIDTH):
    if im.width <= w:
        return im
    return im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)


def key_white(im, lo, hi):
    """Latar putih -> transparan. min(rgb) >= hi: transparan, <= lo: penuh.
    Warna di-unpremultiply dari putih supaya tepi lembut tidak berkabut."""
    im = im.convert("RGB")
    out = Image.new("RGBA", im.size)
    src = im.load()
    dst = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b = src[x, y]
            m = min(r, g, b)
            a = 1.0 if m <= lo else (0.0 if m >= hi else (hi - m) / (hi - lo))
            if a <= 0.0:
                dst[x, y] = (0, 0, 0, 0)
                continue
            un = lambda c: max(0, min(255, round((c - (1 - a) * 255) / a)))
            dst[x, y] = (un(r), un(g), un(b), round(a * 255))
    return out


def key_checker(im):
    """Latar kotak-kotak abu-abu palsu (dua tingkat abu) -> transparan, flood dari tepi."""
    im = im.convert("RGB")
    w, h = im.size
    px = im.load()
    # Dua tingkat abu kotak-kotak (~60-80 dan ~100-125) berubah-ubah karena kompresi JPEG.
    def is_checker(c):
        return max(c) - min(c) <= 10 and 55 <= c[1] <= 132

    bg = bytearray(w * h)
    q = deque([(x, 0) for x in range(w)] + [(x, h - 1) for x in range(w)] + [(0, y) for y in range(h)] + [(w - 1, y) for y in range(h)])
    while q:
        x, y = q.popleft()
        i = y * w + x
        if bg[i] or not is_checker(px[x, y]):
            continue
        bg[i] = 1
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny * w + nx]:
                q.append((nx, ny))
    # Kantong kotak-kotak yang terkurung (sela rambut & lengan): buang komponen abu >= 300 px.
    seen = bytearray(w * h)
    for y0 in range(h):
        for x0 in range(w):
            i0 = y0 * w + x0
            if bg[i0] or seen[i0] or not is_checker(px[x0, y0]):
                continue
            comp = []
            q2 = deque([(x0, y0)])
            seen[i0] = 1
            while q2:
                x, y = q2.popleft()
                comp.append(y * w + x)
                for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not seen[j] and not bg[j] and is_checker(px[nx, ny]):
                            seen[j] = 1
                            q2.append((nx, ny))
            if len(comp) >= 300:
                for j in comp:
                    bg[j] = 1
    out = Image.new("RGBA", (w, h))
    dst = out.load()
    for y in range(h):
        for x in range(w):
            if not bg[y * w + x]:
                dst[x, y] = px[x, y] + (255,)
    # Tepi 1 px dihaluskan (sisa abu di pinggir rambut).
    a = out.getchannel("A")
    from PIL import ImageFilter
    a = a.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.8))
    out.putalpha(a)
    return out.crop(out.getbbox())


def main():
    src = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    for key in ("bg", "swirl", "bokeh", "mist"):
        fit(Image.open(os.path.join(src, FILES[key])).convert("RGB")).save(os.path.join(OUT, "menu_%s.jpg" % key), quality=92)
        print("saved", key)
    frame = key_white(fit(Image.open(os.path.join(src, FILES["frame"]))), 150, 232)
    frame.save(os.path.join(OUT, "menu_frame.png"))
    print("saved frame", frame.size)
    kirana = key_checker(Image.open(os.path.join(src, FILES["kirana"])))
    kirana = fit(kirana, 1100)
    kirana.save(os.path.join(OUT, "menu_kirana.png"))
    print("saved kirana", kirana.size)
    logo = key_white(Image.open(os.path.join(src, FILES["logo"])), 205, 250)
    logo = logo.crop(logo.getbbox())
    logo = fit(logo, 1100)
    logo.save(os.path.join(OUT, "menu_logo.png"))
    print("saved logo", logo.size)


if __name__ == "__main__":
    main()
