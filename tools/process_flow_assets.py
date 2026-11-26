"""Proses aset flow Kirana (rombak FLOW KIRANA.pdf).

Pemakaian:
    python -I tools/process_flow_assets.py "<folder ASSET BARU>" assets/processed/flow

- Background ruangan disalin apa adanya (jpg) dengan nama tetap.
- PORTAL.jpeg: latar magenta dibuang (chroma key + despill) -> portal.png transparan.
- Platform parkour (image (3).png, image (4).png): latar abu-abu dibuang lewat flood fill
  dari tepi, lalu tiap pulau dipotong jadi sprite sendiri (platform_*.png).
"""
import os
import shutil
import sys
from collections import deque

from PIL import Image

BACKGROUNDS = {
    "ASSET RUMAH BIASA/RUMAH BARU DILUAR (DUNIA NYATA).jpeg": "bg_front_house.jpg",
    "ASSET RUMAH DI DUNIA LAIN/di dalem rumah dunia laen.jpeg": "bg_arrival.jpg",
    "ASSET RUMAH DI DUNIA LAIN/tanpa portal.jpeg": "bg_market.jpg",
    "parkour/Gemini_Generated_Image_3nu3533nu3533nu3.jpeg": "bg_space.jpg",
}


def key_magenta(src: str, dst: str, height: int) -> None:
    im = Image.open(src).convert("RGB")
    w, h = im.size
    px = im.load()
    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            m = min(r, b) - g  # seberapa "magenta"
            if m > 110:
                op[x, y] = (0, 0, 0, 0)
                continue
            a = 255
            if m > 40:
                a = int(255 * (110 - m) / 70)
                # despill: buang rona magenta di tepi
                r = min(r, g + 40)
                b = min(b, g + 90)
            op[x, y] = (r, g, b, a)
    bbox = out.getbbox()
    if bbox:
        out = out.crop(bbox)
    k = height / out.height
    out = out.resize((max(1, int(out.width * k)), height), Image.LANCZOS)
    out.save(dst)
    print("portal ->", dst, out.size)


def similar(c1, c2, tol):
    return abs(c1[0] - c2[0]) <= tol and abs(c1[1] - c2[1]) <= tol and abs(c1[2] - c2[2]) <= tol


def cut_platforms(src: str, prefix: str, out_dir: str, tol: int = 18) -> list:
    im = Image.open(src).convert("RGB")
    w, h = im.size
    px = im.load()
    bg = px[2, 2]
    is_bg = bytearray(w * h)
    q = deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        i = y * w + x
        if is_bg[i]:
            continue
        if not similar(px[x, y], bg, tol):
            continue
        is_bg[i] = 1
        if x > 0:
            q.append((x - 1, y))
        if x < w - 1:
            q.append((x + 1, y))
        if y > 0:
            q.append((x, y - 1))
        if y < h - 1:
            q.append((x, y + 1))

    # Komponen terhubung (bukan latar).
    label = [0] * (w * h)
    comps = []
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if is_bg[i] or label[i]:
                continue
            cid = len(comps) + 1
            minx, miny, maxx, maxy, n = x, y, x, y, 0
            q = deque([(x, y)])
            label[i] = cid
            while q:
                cx, cy = q.popleft()
                n += 1
                minx = min(minx, cx)
                maxx = max(maxx, cx)
                miny = min(miny, cy)
                maxy = max(maxy, cy)
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not is_bg[j] and not label[j]:
                            label[j] = cid
                            q.append((nx, ny))
            comps.append([minx, miny, maxx, maxy, n])

    big = [c for c in comps if c[4] > 4000]
    # Pecahan batu kecil di bawah pulau digabung ke pulau terdekat.
    for c in comps:
        if c[4] > 4000:
            continue
        cx = (c[0] + c[2]) / 2
        best = None
        for b in big:
            if b[0] - 30 <= cx <= b[2] + 30 and b[1] - 10 <= c[1] <= b[3] + 60:
                best = b
                break
        if best:
            best[0] = min(best[0], c[0])
            best[1] = min(best[1], c[1])
            best[2] = max(best[2], c[2])
            best[3] = max(best[3], c[3])

    rgba = im.convert("RGBA")
    rp = rgba.load()
    for y in range(h):
        for x in range(w):
            if is_bg[y * w + x]:
                rp[x, y] = (0, 0, 0, 0)

    big.sort(key=lambda c: (round(c[1] / 120), c[0]))
    names = []
    for k, c in enumerate(big):
        crop = rgba.crop((c[0], c[1], c[2] + 1, c[3] + 1))
        name = "%s_%d.png" % (prefix, k + 1)
        crop.save(os.path.join(out_dir, name))
        names.append((name, crop.size))
        print("platform ->", name, crop.size, "bg", bg)
    return names


def main() -> None:
    src_root, out_dir = sys.argv[1], sys.argv[2]
    os.makedirs(out_dir, exist_ok=True)
    for rel, name in BACKGROUNDS.items():
        shutil.copyfile(os.path.join(src_root, rel), os.path.join(out_dir, name))
        print("bg ->", name)
    key_magenta(os.path.join(src_root, "ASSET RUMAH DI DUNIA LAIN/PORTAL.jpeg"), os.path.join(out_dir, "portal.png"), 384)
    cut_platforms(os.path.join(src_root, "parkour/image (4).png"), "platform", out_dir)
    cut_platforms(os.path.join(src_root, "parkour/image (3).png"), "platform_wide", out_dir)


if __name__ == "__main__":
    main()
