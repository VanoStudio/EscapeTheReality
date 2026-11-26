class_name ComicBalloon
extends Control

# Bubble dialog webtoon yang digambar prosedural (badan + ekor = satu polygon, outline mulus).
# Hidup di dalam SubViewport; ComicPlayer menempelkan tekstur viewport ke Sprite3D panel
# supaya bubble ikut bergerak/miring bersama panel di ruang 2.5D.
#
# Gaya:
#   speech     bubble bulat organik (bicara biasa)
#   hollow     outline putus-putus tipis, teks bergelombang pelan (jawaban palsu "gapapa")
#   cold       kotak membulat gelap, teks putih kebiruan (kalimat dingin/menusuk)
#   shout      ledakan bergerigi besar (teriak)
#   shout_cry  ledakan bergerigi gemetar + teks bergetar (teriak sambil menangis)
#   sfx        tanpa badan, huruf tebal ber-outline (efek suara)

const STYLE := {
	"speech": {"font": "res://assets/processed/fonts/comic_dialog_bold.ttf", "fill": "#fbf8f2", "line": "#1b1720", "text": "#1b1720", "line_w": 0.028, "k": Vector2(1.2, 1.32), "pad": 0.55},
	"hollow": {"font": "res://assets/processed/fonts/comic_dialog.ttf", "fill": "#f6f2ea", "line": "#3a3440", "text": "#2a2530", "line_w": 0.018, "k": Vector2(1.2, 1.32), "pad": 0.6},
	"cold": {"font": "res://assets/processed/fonts/comic_dialog_bold.ttf", "fill": "#14161c", "line": "#cfd6e6", "text": "#e8eefc", "line_w": 0.022, "k": Vector2(1.06, 1.12), "pad": 0.6},
	"shout": {"font": "res://assets/processed/fonts/scream.ttf", "fill": "#ffffff", "line": "#120e14", "text": "#1b1720", "line_w": 0.045, "k": Vector2(1.2, 1.38), "pad": 0.3},
	"shout_cry": {"font": "res://assets/processed/fonts/scream.ttf", "fill": "#ffffff", "line": "#120e14", "text": "#1b1720", "line_w": 0.038, "k": Vector2(1.16, 1.34), "pad": 0.3},
	"sfx": {"font": "res://assets/processed/fonts/scream.ttf", "fill": "#00000000", "line": "#00000000", "text": "#ffffff", "line_w": 0.0, "k": Vector2(1, 1), "pad": 0.0}
}

var style: String = "speech"
var body_center := Vector2.ZERO
var body_half := Vector2.ONE
var tail_tip := Vector2.INF
var seed_val: int = 0
var fill_color := Color.WHITE
var line_color := Color.BLACK
var line_width := 4.0
var font_px: int = 32
var label: RichTextLabel
var jitter_px := 0.0
var _jitter_acc := 0.0
var _jitter_seed: int = 0

# Menyusun bubble untuk satu panel.
# def: data bubble dari comic.json. panel_size: ukuran panel (unit dunia).
# px_per_unit: resolusi viewport. fpx: ukuran font (px viewport).
# Hasil: {"vp_size": Vector2i, "center_units": Vector2 (koordinat panel, y ke atas)}.
func build(def: Dictionary, panel_size: Vector2, px_per_unit: float, fpx: int) -> Dictionary:
	style = String(def.get("style", "speech"))
	if not STYLE.has(style):
		style = "speech"
	var st: Dictionary = STYLE[style]
	font_px = fpx
	seed_val = hash(String(def.get("text", "")))
	fill_color = Color.html(String(def.get("fill", st["fill"])))
	line_color = Color.html(String(def.get("line", st["line"])))
	line_width = maxf(2.0, float(st["line_w"]) * fpx * 3.0) if style != "sfx" else 0.0
	jitter_px = fpx * 0.05 if style == "shout_cry" else 0.0

	var font_path := String(def.get("font", st["font"]))
	var font: Font = load(font_path) as Font if ResourceLoader.exists(font_path) else ThemeDB.fallback_font
	var text := String(def.get("text", ""))
	var panel_px := panel_size * px_per_unit
	var uv: Array = def.get("uv", [0.1, 0.1, 0.3, 0.2])
	var line_h := font.get_height(fpx)

	# Lebar bungkus dipilih dari jumlah baris yang membuat bubble melebar (rasio w:h ideal),
	# bukan dari lebar uv, supaya kalimat panjang tidak jadi menara sempit.
	var single := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fpx).x
	var ratio := 4.2 if style.begins_with("shout") else 3.2
	var n_lines := maxf(1.0, round(sqrt(single / (ratio * line_h))))
	var max_w: float = single / n_lines * 1.1 + fpx
	max_w = minf(max_w, panel_px.x * float(def.get("max_w", 0.62)))
	max_w = maxf(max_w, fpx * 4.0)

	# Ukur teks lalu seimbangkan lebar baris (hindari satu kata yatim di baris terakhir).
	var measured := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, max_w, fpx)
	var lines := int(round(measured.y / line_h))
	if lines > 1:
		var lo := max_w * 0.45
		var hi := max_w
		for i in range(10):
			var mid := (lo + hi) * 0.5
			var m := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, mid, fpx)
			if int(round(m.y / line_h)) > lines:
				lo = mid
			else:
				hi = mid
		measured = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, hi, fpx)
	var text_size := Vector2(measured.x + fpx * 0.3, measured.y)

	var k: Vector2 = st["k"]
	var pad := float(st["pad"]) * fpx
	body_half = Vector2(text_size.x * 0.5 * k.x + pad, text_size.y * 0.5 * k.y + pad)
	if style == "sfx":
		body_half = text_size * 0.5 + Vector2(fpx * 0.3, fpx * 0.3)

	# Posisi di ruang piksel panel (origin kiri-atas, y ke bawah).
	var c := Vector2((float(uv[0]) + float(uv[2]) * 0.5) * panel_px.x, (float(uv[1]) + float(uv[3]) * 0.5) * panel_px.y)
	var tip := Vector2.INF
	if def.has("tail") and style != "sfx":
		var t: Array = def["tail"]
		tip = Vector2(float(t[0]) * panel_px.x, float(t[1]) * panel_px.y)
		var dir := (tip - c).normalized()
		var edge := 1.0 / sqrt(pow(dir.x / body_half.x, 2) + pow(dir.y / body_half.y, 2))
		var max_len: float = minf(body_half.y * 1.5, fpx * 3.2)
		var min_len := fpx * 0.9
		var dist: float = clampf((tip - c).length(), edge + min_len, edge + max_len)
		tip = c + dir * dist

	var spike := 1.42 if style.begins_with("shout") else 1.06
	var margin := Vector2.ONE * (line_width * 2.0 + 14.0 + jitter_px)
	var bmin := c - body_half * spike - margin
	var bmax := c + body_half * spike + margin + Vector2(8, 10)
	if tip != Vector2.INF:
		bmin = bmin.min(tip - margin)
		bmax = bmax.max(tip + margin)
	var vp_size := Vector2i(int(ceil(bmax.x - bmin.x)), int(ceil(bmax.y - bmin.y)))
	size = Vector2(vp_size)
	body_center = c - bmin
	tail_tip = tip - bmin if tip != Vector2.INF else Vector2.INF

	label = RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("normal_font", font)
	label.add_theme_font_override("bold_font", font)
	label.add_theme_font_size_override("normal_font_size", fpx)
	label.add_theme_font_size_override("bold_font_size", fpx)
	label.add_theme_color_override("default_color", Color.html(String(def.get("color", st["text"]))))
	label.add_theme_constant_override("line_separation", 0)
	if style == "sfx":
		label.add_theme_constant_override("outline_size", int(fpx * 0.22))
		label.add_theme_color_override("font_outline_color", Color.html(String(def.get("outline", "#1b1720"))))
	label.size = Vector2(text_size.x, text_size.y)
	label.custom_minimum_size = Vector2(text_size.x, 0)
	label.position = body_center - text_size * 0.5 + Vector2(0, fpx * 0.04)
	label.text = _bbcode(def, text)
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	label.visible_characters = 0
	add_child(label)
	_recenter.call_deferred()

	var center_px := (bmin + bmax) * 0.5
	var center_units := Vector2(center_px.x / px_per_unit - panel_size.x * 0.5, -(center_px.y / px_per_unit - panel_size.y * 0.5))
	queue_redraw()
	return {"vp_size": vp_size, "center_units": center_units}

func _recenter() -> void:
	if label == null:
		return
	var h := float(label.get_content_height())
	if h > 0.0:
		label.position.y = body_center.y - h * 0.5

func _bbcode(def: Dictionary, text: String) -> String:
	var body := text
	var accent := String(def.get("accent", ""))
	if accent != "" and body.contains(accent):
		body = body.replace(accent, "[color=%s]%s[/color]" % [String(def.get("accent_color", "#b3121b")), accent])
	match style:
		"hollow":
			body = "[wave amp=%.1f freq=1.6 connected=1]%s[/wave]" % [font_px * 0.12, body]
		"shout_cry":
			body = "[shake rate=14.0 level=%d connected=1]%s[/shake]" % [maxi(2, int(font_px * 0.05)), body]
	return "[center]%s[/center]" % body

func _process(delta: float) -> void:
	if jitter_px <= 0.0:
		return
	_jitter_acc += delta
	if _jitter_acc >= 0.08:
		_jitter_acc = 0.0
		_jitter_seed += 1
		queue_redraw()

# ---------------------------------------------------------------- bentuk

func _tail_angle() -> float:
	if tail_tip == Vector2.INF:
		return PI * 0.5
	return (tail_tip - body_center).angle()

func _body_points() -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var pts := PackedVector2Array()
	# Mulai di seberang ekor supaya titik yang diganti ekor berada di tengah array (rentang utuh).
	var start := _tail_angle() + PI
	if style.begins_with("shout"):
		var spikes := 15 if style == "shout" else 21
		var total := spikes * 2
		for i in range(total):
			var t := start + TAU * float(i) / total
			var r := 0.0
			if i % 2 == 0:
				r = rng.randf_range(1.14, 1.36) if style == "shout" else rng.randf_range(1.07, 1.2)
			else:
				r = rng.randf_range(0.9, 0.97)
			pts.append(body_center + Vector2(cos(t) * body_half.x, sin(t) * body_half.y) * r)
		return pts
	var ex := 4.6 if style == "cold" else 2.35
	var phase := rng.randf() * TAU
	var n := 96
	for i in range(n):
		var t := start + TAU * float(i) / n
		var c := cos(t)
		var s := sin(t)
		var x := signf(c) * pow(absf(c), 2.0 / ex)
		var y := signf(s) * pow(absf(s), 2.0 / ex)
		var wob := 1.0
		if style != "cold":
			wob = 1.0 + 0.016 * sin(3.0 * t + phase) + 0.01 * sin(5.0 * t + phase * 1.7)
		pts.append(body_center + Vector2(x * body_half.x, y * body_half.y) * wob)
	return pts

func _quad_bezier(a: Vector2, ctrl: Vector2, b: Vector2, steps: int, out: PackedVector2Array, include_first: bool) -> void:
	for i in range(0 if include_first else 1, steps + 1):
		var t := float(i) / steps
		out.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))

func _shape() -> PackedVector2Array:
	var pts := _body_points()
	if tail_tip == Vector2.INF:
		return pts
	var ta := _tail_angle()
	var avg_r := (body_half.x + body_half.y) * 0.5
	var base_w := font_px * (1.7 if style.begins_with("shout") else 1.05)
	var half_ang := base_w / (2.0 * avg_r)
	var i0 := -1
	var i1 := -1
	for i in range(pts.size()):
		if absf(angle_difference(ta, (pts[i] - body_center).angle())) < half_ang:
			if i0 < 0:
				i0 = i
			i1 = i
	if i0 < 0:
		i0 = pts.size() / 2
		i1 = i0
	i0 = maxi(i0 - 1, 1)
	i1 = mini(i1 + 1, pts.size() - 2)
	var base1 := pts[i0]
	var base2 := pts[i1]
	var out := PackedVector2Array()
	for i in range(0, i0 + 1):
		out.append(pts[i])
	if style in ["shout", "shout_cry", "cold"]:
		out.append(tail_tip)
	else:
		# Ekor melengkung: kedua sisi dibengkokkan ke arah yang sama.
		var axis := tail_tip - (base1 + base2) * 0.5
		var perp := Vector2(-axis.y, axis.x).normalized() * axis.length() * 0.22
		_quad_bezier(base1, base1.lerp(tail_tip, 0.55) + perp, tail_tip, 8, out, false)
		_quad_bezier(tail_tip, base2.lerp(tail_tip, 0.55) + perp * 0.6, base2, 8, out, false)
		out.remove_at(out.size() - 1)
	for i in range(i1, pts.size()):
		out.append(pts[i])
	return out

func _draw() -> void:
	if style == "sfx":
		return
	var poly := _shape()
	if jitter_px > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val + _jitter_seed * 7919
		for i in range(poly.size()):
			poly[i] += Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * jitter_px
	# Bayangan lembut di bawah bubble supaya "melayang" di atas panel.
	var shadow := PackedVector2Array()
	var off := Vector2(line_width * 1.2 + 3.0, line_width * 1.6 + 4.0)
	for p in poly:
		shadow.append(p + off)
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
	draw_colored_polygon(poly, fill_color)
	var closed := poly.duplicate()
	closed.append(poly[0])
	if style == "hollow":
		_draw_dashed(closed, line_color, line_width, font_px * 0.42, font_px * 0.26)
	else:
		draw_polyline(closed, line_color, line_width, true)
	if style == "cold":
		# Garis dalam tipis: kesan rapi dan berjarak.
		var inner := PackedVector2Array()
		for p in closed:
			inner.append(body_center + (p - body_center) * 0.94)
		draw_polyline(inner, Color(line_color, 0.25), maxf(1.0, line_width * 0.4), true)

func _draw_dashed(pts: PackedVector2Array, color: Color, width: float, on_len: float, off_len: float) -> void:
	var drawing := true
	var remain := on_len
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var pos := 0.0
		while pos < seg:
			var step: float = minf(remain, seg - pos)
			var p0 := a.lerp(b, pos / seg)
			var p1 := a.lerp(b, (pos + step) / seg)
			if drawing:
				draw_line(p0, p1, color, width, true)
			pos += step
			remain -= step
			if remain <= 0.001:
				drawing = not drawing
				remain = on_len if drawing else off_len
