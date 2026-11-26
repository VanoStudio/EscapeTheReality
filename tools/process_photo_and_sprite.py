"""Aset rombak #2: foto keluarga sobek (4 pecahan) dan spritesheet Kirana rumah dari zip.

Pemakaian:
    python -I tools/process_photo_and_sprite.py <foto_sobek.webp> <folder SPRITESHEET KIRANA RUMAH>

Keluaran:
- assets/processed/flow/photo_piece_1..4.png  (urut: kiri-atas, kanan-atas, kiri-bawah, kanan-bawah)
- assets/processed/flow/photo_full.png        (foto utuh, latar dinding dibuang)
- assets/processed/flow/photo_pieces.json     (posisi tiap pecahan di foto utuh)
- assets/processed/characters/kirana_rumah/spritesheets_strip_12x1/{idle,walk}_12f.png
  (format sama seperti sebelumnya: strip 3072x256, sel 256, kaki di y=240, tinggi ~208)
"""
import json
import os
import sys
from collections import deque

from PIL import Image, ImageFilter

FLOW_DIR = "assets/processed/flow"
STRIP_DIR = "assets/processed/characters/kirana_rumah/spritesheets_strip_12x1"


def flood_background(im, x0, y0, x1, y1, is_bg):
    """Flood fill dari tepi kotak (x0,y0)-(x1,y1); kembalikan set piksel latar (bytearray)."""
    w = x1 - x0
    h = y1 - y0
    px = im.load()
    bg = bytearray(w * h)
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
        if bg[i]:
            continue
        if not is_bg(px[x0 + x, y0 + y]):
            continue
        bg[i] = 1
        if x > 0:
            q.append((x - 1, y))
        if x < w - 1:
            q.append((x + 1, y))
        if y > 0:
            q.append((x, y - 1))
        if y < h - 1:
            q.append((x, y + 1))
    return bg


def components(mask, w, h, min_px):
    label = [0] * (w * h)
    out = []
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if mask[i] or label[i]:
                continue
            cid = len(out) + 1
            q = deque([(x, y)])
            label[i] = cid
            bb = [x, y, x, y, 0]
            while q:
                cx, cy = q.popleft()
                bb[4] += 1
                bb[0] = min(bb[0], cx)
                bb[1] = min(bb[1], cy)
                bb[2] = max(bb[2], cx)
                bb[3] = max(bb[3], cy)
                for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
                    if 0 <= nx < w and 0 <= ny < h:
                        j = ny * w + nx
                        if not mask[j] and not label[j]:
                            label[j] = cid
                            q.append((nx, ny))
            if bb[4] >= min_px:
                out.append((cid, bb))
    return label, out


def _seam(cost, length, span, lo, hi):
    """Jalur biaya minimum (dynamic programming) melintasi `length` baris/kolom,
    posisi di [lo, hi), boleh bergeser maks 1 piksel per langkah."""
    INF = float("inf")
    n = hi - lo
    acc = [[INF] * n for _ in range(length)]
    back = [[0] * n for _ in range(length)]
    for j in range(n):
        acc[0][j] = cost(0, lo + j)
    for i in range(1, length):
        for j in range(n):
            best, bj = INF, j
            for dj in (-1, 0, 1):
                k = j + dj
                if 0 <= k < n and acc[i - 1][k] < best:
                    best, bj = acc[i - 1][k], k
            acc[i][j] = best + cost(i, lo + j)
            back[i][j] = bj
    j = min(range(n), key=lambda q: acc[length - 1][q])
    path = [0] * length
    for i in range(length - 1, -1, -1):
        path[i] = lo + j
        j = back[i][j]
    return path


def process_photo(src):
    # Sobekan di tengah tidak selalu terpisah bersih (serat kertas putih menjembatani),
    # jadi garis potong dicari dengan seam: lewat piksel dinding/serat sobekan.
    im = Image.open(src).convert("RGB")
    w, h = im.size
    px = im.load()
    ref = px[4, 4]

    def is_wall(c):
        # Dinding latar = abu zaitun: hijau sedikit di atas biru, merah ~ hijau, tidak terang.
        r, g, b = c
        return 100 <= max(c) <= 192 and 10 <= g - b <= 27 and 0 <= r - g <= 12

    def is_tear(c):
        # serat putih kertas di tepi sobekan
        return min(c) > 228

    def cost(c):
        return 0.0 if is_wall(c) else (0.25 if is_tear(c) else 1.0)

    vseam = _seam(lambda i, x: cost(px[x, i]), h, w, int(w * 0.4), int(w * 0.6))
    hseam = _seam(lambda i, y: cost(px[i, y]), w, h, int(h * 0.42), int(h * 0.58))

    border_bg = flood_background(im, 0, 0, w, h, is_wall)
    rgba = im.convert("RGBA")
    rp = rgba.load()
    pieces = [Image.new("RGBA", (w, h)) for _ in range(4)]
    pps = [pc.load() for pc in pieces]
    for y in range(h):
        vx = vseam[y]
        for x in range(w):
            c = px[x, y]
            if border_bg[y * w + x]:
                continue
            # Piksel dinding di dekat garis sobek = celah, dibuang.
            if is_wall(c) and (abs(x - vx) < 30 or abs(y - hseam[x]) < 30):
                continue
            q = (0 if y < hseam[x] else 2) + (0 if x < vx else 1)
            pps[q][x, y] = c + (255,)
    # Rapikan tiap pecahan: tutup celah sempit (closing) lalu isi lubang yang tertutup,
    # supaya latar foto yang mirip warna dinding tidak ikut terhapus.
    for n in range(4):
        mask = pieces[n].getchannel("A")
        closed = mask.filter(ImageFilter.MaxFilter(21)).filter(ImageFilter.MinFilter(21))
        cm = closed.load()
        outside = flood_background(closed.convert("RGB"), 0, 0, w, h, lambda c: c[0] < 128)
        fixed = Image.new("RGBA", (w, h))
        fp = fixed.load()
        for y in range(h):
            for x in range(w):
                if not outside[y * w + x] and cm[x, y] >= 128:
                    q = (0 if y < hseam[x] else 2) + (0 if x < vseam[y] else 1)
                    if q == n:
                        fp[x, y] = px[x, y] + (255,)
        # Kupas sisa dinding yang menempel di tepi luar (klasifikasi lebih longgar,
        # hanya merambat dari area transparan, jadi isi foto tidak ikut terkupas).
        def loose_wall(c):
            r, g, b = c[0], c[1], c[2]
            return max(c[:3]) <= 206 and 6 <= g - b <= 32 and -3 <= r - g <= 15
        q2 = deque()
        for y in range(h):
            for x in range(w):
                if fp[x, y][3] == 0:
                    q2.append((x, y))
        seen = bytearray(w * h)
        bb = fixed.getbbox() or (0, 0, w, h)
        BAND = 26
        def near_edge(x, y):
            return x - bb[0] < BAND or bb[2] - x < BAND or y - bb[1] < BAND or bb[3] - y < BAND
        while q2:
            x, y = q2.popleft()
            for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
                    c = fp[nx, ny]
                    if c[3] > 0 and loose_wall(c) and near_edge(nx, ny):
                        seen[ny * w + nx] = 1
                        fp[nx, ny] = (0, 0, 0, 0)
                        q2.append((nx, ny))
        pieces[n] = fixed
    meta = {"size": [w, h], "pieces": []}
    full = Image.new("RGBA", (w, h))
    for n, pc in enumerate(pieces):
        bb = pc.getbbox()
        crop = pc.crop(bb)
        name = "photo_piece_%d.png" % (n + 1)
        crop.save(os.path.join(FLOW_DIR, name))
        full.alpha_composite(pc)
        meta["pieces"].append({"file": name, "pos": [bb[0], bb[1]], "size": [crop.width, crop.height]})
        print("piece", name, bb)
    fb = full.getbbox()
    full.crop(fb).save(os.path.join(FLOW_DIR, "photo_full.png"))
    meta["full_offset"] = [fb[0], fb[1]]
    with open(os.path.join(FLOW_DIR, "photo_pieces.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, indent=2)


def process_sheet(src, out_name, cols=4, rows=3):
    im = Image.open(src).convert("RGB")
    W, H = im.size
    ref = im.getpixel((3, 3))

    def is_grey(c):
        return abs(c[0] - ref[0]) < 22 and abs(c[1] - ref[1]) < 22 and abs(c[2] - ref[2]) < 22

    cells = []
    for r in range(rows):
        for c in range(cols):
            x0 = round(c * W / cols)
            x1 = round((c + 1) * W / cols)
            y0 = round(r * H / rows)
            y1 = round((r + 1) * H / rows)
            cw, ch = x1 - x0, y1 - y0
            bg = flood_background(im, x0, y0, x1, y1, is_grey)
            # Buang bintik kecil sisa kompresi: ambil komponen terbesar saja.
            label, comps = components(bg, cw, ch, 50)
            keep = max(comps, key=lambda cc: cc[1][4])[0]
            cell = Image.new("RGBA", (cw, ch))
            cp = cell.load()
            src_px = im.load()
            for y in range(ch):
                for x in range(cw):
                    if label[y * cw + x] == keep:
                        cp[x, y] = src_px[x0 + x, y0 + y] + (255,)
            cells.append(cell.crop(cell.getbbox()))
    tallest = max(cl.height for cl in cells)
    k = 208.0 / tallest
    strip = Image.new("RGBA", (256 * len(cells), 256))
    for i, cl in enumerate(cells):
        sw, sh = max(1, round(cl.width * k)), max(1, round(cl.height * k))
        small = cl.resize((sw, sh), Image.BOX)
        # Rapikan alpha (tepi tajam ala pixel art).
        a = small.getchannel("A").point(lambda v: 255 if v >= 128 else 0)
        small.putalpha(a)
        # Jangkar horizontal: rata-rata x piksel kepala (30% atas) supaya badan tidak goyang.
        sp = small.load()
        xs = [x for y in range(int(sh * 0.3)) for x in range(sw) if sp[x, y][3] > 0]
        head_cx = sum(xs) / len(xs) if xs else sw / 2
        ox = round(256 * i + 128 - head_cx)
        oy = 240 - sh
        strip.alpha_composite(small, (ox, oy))
    os.makedirs(STRIP_DIR, exist_ok=True)
    strip.save(os.path.join(STRIP_DIR, out_name))
    print("strip", out_name, "frames", len(cells), "scale", round(k, 3))


def main():
    photo, sheet_dir = sys.argv[1], sys.argv[2]
    os.makedirs(FLOW_DIR, exist_ok=True)
    process_photo(photo)
    process_sheet(os.path.join(sheet_dir, "idle.jpeg"), "idle_12f.png")
    process_sheet(os.path.join(sheet_dir, "walk.jpeg"), "walk_12f.png")


if __name__ == "__main__":
    main()
