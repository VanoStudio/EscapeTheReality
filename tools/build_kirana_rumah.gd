extends Node
## Bangun sprite Kirana Rumah (idle 12f + walk 12f) dari konsep AI (latar magenta).
## Jalankan: godot_run scene tools/build_kirana_rumah.tscn
## Argumen (opsional, setelah "--"): --src=<png> --out=<dir res://> --compare=<png> --preview
##   --preview = hanya tulis strip + perbandingan (tanpa individual_frames) → untuk uji.
## Alur: chroma-key magenta → crop → downsample "suara terbanyak" ke grid native 64x64
## (1 piksel native = 4 piksel sel 256) → pisah segmen via mask region → animasi prosedural
## (geser piksel bulat, tanpa interpolasi/rotasi) → upscale nearest ×4 → strip 3072x256.
## Hasil dilaporkan lewat printerr supaya terlihat di ekor log godot_run.

const SRC_DEFAULT := "res://assets/raw/characters/kirana_rumah_konsep2.png"
const OUT_DEFAULT := "res://assets/processed/characters/kirana_rumah/"
const REF_DIR := "res://assets/processed/characters/kirana_fantasi/individual_frames/"
const CMP_DEFAULT := "res://tools/_preview/perbandingan.png"

const CELL := 256
const PX := 4                # 1 piksel native = 4 piksel sel
const NCELL := 64            # CELL / PX
const BASE_ROW := 60         # baris native eksklusif tempat kaki berdiri → y=240 (sama fantasi)
const TARGET_H := 52         # native → 208 px (fantasi idle = 209)
const FRAMES := 12
const KEY_DIST := 70.0

# Warna (disetel dari konsep-2)
const OUTLINE := Color8(24, 18, 22)
const HAIR := Color8(48, 38, 36)
const CLIP_HI := Color8(228, 232, 242)
const CLIP_LO := Color8(158, 166, 186)

# Fraksi bbox sprite (x: 0..1 lebar, y: 0..1 tinggi) — diukur dari konsep-2
const F_EYE_L := Vector2(0.212, 0.237)
const F_EYE_R := Vector2(0.536, 0.237)
const F_CLIP := Vector2(0.735, 0.145)
const F_LEG_SPLIT := 0.455
const F_HEM := 0.84          # awal ujung celana lebar + sepatu
const F_WAIST := 0.52

var _log := ""
var _ox := 0
var _oy := 0
var _tw := 0

func _say(s: String) -> void:
	_log += s + "\n"

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var s := String(a)
		if s.begins_with("--"):
			var kv := s.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_say("BUILD_KIRANA_RUMAH>>")
	var ok := _run(args)
	_say("SELESAI ok=" + str(ok))
	printerr(_log)
	get_tree().quit()

# ───────────────────────── pipeline ─────────────────────────

func _run(a: Dictionary) -> bool:
	var src_path: String = a.get("src", SRC_DEFAULT)
	var out_dir: String = a.get("out", OUT_DEFAULT)
	var cmp_path: String = a.get("compare", CMP_DEFAULT)
	var preview: bool = a.has("preview")
	if not out_dir.ends_with("/"):
		out_dir += "/"
	var src := _load_png(src_path)
	if src == null:
		_say("GAGAL: tidak bisa memuat src " + src_path)
		return false
	_say("src %s %s" % [src_path, str(src.get_size())])

	var keyed := _key_background(src)
	var rect := keyed.get_used_rect()
	_say("bbox setelah key: " + str(rect))
	if rect.size.y < 50:
		_say("GAGAL: bbox terlalu kecil (key salah?)")
		return false
	var native := _downsample(keyed, rect, TARGET_H)
	_say("native %s" % str(native.get_size()))
	_tw = native.get_width()
	_ox = (NCELL - _tw) / 2
	_oy = BASE_ROW - TARGET_H
	var base := _blank()
	base.blit_rect(native, Rect2i(0, 0, _tw, TARGET_H), Vector2i(_ox, _oy))
	_despeckle(base)
	_fix_hairpin(base)

	var seg := _make_segments(base)
	var idle: Array[Image] = []
	var walk: Array[Image] = []
	for i in FRAMES:
		idle.append(_upscale(_compose(seg, _idle_params(i))))
	for i in FRAMES:
		walk.append(_upscale(_compose(seg, _walk_params(i))))

	_report("idle", idle)
	_report("walk", walk)

	_ensure_dir(out_dir + "spritesheets_strip_12x1/")
	_save(_strip(idle), out_dir + "spritesheets_strip_12x1/idle_12f.png")
	_save(_strip(walk), out_dir + "spritesheets_strip_12x1/walk_12f.png")
	if not preview:
		for pair in [["idle", idle], ["walk", walk]]:
			var nm: String = pair[0]
			var arr: Array = pair[1]
			_ensure_dir(out_dir + "individual_frames/" + nm + "/")
			for i in FRAMES:
				_save(arr[i], out_dir + "individual_frames/%s/frame_%02d.png" % [nm, i + 1])
		_patch_tres(out_dir)
	_compare(idle, walk, cmp_path)
	return true

## Ganti animasi idle_rumah / walk_rumah di kirana_fantasy_frames.tres (teks) dengan
## 12 AtlasTexture per strip. Nama animasi tidak diubah; kirana_rumah.png lama tidak dihapus.
## (Edit teks, bukan ResourceSaver, karena png baru belum ter-import saat godot_run.)
func _patch_tres(out_dir: String) -> void:
	var path := "res://assets/processed/characters/kirana_fantasi/kirana_fantasy_frames.tres"
	var t := FileAccess.get_file_as_string(path)
	if t.is_empty():
		_say("GAGAL patch: tres tidak terbaca")
		return
	if t.contains("rumah_idle_strip"):
		_say("tres sudah dipatch sebelumnya → dilewati")
		return
	var old_ext := '[ext_resource type="Texture2D" path="res://assets/processed/characters/kirana_rumah.png" id="3_a02b0"]'
	if not t.contains(old_ext) or not t.contains("[resource]\n"):
		_say("GAGAL patch: struktur tres tak dikenali")
		return
	var new_ext := '[ext_resource type="Texture2D" path="%sspritesheets_strip_12x1/idle_12f.png" id="rumah_idle_strip"]\n' % out_dir
	new_ext += '[ext_resource type="Texture2D" path="%sspritesheets_strip_12x1/walk_12f.png" id="rumah_walk_strip"]' % out_dir
	t = t.replace(old_ext, new_ext)
	var subs := ""
	for kind in ["idle", "walk"]:
		for i in FRAMES:
			subs += '[sub_resource type="AtlasTexture" id="AtlasTexture_rumah_%s_%02d"]\natlas = ExtResource("rumah_%s_strip")\nregion = Rect2(%d, 0, 256, 256)\n\n' % [kind, i + 1, kind, i * CELL]
	t = t.replace("[resource]\n", subs + "[resource]\n")
	for pair in [["idle_rumah", "idle", "10.0"], ["walk_rumah", "walk", "12.0"]]:
		var anim: String = pair[0]
		var kind2: String = pair[1]
		var name_idx := t.find('"name": &"%s"' % anim)
		var fr_idx := t.rfind('"frames": [', name_idx)
		var loop_idx := t.find('"loop"', fr_idx)
		if name_idx < 0 or fr_idx < 0 or loop_idx < 0:
			_say("GAGAL patch: animasi %s tak ditemukan" % anim)
			return
		var items: Array[String] = []
		for i in FRAMES:
			items.append('{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_rumah_%s_%02d")\n}' % [kind2, i + 1])
		t = t.substr(0, fr_idx) + '"frames": [' + ", ".join(items) + '],\n' + t.substr(loop_idx)
		name_idx = t.find('"name": &"%s"' % anim)
		var sp_idx := t.find('"speed": ', name_idx)
		var sp_end := t.find("\n", sp_idx)
		t = t.substr(0, sp_idx) + '"speed": ' + str(pair[2]) + t.substr(sp_end)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		_say("GAGAL patch: tak bisa tulis tres")
		return
	f.store_string(t)
	f.close()
	_say("tres dipatch: idle_rumah speed 10, walk_rumah speed 12, 12 region 256x256 per strip")

func _load_png(path: String) -> Image:
	var b := FileAccess.get_file_as_bytes(path)
	if b.is_empty():
		return null
	var img := Image.new()
	var err := img.load_png_from_buffer(b)
	if err != OK:
		err = img.load_jpg_from_buffer(b)
	return img if err == OK else null

func _ensure_dir(p: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p))

func _save(img: Image, p: String) -> void:
	var e := img.save_png(ProjectSettings.globalize_path(p))
	if e != OK:
		_say("GAGAL simpan %s err=%d" % [p, e])

func _blank() -> Image:
	return Image.create(NCELL, NCELL, false, Image.FORMAT_RGBA8)

# ───────────────────── 1. chroma key ─────────────────────

func _key_background(src: Image) -> Image:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var d := img.get_data()
	# warna latar = rata-rata piksel pinggir
	var sr := 0.0
	var sg := 0.0
	var sb := 0.0
	var n := 0
	for x in w:
		for y in [0, h - 1]:
			var o: int = (y * w + x) * 4
			sr += d[o]; sg += d[o + 1]; sb += d[o + 2]; n += 1
	for y in h:
		for x in [0, w - 1]:
			var o2: int = (y * w + x) * 4
			sr += d[o2]; sg += d[o2 + 1]; sb += d[o2 + 2]; n += 1
	var bgr := sr / n
	var bgg := sg / n
	var bgb := sb / n
	_say("warna latar ~ (%d,%d,%d)" % [bgr, bgg, bgb])
	var thr2 := KEY_DIST * KEY_DIST
	var vis := PackedByteArray()
	vis.resize(w * h)
	var stack := PackedInt32Array()
	stack.resize(w * h)
	var top := 0
	# seed dari pinggir
	for x in w:
		for y in [0, h - 1]:
			var p: int = y * w + x
			if vis[p] == 0 and _near(d, p, bgr, bgg, bgb, thr2):
				vis[p] = 1; stack[top] = p; top += 1
	for y in h:
		for x in [0, w - 1]:
			var p2: int = y * w + x
			if vis[p2] == 0 and _near(d, p2, bgr, bgg, bgb, thr2):
				vis[p2] = 1; stack[top] = p2; top += 1
	while top > 0:
		top -= 1
		var cur: int = stack[top]
		var cx := cur % w
		var cy := cur / w
		for k in 4:
			var nx := cx + (1 if k == 0 else (-1 if k == 1 else 0))
			var ny := cy + (1 if k == 2 else (-1 if k == 3 else 0))
			if nx < 0 or ny < 0 or nx >= w or ny >= h:
				continue
			var q: int = ny * w + nx
			if vis[q] == 0 and _near(d, q, bgr, bgg, bgb, thr2):
				vis[q] = 1; stack[top] = q; top += 1
	# fringe: piksel tepi yang masih bernuansa magenta ikut dibuang (2 putaran)
	for _round in 2:
		var kill := PackedInt32Array()
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var p3: int = y * w + x
				if vis[p3] == 1:
					continue
				if vis[p3 - 1] == 0 and vis[p3 + 1] == 0 and vis[p3 - w] == 0 and vis[p3 + w] == 0:
					continue
				var o3: int = p3 * 4
				var r: int = d[o3]
				var g: int = d[o3 + 1]
				var b: int = d[o3 + 2]
				if r > g + 40 and b > g + 25 and r > 90:
					kill.append(p3)
		for p4 in kill:
			vis[p4] = 1
	for p5 in w * h:
		d[p5 * 4 + 3] = 0 if vis[p5] == 1 else 255
	img.set_data(w, h, false, Image.FORMAT_RGBA8, d)
	return img

func _near(d: PackedByteArray, p: int, r: float, g: float, b: float, thr2: float) -> bool:
	var o := p * 4
	if d[o + 3] < 128:
		return true      # sudah transparan (mis. input uji) → anggap latar
	var dr := d[o] - r
	var dg := d[o + 1] - g
	var db := d[o + 2] - b
	return dr * dr + dg * dg + db * db <= thr2

# ───────────────────── 2. downsample (suara terbanyak) ─────────────────────

func _downsample(img: Image, rect: Rect2i, target_h: int) -> Image:
	var s := float(target_h) / float(rect.size.y)
	var tw := maxi(1, roundi(rect.size.x * s))
	var sx := float(tw) / float(rect.size.x)
	var out := Image.create(tw, target_h, false, Image.FORMAT_RGBA8)
	var w := img.get_width()
	var d := img.get_data()
	for ty in target_h:
		var y0: int = rect.position.y + int(floor(ty / s))
		var y1: int = rect.position.y + int(floor((ty + 1) / s))
		y1 = maxi(y1, y0 + 1)
		for tx in tw:
			var x0: int = rect.position.x + int(floor(tx / sx))
			var x1: int = rect.position.x + int(floor((tx + 1) / sx))
			x1 = maxi(x1, x0 + 1)
			var votes := {}
			var total := 0
			var opaque := 0
			for yy in range(y0, y1):
				for xx in range(x0, x1):
					total += 1
					var o: int = (yy * w + xx) * 4
					if d[o + 3] == 0:
						continue
					opaque += 1
					var r: int = d[o]
					var g: int = d[o + 1]
					var b: int = d[o + 2]
					var luma := (r * 3 + g * 6 + b) / 10
					var wt := 1.0
					if luma < 45:
						wt = 1.7      # garis tepi gelap dipertahankan
					elif luma > 232:
						wt = 1.3      # highlight / sepatu putih
					var key: int = ((r >> 5) << 6) | ((g >> 5) << 3) | (b >> 5)
					var v: Array = votes.get(key, [0.0, 0.0, 0.0, 0.0, 0])
					v[0] += wt
					v[1] += r; v[2] += g; v[3] += b; v[4] += 1
					votes[key] = v
			if opaque * 2 < total or votes.is_empty():
				continue
			var best: Array = []
			for k in votes:
				var vv: Array = votes[k]
				if best.is_empty() or vv[0] > best[0]:
					best = vv
			var cnt: float = best[4]
			out.set_pixel(tx, ty, Color8(int(best[1] / cnt), int(best[2] / cnt), int(best[3] / cnt), 255))
	return out

func _despeckle(img: Image) -> void:
	var kill: Array[Vector2i] = []
	for y in NCELL:
		for x in NCELL:
			if img.get_pixel(x, y).a < 0.5:
				continue
			var nb := 0
			for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var q: Vector2i = Vector2i(x, y) + dv
				if _op(img, q.x, q.y):
					nb += 1
			if nb < 2:
				kill.append(Vector2i(x, y))
	for k in kill:
		img.set_pixel(k.x, k.y, Color(0, 0, 0, 0))

func _op(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and img.get_pixel(x, y).a >= 0.5

# ───────────────────── 3. rapikan: jepit, mata, segmen ─────────────────────

func _fx(f: float) -> int:
	return _ox + roundi(f * _tw)

func _fy(f: float) -> int:
	return _oy + roundi(f * TARGET_H)

func _luma(c: Color) -> float:
	return (c.r * 0.3 + c.g * 0.59 + c.b * 0.11) * 255.0

func _fix_hairpin(img: Image) -> void:
	var ax := _fx(F_CLIP.x)
	var ay := _fy(F_CLIP.y)
	# hapus gumpalan abu lama (terang & tidak berwarna kulit) → warna rambut
	for y in range(ay - 3, ay + 4):
		for x in range(ax - 3, ax + 4):
			if not _op(img, x, y):
				continue
			var c := img.get_pixel(x, y)
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			var sat := 0.0 if mx <= 0.0 else (mx - mn) / mx
			if _luma(c) > 95.0 and sat < 0.25:
				img.set_pixel(x, y, HAIR)
	# 2 batang perak sejajar, miring tipis, dipisah 1 baris rambut
	var x0 := ax - 1
	var r := ay - 2
	var px: Array = [
		[x0, r + 1, CLIP_LO], [x0 + 1, r, CLIP_HI], [x0 + 2, r, CLIP_LO],
		[x0, r + 3, CLIP_LO], [x0 + 1, r + 2, CLIP_HI], [x0 + 2, r + 2, CLIP_LO],
	]
	for p in px:
		if _op(img, p[0], p[1]):
			img.set_pixel(p[0], p[1], p[2])

func _rect(x0: float, x1: float, y0: float, y1: float) -> Rect2i:
	var ax := _fx(x0)
	var ay := _fy(y0)
	return Rect2i(ax, ay, _fx(x1) - ax, _fy(y1) - ay)

func _cut(base: Image, rects: Array) -> Image:
	var out := _blank()
	for r in rects:
		var rr: Rect2i = r
		for y in range(rr.position.y, rr.end.y):
			for x in range(rr.position.x, rr.end.x):
				if x >= 0 and y >= 0 and x < NCELL and y < NCELL:
					var c := base.get_pixel(x, y)
					if c.a >= 0.5:
						out.set_pixel(x, y, c)
	return out

func _make_segments(base: Image) -> Dictionary:
	var s := {}
	var cx := _fx(F_LEG_SPLIT)
	s["cx"] = cx
	s["hem_row"] = _fy(F_HEM)
	s["waist_row"] = _fy(F_WAIST)
	# kaki: tubuh bawah + "pengisi" di bawah hoodie supaya tidak bolong saat badan naik
	s["legL"] = _cut(base, [_rect(0.0, F_LEG_SPLIT, 0.70, 1.0), _rect(0.20, F_LEG_SPLIT, 0.60, 0.70)])
	s["legR"] = _cut(base, [_rect(F_LEG_SPLIT, 1.0, 0.70, 1.0), _rect(F_LEG_SPLIT, 0.72, 0.60, 0.70)])
	s["torso"] = _cut(base, [_rect(0.0, 1.0, 0.355, 0.675)])
	s["armL"] = _cut(base, [_rect(0.0, 0.20, 0.38, 0.70)])
	s["armR"] = _cut(base, [_rect(0.72, 1.0, 0.38, 0.70)])
	s["head"] = _cut(base, [_rect(0.0, 1.0, 0.0, 0.365)])
	# mata (dideteksi dari piksel gelap/putih di jendela sekitar posisi harapan)
	var head: Image = s["head"]
	s["eyeL"] = _find_eye(head, F_EYE_L)
	s["eyeR"] = _find_eye(head, F_EYE_R)
	s["skin"] = _sample_skin(head, s["eyeL"], s["eyeR"])
	_say("mata L=%s R=%s kulit=%s" % [str(s["eyeL"]), str(s["eyeR"]), str(s["skin"])])
	# murung: kelopak berat (baris atas mata digelapkan) di semua frame
	for key in ["eyeL", "eyeR"]:
		var e: Rect2i = s[key]
		if e.size.y >= 3:
			for x in range(e.position.x, e.end.x):
				head.set_pixel(x, e.position.y, OUTLINE)
	return s

func _find_eye(head: Image, f: Vector2) -> Rect2i:
	var cx := _fx(f.x)
	var y0 := _fy(0.215)
	var y1 := _fy(0.285)
	var x0 := 99
	var x1 := -1
	var ey0 := 99
	var ey1 := -1
	for y in range(y0, y1 + 1):
		for x in range(cx - 2, cx + 3):
			if not _op(head, x, y):
				continue
			var l := _luma(head.get_pixel(x, y))
			if l < 100.0 or l > 228.0:
				x0 = mini(x0, x); x1 = maxi(x1, x)
				ey0 = mini(ey0, y); ey1 = maxi(ey1, y)
	if x1 < 0:
		return Rect2i()
	return Rect2i(x0, ey0, x1 - x0 + 1, ey1 - ey0 + 1)

func _sample_skin(head: Image, el: Rect2i, er: Rect2i) -> Color:
	var e := el if el.size.x > 0 else er
	if e.size.x == 0:
		return Color8(232, 190, 160)
	var p := Vector2i(e.position.x + e.size.x / 2, e.end.y + 1)
	for dy in 4:
		if _op(head, p.x, p.y + dy):
			return head.get_pixel(p.x, p.y + dy)
	return Color8(232, 190, 160)

# ───────────────────── 4. animasi prosedural ─────────────────────

func _idle_params(i: int) -> Dictionary:
	var up := 1 if (i >= 3 and i <= 8) else 0
	var sway_tab := [0, 0, 1, 1, 1, 0, 0, 0, -1, -1, -1, 0]
	return {
		"legL_dy": 0, "legL_dx": 0, "legR_dy": 0, "legR_dx": 0,
		"body_dy": -up, "lean": 0,
		"widen": 1 if (i >= 4 and i <= 7) else 0,
		"armL_dy": -up if (i >= 4 and i <= 7) else 0, "armR_dy": 0, "armL_dx": 0, "armR_dx": 0,
		"blink": i == 9 or i == 10,
		"sway": sway_tab[i],
	}

func _walk_params(i: int) -> Dictionary:
	var p := TAU * float(i) / float(FRAMES)
	var sn := sin(p)
	var cs := cos(p)
	var liftL := maxf(0.0, sn)
	var liftR := maxf(0.0, -sn)
	var bob := 1 if absf(sn) > 0.7 else 0
	return {
		"legL_dy": -roundi(1.6 * liftL), "legL_dx": roundi(cs),
		"legR_dy": -roundi(1.6 * liftR), "legR_dx": -roundi(cs),
		"body_dy": -bob, "lean": -1, "widen": 0,
		"armL_dy": roundi(-cs), "armR_dy": roundi(cs), "armL_dx": 0, "armR_dx": 0,
		"blink": false, "sway": roundi(-cs * 0.9),
	}

func _rs(split: int, above: int, below: int) -> PackedInt32Array:
	var a := PackedInt32Array()
	a.resize(NCELL)
	for y in NCELL:
		a[y] = above if y < split else below
	return a

func _place(dst: Image, src: Image, dy: int, rs: PackedInt32Array) -> void:
	for y in NCELL:
		var ty := y + dy
		if ty < 0 or ty >= NCELL:
			continue
		for x in NCELL:
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var tx := x + rs[y]
			if tx >= 0 and tx < NCELL:
				dst.set_pixel(tx, ty, c)

func _widen(src: Image, cx: int) -> Image:
	var out := _blank()
	for y in NCELL:
		for x in NCELL:
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			out.set_pixel(x - 1 if x < cx else x, y, c)
		if src.get_pixel(cx - 1, y).a >= 0.5:
			out.set_pixel(cx - 1, y, src.get_pixel(cx - 1, y))
	return out

func _head_variant(S: Dictionary, blink: bool, sway: int) -> Image:
	var head: Image = (S["head"] as Image).duplicate()
	if blink:
		for key in ["eyeL", "eyeR"]:
			var e: Rect2i = S[key]
			if e.size.x == 0:
				continue
			for y in range(e.position.y, e.end.y):
				for x in range(e.position.x, e.end.x):
					head.set_pixel(x, y, S["skin"])
			var ly := e.end.y - 2 if e.size.y >= 3 else e.end.y - 1
			for x in range(e.position.x, e.end.x):
				head.set_pixel(x, ly, OUTLINE)
	if sway != 0:
		# ujung bob (baris bawah rambut) melebar ke satu sisi: 2 kolom terluar bergeser 1 px
		for y in range(_fy(0.31), _fy(0.365)):
			var xl := 99
			var xr := -1
			for x in NCELL:
				if _op(head, x, y) and _luma(head.get_pixel(x, y)) < 80.0:
					xl = mini(xl, x); xr = maxi(xr, x)
			if xr < 0:
				continue
			if sway > 0 and xr + 1 < NCELL:
				head.set_pixel(xr + 1, y, head.get_pixel(xr, y))
				if xr - 1 >= 0 and _op(head, xr - 1, y):
					head.set_pixel(xr, y, head.get_pixel(xr - 1, y))
			elif sway < 0 and xl - 1 >= 0:
				head.set_pixel(xl - 1, y, head.get_pixel(xl, y))
				if _op(head, xl + 1, y):
					head.set_pixel(xl, y, head.get_pixel(xl + 1, y))
	return head

func _compose(S: Dictionary, f: Dictionary) -> Image:
	var out := _blank()
	var hem: int = S["hem_row"]
	var waist: int = S["waist_row"]
	var lean: int = f["lean"]
	var bdy: int = f["body_dy"]
	_place(out, S["legL"], f["legL_dy"], _rs(hem, 0, f["legL_dx"]))
	_place(out, S["legR"], f["legR_dy"], _rs(hem, 0, f["legR_dx"]))
	var torso: Image = S["torso"]
	if f["widen"] > 0:
		torso = _widen(torso, S["cx"])
	_place(out, torso, bdy, _rs(waist, lean, 0))
	var wl: int = -1 if f["widen"] > 0 else 0
	var wr: int = 1 if f["widen"] > 0 else 0
	var al: int = int(f["armL_dx"]) + wl
	var ar: int = int(f["armR_dx"]) + wr
	_place(out, S["armL"], bdy + int(f["armL_dy"]), _rs(waist, lean + al, al))
	_place(out, S["armR"], bdy + int(f["armR_dy"]), _rs(waist, lean + ar, ar))
	var head := _head_variant(S, f["blink"], f["sway"])
	_place(out, head, bdy, _rs(0, lean, lean))
	return out

# ───────────────────── 5. output ─────────────────────

func _upscale(img: Image) -> Image:
	var out := Image.create(CELL, CELL, false, Image.FORMAT_RGBA8)
	for y in NCELL:
		for x in NCELL:
			var c := img.get_pixel(x, y)
			if c.a >= 0.5:
				out.fill_rect(Rect2i(x * PX, y * PX, PX, PX), c)
	return out

func _strip(frames: Array) -> Image:
	var out := Image.create(CELL * FRAMES, CELL, false, Image.FORMAT_RGBA8)
	for i in FRAMES:
		var fr: Image = frames[i]
		out.blit_rect(fr, Rect2i(0, 0, CELL, CELL), Vector2i(i * CELL, 0))
	return out

func _report(nm: String, frames: Array) -> void:
	var lo := 9999
	var hi := -1
	var hmin := 9999
	var hmax := 0
	var s := ""
	for i in frames.size():
		var u: Rect2i = (frames[i] as Image).get_used_rect()
		lo = mini(lo, u.end.y); hi = maxi(hi, u.end.y)
		hmin = mini(hmin, u.size.y); hmax = maxi(hmax, u.size.y)
		s += "%d:%d..%d " % [i + 1, u.position.y, u.end.y]
	_say("%s: kaki-bawah y %d..%d, tinggi %d..%d (fantasi idle: 209, baseline 240) | %s" % [nm, lo, hi, hmin, hmax, s])

func _compare(idle: Array, walk: Array, path: String) -> void:
	var cols := 5
	var cmp := Image.create(CELL * cols, CELL * 2, false, Image.FORMAT_RGBA8)
	cmp.fill(Color8(70, 76, 92))
	for y in 2:
		cmp.fill_rect(Rect2i(0, y * CELL + 240, CELL * cols, 1), Color8(255, 255, 0, 160))
	var ref_list := [["idle", 1], ["walk", 1], ["walk", 4], ["walk", 7], ["walk", 10]]
	for c in cols:
		var r: Array = ref_list[c]
		var ref := _load_png(REF_DIR + "%s/frame_%02d.png" % [r[0], r[1]])
		if ref != null:
			ref.convert(Image.FORMAT_RGBA8)
			cmp.blend_rect(ref, Rect2i(0, 0, CELL, CELL), Vector2i(c * CELL, 0))
		var mine: Image = idle[0] if c == 0 else walk[int(r[1]) - 1]
		cmp.blend_rect(mine, Rect2i(0, 0, CELL, CELL), Vector2i(c * CELL, CELL))
	_ensure_dir(path.get_base_dir())
	_save(cmp, path)
	_say("perbandingan → " + path)
