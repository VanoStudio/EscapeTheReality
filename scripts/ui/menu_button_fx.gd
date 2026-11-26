class_name MenuButtonFX
extends Button

# Tombol menu bergaya AAA: teks kapital renggang, saat dipilih (hover mouse / fokus keyboard)
# muncul sapuan cahaya dari kiri, garis bawah tumbuh, ornamen berlian, teks bergeser & berpendar.
# Mouse dan keyboard disatukan: hover = fokus, jadi hanya ada satu tombol terpilih.

const GOLD := Color(1.0, 0.84, 0.55)
const IDLE := Color(0.86, 0.82, 0.8, 0.88)

var label_text := ""
var font_px := 34
var _hl := 0.0          # 0..1 tingkat sorot
var _flash := 0.0
var _font: Font
var _t := 0.0

static func make(t: String, px: int = 34, width: float = 560.0) -> MenuButtonFX:
	var b := MenuButtonFX.new()
	b.label_text = t.to_upper()
	b.font_px = px
	b.custom_minimum_size = Vector2(width, px * 1.9)
	return b

func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_ALL
	flat = true
	for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var fv := FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.spacing_glyph = int(font_px * 0.16)
	fv.variation_embolden = 0.6
	_font = fv
	mouse_entered.connect(func() -> void:
		if not disabled:
			grab_focus())
	focus_entered.connect(_on_focus)
	pressed.connect(func() -> void: _flash = 1.0)

func _on_focus() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("tick", 1.6, -8.0)

func _process(delta: float) -> void:
	_t += delta
	var target := 1.0 if has_focus() else 0.0
	_hl = move_toward(_hl, target, delta * 5.0)
	_flash = maxf(_flash - delta * 3.0, 0.0)
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var e := ease(_hl, 0.4)
	# Sapuan cahaya dari kiri (gradien memudar ke kanan).
	if e > 0.001:
		var bw := w * e
		var c0 := Color(GOLD.r, GOLD.g * 0.7, GOLD.b * 0.4, 0.32 * e + 0.25 * _flash)
		var c1 := Color(c0.r, c0.g, c0.b, 0.0)
		draw_polygon(PackedVector2Array([Vector2(0, 4), Vector2(bw, 4), Vector2(bw, h - 4), Vector2(0, h - 4)]),
			PackedColorArray([c0, c1, c1, c0]))
		# Garis kiri + garis bawah yang tumbuh.
		draw_rect(Rect2(0, 6, 4, h - 12), Color(GOLD, e))
		draw_line(Vector2(34, h - 6), Vector2(34 + (w * 0.62) * e, h - 6), Color(GOLD, 0.8 * e), 2.0, true)
		# Berlian kecil berputar.
		var c := Vector2(22, h * 0.5)
		var r := 7.0 * e
		var a := _t * 1.6
		var pts := PackedVector2Array()
		for i in range(4):
			var ang := a + i * PI * 0.5
			pts.append(c + Vector2(cos(ang), sin(ang)) * r)
		draw_colored_polygon(pts, Color(GOLD, e))
	# Teks: bergeser saat dipilih, pendar lembut.
	var tx := 44.0 + 14.0 * e
	var ty := h * 0.5 + font_px * 0.36
	var col := IDLE.lerp(Color(1.0, 0.95, 0.85), e)
	if e > 0.01:
		for off in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
			draw_string(_font, Vector2(tx, ty) + off, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, Color(1.0, 0.6, 0.3, 0.18 * e))
	draw_string(_font, Vector2(tx + 2, ty + 3), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, Color(0, 0, 0, 0.6))
	draw_string(_font, Vector2(tx, ty), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_px, col)
