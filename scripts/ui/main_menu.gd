class_name MainMenu
extends Control

# Main menu berlapis (aset folder MAINMENU di zip, diolah tools/process_menu_assets.py):
#   latar ruang terbelah (zoom pelan) -> pusaran cahaya di jam -> kabut mengalir ->
#   Kirana memegang jam (bernapas, jam berpendar) -> bingkai perabot melayang -> debu & bara ->
#   logo berkilau. Semua lapisan bergeser mengikuti mouse (kedalaman).
# Tombol gaya AAA (MenuButtonFX): MULAI / PENGATURAN / KREDIT / KELUAR, mouse + keyboard.

const ButtonFX := preload("res://scripts/ui/menu_button_fx.gd")
const DIR := "res://assets/processed/menu/"
const VIEW := Vector2(1920, 1080)
const KIRANA_H := 1000.0
const KIRANA_CENTER_X := 1300.0
const CLOCK_UV := Vector2(0.41, 0.48)   # posisi jam di gambar Kirana

var layers: Array = []      # [{node, base, depth}]
var bg: TextureRect
var swirl: TextureRect
var mist_a: TextureRect
var mist_b: TextureRect
var kirana: TextureRect
var clock_glow: TextureRect
var frame: TextureRect
var bokeh: TextureRect
var logo: TextureRect
var embers: CPUParticles2D
var buttons: Array = []
var button_box: VBoxContainer
var settings_panel: PanelContainer
var black: ColorRect
var hint: Label
var busy := false
var _t := 0.0
var _parallax := Vector2.ZERO
var _clock_pos := Vector2.ZERO

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build_scene()
	_build_buttons()
	_build_settings()
	_build_overlay()
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_music"):
		am.play_music("fantasy_piano")
	var rm = get_node_or_null("/root/RoomManager")
	if rm and rm.hud_instance:
		rm.hud_instance.visible = false
	_intro()
	_check_pending_screenshot()

# ---------------------------------------------------------------- lapisan

func _tex_rect(file: String, size: Vector2, pos: Vector2, depth: float, additive: bool = false) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = load(DIR + file) as Texture2D
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.size = size
	tr.position = pos
	tr.pivot_offset = size * 0.5
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		tr.material = m
	add_child(tr)
	layers.append({"node": tr, "base": pos, "depth": depth})
	return tr

func _build_scene() -> void:
	var base := ColorRect.new()
	base.color = Color(0.03, 0.01, 0.03)
	base.set_anchors_preset(Control.PRESET_FULL_RECT)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(base)

	bg = _tex_rect("menu_bg.jpg", Vector2(2080, 1170), Vector2(-80, -45), 10.0)
	bg.modulate = Color(0.78, 0.7, 0.76)

	var kw := KIRANA_H * 826.0 / 1201.0
	var kpos := Vector2(KIRANA_CENTER_X - kw * 0.5, VIEW.y - KIRANA_H + 70.0)
	_clock_pos = kpos + Vector2(kw, KIRANA_H) * CLOCK_UV

	# Pusaran cahaya: pusat terang di gambar ~ (0.52, 0.62) -> ditaruh di belakang jam.
	var sw := Vector2(1500, 844)
	swirl = _tex_rect("menu_swirl.jpg", sw, _clock_pos - sw * Vector2(0.52, 0.62), 16.0, true)
	swirl.pivot_offset = sw * Vector2(0.52, 0.62)
	swirl.modulate = Color(1, 1, 1, 0.75)

	mist_a = _tex_rect("menu_mist.jpg", Vector2(1920, 1080), Vector2(0, 160), 18.0, true)
	mist_b = _tex_rect("menu_mist.jpg", Vector2(1920, 1080), Vector2(-1920, 160), 18.0, true)
	mist_b.flip_h = true
	for m in [mist_a, mist_b]:
		m.modulate = Color(1, 0.85, 0.9, 0.55)

	kirana = _tex_rect("menu_kirana.png", Vector2(kw, KIRANA_H), kpos, 24.0)
	kirana.pivot_offset = Vector2(kw * 0.5, KIRANA_H)

	clock_glow = TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.8, 0.4, 0.9))
	grad.set_color(1, Color(1.0, 0.5, 0.2, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 256
	gt.height = 256
	clock_glow.texture = gt
	clock_glow.size = Vector2(260, 260)
	clock_glow.pivot_offset = Vector2(130, 130)
	clock_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	clock_glow.material = add
	add_child(clock_glow)
	layers.append({"node": clock_glow, "base": _clock_pos - Vector2(130, 130), "depth": 24.0})

	frame = _tex_rect("menu_frame.png", Vector2(2060, 1150), Vector2(-70, -35), 42.0)
	frame.modulate = Color(0.82, 0.76, 0.8)
	bokeh = _tex_rect("menu_bokeh.jpg", Vector2(2000, 1125), Vector2(-40, -22), 32.0, true)
	bokeh.modulate = Color(1, 0.9, 0.8, 0.85)

	embers = CPUParticles2D.new()
	embers.texture = RoomFX.dot_texture()
	embers.amount = 60
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.position = Vector2(960, 1120)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(1000, 20)
	embers.direction = Vector2(0.2, -1)
	embers.spread = 25.0
	embers.gravity = Vector2(0, -6)
	embers.initial_velocity_min = 40.0
	embers.initial_velocity_max = 110.0
	embers.scale_amount_min = 0.15
	embers.scale_amount_max = 0.5
	embers.color = Color(1.0, 0.6, 0.3, 0.8)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.2, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	embers.color_ramp = ramp
	var em := CanvasItemMaterial.new()
	em.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	embers.material = em
	add_child(embers)

	# Gelap di kiri untuk keterbacaan logo & tombol, plus vignette.
	var side := TextureRect.new()
	var sg := Gradient.new()
	sg.set_color(0, Color(0.02, 0.0, 0.03, 0.85))
	sg.set_color(1, Color(0.02, 0.0, 0.03, 0.0))
	var st := GradientTexture2D.new()
	st.gradient = sg
	st.fill_from = Vector2(0, 0.5)
	st.fill_to = Vector2(1, 0.5)
	side.texture = st
	side.stretch_mode = TextureRect.STRETCH_SCALE
	side.position = Vector2.ZERO
	side.size = Vector2(1150, 1080)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(side)
	var vg := TextureRect.new()
	var vgr := Gradient.new()
	vgr.set_color(0, Color(0, 0, 0, 0))
	vgr.set_offset(0, 0.55)
	vgr.set_color(1, Color(0, 0, 0, 0.7))
	var vgt := GradientTexture2D.new()
	vgt.gradient = vgr
	vgt.fill = GradientTexture2D.FILL_RADIAL
	vgt.fill_from = Vector2(0.5, 0.5)
	vgt.fill_to = Vector2(1.0, 1.0)
	vg.texture = vgt
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vg)

	var lw := 720.0
	logo = _tex_rect("menu_logo.png", Vector2(lw, lw * 615.0 / 1100.0), Vector2(110, 70), 6.0)
	var sh := ShaderMaterial.new()
	sh.shader = load("res://shaders/logo_shine.gdshader") as Shader
	logo.material = sh

# ---------------------------------------------------------------- tombol

func _build_buttons() -> void:
	button_box = VBoxContainer.new()
	button_box.position = Vector2(96, 560)
	button_box.add_theme_constant_override("separation", 6)
	add_child(button_box)
	var defs := [["Mulai", _on_start], ["Pengaturan", _on_settings], ["Kredit", _on_credits]]
	# Di browser (build web itch.io) tombol Keluar tidak berfungsi, jadi disembunyikan.
	if not OS.has_feature("web"):
		defs.append(["Keluar", _on_quit])
	for d in defs:
		var b: Button = ButtonFX.make(d[0], 40)
		b.pressed.connect(d[1])
		button_box.add_child(b)
		buttons.append(b)
	for i in range(buttons.size()):
		var b: Button = buttons[i]
		b.focus_neighbor_top = b.get_path_to(buttons[(i - 1 + buttons.size()) % buttons.size()])
		b.focus_neighbor_bottom = b.get_path_to(buttons[(i + 1) % buttons.size()])
	hint = Label.new()
	hint.text = "↑ ↓  pilih      Enter  konfirmasi"
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(0.95, 0.88, 0.8, 0.55))
	hint.position = Vector2(140, 1010)
	add_child(hint)

func _build_overlay() -> void:
	black = ColorRect.new()
	black.color = Color(0, 0, 0, 1)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(black)

func _intro() -> void:
	logo.modulate.a = 0.0
	logo.scale = Vector2(1.12, 1.12)
	for b in buttons:
		b.modulate.a = 0.0
	hint.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(black, "color:a", 0.0, 1.4).set_trans(Tween.TRANS_SINE)
	var l := create_tween().set_parallel(true)
	l.tween_property(logo, "modulate:a", 1.0, 1.2).set_delay(0.5)
	l.tween_property(logo, "scale", Vector2.ONE, 1.6).set_delay(0.5).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	for i in range(buttons.size()):
		var b: Control = buttons[i]
		var tb := create_tween().set_parallel(true)
		b.position.x = -60.0
		tb.tween_property(b, "modulate:a", 1.0, 0.5).set_delay(1.1 + i * 0.12)
		tb.tween_property(b, "position:x", 0.0, 0.6).set_delay(1.1 + i * 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	create_tween().tween_property(hint, "modulate:a", 1.0, 0.8).set_delay(1.8)
	await get_tree().create_timer(1.2).timeout
	if is_instance_valid(buttons[0]):
		buttons[0].grab_focus()

# ---------------------------------------------------------------- gerak

func _process(delta: float) -> void:
	_t += delta
	# Parallax mengikuti mouse (halus), dengan sedikit napas otomatis.
	var mp := get_viewport().get_mouse_position()
	var target := ((mp / VIEW) - Vector2(0.5, 0.5)) * 2.0
	target = target.clamp(Vector2(-1, -1), Vector2(1, 1))
	_parallax = _parallax.lerp(target, 1.0 - exp(-2.5 * delta))
	var drift := Vector2(sin(_t * 0.21), cos(_t * 0.17)) * 0.25
	for L in layers:
		var n: Control = L["node"]
		n.position = L["base"] - (_parallax + drift) * float(L["depth"])
	bg.scale = Vector2.ONE * (1.02 + 0.02 * sin(_t * 0.08))
	swirl.rotation = sin(_t * 0.25) * 0.06
	swirl.modulate.a = 0.6 + 0.2 * sin(_t * 1.3)
	swirl.scale = Vector2.ONE * (1.0 + 0.03 * sin(_t * 0.9))
	var mx := fmod(_t * 28.0, 1920.0)
	mist_a.position.x += mx
	mist_b.position.x += mx
	kirana.scale = Vector2(1.0, 1.0 + 0.008 * sin(_t * 1.6))
	kirana.position.y += sin(_t * 0.9) * 6.0
	clock_glow.position.y += sin(_t * 0.9) * 6.0
	clock_glow.modulate.a = 0.55 + 0.35 * (0.5 + 0.5 * sin(_t * 2.4))
	clock_glow.scale = Vector2.ONE * (0.9 + 0.15 * sin(_t * 2.4))
	frame.position.y += sin(_t * 0.6) * 8.0
	frame.rotation = sin(_t * 0.35) * 0.004
	bokeh.position.y += -fmod(_t * 8.0, 40.0)
	bokeh.modulate.a = 0.7 + 0.15 * sin(_t * 0.7)
	logo.position.y += sin(_t * 1.1) * 3.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and settings_panel and settings_panel.visible:
		_close_settings()
		get_viewport().set_input_as_handled()

# ---------------------------------------------------------------- aksi

func _sfx(n: String, pitch: float = 1.0) -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx(n, pitch)

func _leave(scene: String) -> void:
	if busy:
		return
	busy = true
	_sfx("select")
	var rm = get_node_or_null("/root/RoomManager")
	if rm and rm.has_method("go_to_scene"):
		rm.go_to_scene(scene, 0.9, 0.9)
	else:
		get_tree().change_scene_to_file(scene)

func _on_start() -> void:
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("reset_state"):
		gs.reset_state()
	_leave("res://scenes/opening.tscn")

func _on_credits() -> void:
	_leave("res://scenes/credits.tscn")

func _on_quit() -> void:
	if busy:
		return
	busy = true
	_sfx("select")
	await create_tween().tween_property(black, "color:a", 1.0, 0.7).finished
	get_tree().quit()

# ---------------------------------------------------------------- pengaturan

func _build_settings() -> void:
	settings_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.03, 0.06, 0.92)
	sb.border_color = Color(1.0, 0.8, 0.5, 0.45)
	sb.border_width_left = 3
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 48
	sb.content_margin_right = 48
	sb.content_margin_top = 40
	sb.content_margin_bottom = 40
	settings_panel.add_theme_stylebox_override("panel", sb)
	settings_panel.position = Vector2(1920, 180)
	settings_panel.size = Vector2(720, 700)
	settings_panel.visible = false
	add_child(settings_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	settings_panel.add_child(v)
	var title := Label.new()
	title.text = "PENGATURAN"
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.55))
	v.add_child(title)
	for d in [["Volume Master", "Master"], ["Volume Musik", "Music"], ["Volume Efek Suara", "SFX"]]:
		var l := Label.new()
		l.text = d[0]
		l.add_theme_font_size_override("font_size", 28)
		l.add_theme_color_override("font_color", Color(0.95, 0.9, 0.85))
		v.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		var bus := AudioServer.get_bus_index(d[1])
		s.value = db_to_linear(AudioServer.get_bus_volume_db(bus)) if bus >= 0 else 1.0
		s.custom_minimum_size = Vector2(600, 36)
		s.value_changed.connect(_on_volume.bind(d[1]))
		v.add_child(s)
	var back: Button = ButtonFX.make("Kembali", 34, 600.0)
	back.pressed.connect(_close_settings)
	v.add_child(back)
	settings_panel.set_meta("back", back)

func _on_volume(val: float, bus_name: String) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(val, 0.001)))

func _on_settings() -> void:
	if busy:
		return
	_sfx("select")
	settings_panel.visible = true
	var t := create_tween().set_parallel(true)
	t.tween_property(settings_panel, "position:x", 1920.0 - 820.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(button_box, "modulate:a", 0.35, 0.3)
	(settings_panel.get_meta("back") as Control).grab_focus()

func _close_settings() -> void:
	_sfx("select", 0.9)
	var t := create_tween().set_parallel(true)
	t.tween_property(settings_panel, "position:x", 1920.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t.tween_property(button_box, "modulate:a", 1.0, 0.3)
	await t.finished
	settings_panel.visible = false
	buttons[1].grab_focus()

# ---------------------------------------------------------------- screenshot CLI

func _check_pending_screenshot() -> void:
	for arg in OS.get_cmdline_args():
		if String(arg).begins_with("--shot="):
			var shot_name := String(arg).trim_prefix("--shot=")
			await get_tree().create_timer(3.0).timeout
			var img := get_viewport().get_texture().get_image()
			img.save_png("res://tests/screenshots/%s.png" % shot_name)
			print("Screenshot captured: res://tests/screenshots/%s.png" % shot_name)
			get_tree().quit(0)
			return
