class_name ChoiceCard
extends Button

# Satu kotak pilihan jawaban (krem, bingkai emas ganda, sudut kiri-kanan terpotong, ornamen berlian).
# Digambar kode supaya rapi di ukuran apa pun; gaya dari ChoiceStyle (data/choice_style.tres).

var style: ChoiceStyle
var label_text := ""
var number := 0
var _font: Font
var _hl := 0.0
var _flash := 0.0
var _lines_h := 0.0

func setup(st: ChoiceStyle, txt: String, num: int) -> void:
	style = st
	label_text = txt
	number = num
	text = ""
	flat = true
	focus_mode = Control.FOCUS_ALL
	for n in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(n, StyleBoxEmpty.new())
	_font = load(st.font_path) as Font if ResourceLoader.exists(st.font_path) else ThemeDB.fallback_font
	var shown := _shown_text()
	var wrap_w := st.card_width - st.padding.x * 2.0
	var sz := _font.get_multiline_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, wrap_w, st.font_size)
	_lines_h = sz.y
	custom_minimum_size = Vector2(st.card_width, maxf(st.min_height, sz.y + st.padding.y * 2.0))

func _shown_text() -> String:
	return ("%d.  %s" % [number, label_text]) if style.show_numbers else label_text

func _ready() -> void:
	mouse_entered.connect(func() -> void:
		if not disabled:
			grab_focus())
	focus_entered.connect(func() -> void:
		var am = get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx("tick", 1.5, -8.0))
	pressed.connect(func() -> void: _flash = 1.0)

func _process(delta: float) -> void:
	if style == null:
		return
	_hl = move_toward(_hl, 1.0 if has_focus() else 0.0, delta * style.anim_speed)
	_flash = maxf(_flash - delta * 3.0, 0.0)
	queue_redraw()

func _shape(r: Rect2, cut: float) -> PackedVector2Array:
	# Persegi panjang dengan ujung kiri & kanan berbentuk mata panah tumpul.
	var mid := r.position.y + r.size.y * 0.5
	return PackedVector2Array([
		Vector2(r.position.x + cut, r.position.y), Vector2(r.end.x - cut, r.position.y),
		Vector2(r.end.x, mid), Vector2(r.end.x - cut, r.end.y),
		Vector2(r.position.x + cut, r.end.y), Vector2(r.position.x, mid)])

func _draw() -> void:
	if style == null:
		return
	var e := ease(_hl, 0.5)
	var off := Vector2(-style.hover_shift * e, 0)
	var r := Rect2(off, size)
	var cut := style.chamfer
	# Bayangan + cahaya saat dipilih.
	var sh := _shape(Rect2(r.position + Vector2(4, 5), r.size), cut)
	draw_colored_polygon(sh, style.shadow)
	if e > 0.01:
		var gr := _shape(r.grow(6.0 * e), cut + 4.0)
		draw_colored_polygon(gr, Color(style.glow, style.glow.a * e))
	var body := _shape(r, cut)
	draw_colored_polygon(body, style.fill.lerp(style.fill_hover, e).lerp(Color.WHITE, _flash * 0.5))
	var outline := body.duplicate()
	outline.append(body[0])
	draw_polyline(outline, style.border_outer.lerp(style.border_hover, e), style.border_width, true)
	var inner := _shape(r.grow(-style.inner_inset), maxf(cut - style.inner_inset * 0.6, 2.0))
	var inner_line := inner.duplicate()
	inner_line.append(inner[0])
	draw_polyline(inner_line, Color(style.border_inner, 0.7 + 0.3 * e), style.inner_width, true)
	# Ornamen berlian di kedua ujung.
	for x in [r.position.x + cut * 0.55, r.end.x - cut * 0.55]:
		var c := Vector2(x, r.position.y + r.size.y * 0.5)
		var d := 4.0 + 1.5 * e
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), style.border_outer.lerp(style.border_hover, e))
	# Teks rata kiri, di tengah secara vertikal.
	var wrap_w := style.card_width - style.padding.x * 2.0
	var top := r.position.y + (r.size.y - _lines_h) * 0.5 + _font.get_ascent(style.font_size)
	draw_multiline_string(_font, Vector2(r.position.x + style.padding.x, top), _shown_text(), HORIZONTAL_ALIGNMENT_LEFT, wrap_w, style.font_size, -1, style.text_color.lerp(style.text_hover, e))
