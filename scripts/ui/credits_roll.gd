class_name CreditsRoll
extends Control

# Roll kredit (data/credits.json). Dipakai setelah ending dan dari tombol KREDIT di main menu.
# Selesai -> tombol "KEMBALI KE MENU UTAMA"; tombol/klik apa saja juga kembali; otomatis kembali
# setelah AUTO_RETURN detik. Esc / tahan klik = lewati roll. Kembali ke menu selalu lewat fade.

const DATA_PATH := "res://data/credits.json"
const MENU_SCENE := "res://scenes/ui/main_menu.tscn"
const BOLD := "res://assets/processed/fonts/comic_dialog_bold.ttf"
const SCROLL_SPEED := 70.0
const AUTO_RETURN := 12.0
const SKIP_HOLD := 0.6
const ButtonFX := preload("res://scripts/ui/menu_button_fx.gd")

var column: VBoxContainer
var end_box: VBoxContainer
var back_btn: Button
var hint: Label
var bg: TextureRect
var bokeh: TextureRect
var finished_roll := false
var leaving := false
var roll_tween: Tween
var _t := 0.0
var _hold := 0.0
var _auto_timer := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_backdrop()
	_build_column(_load())
	_build_end()
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_music"):
		am.play_music("ending_warm")
	var rm = get_node_or_null("/root/RoomManager")
	if rm and rm.hud_instance:
		rm.hud_instance.visible = false
	await get_tree().process_frame
	_start_roll()
	_check_shot()

func _load() -> Dictionary:
	if FileAccess.file_exists(DATA_PATH):
		var d = JSON.parse_string(FileAccess.open(DATA_PATH, FileAccess.READ).get_as_text())
		if d is Dictionary:
			return d
	return {}

func _font() -> Font:
	return load(BOLD) as Font if ResourceLoader.exists(BOLD) else ThemeDB.fallback_font

func _label(text: String, size: int, color: Color, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(1500, 0)
	l.add_theme_font_override("font", _font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_y", 3)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.08))
	return l

func _build_backdrop() -> void:
	var black := ColorRect.new()
	black.color = Color(0.02, 0.01, 0.03)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(black)
	bg = TextureRect.new()
	bg.texture = load("res://assets/processed/menu/menu_bg.jpg") as Texture2D
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(2040, 1150)
	bg.position = Vector2(-60, -35)
	bg.modulate = Color(0.32, 0.26, 0.32)
	add_child(bg)
	bokeh = TextureRect.new()
	bokeh.texture = load("res://assets/processed/menu/menu_bokeh.jpg") as Texture2D
	bokeh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bokeh.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bokeh.size = Vector2(2040, 1150)
	bokeh.position = Vector2(-60, -35)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	bokeh.material = add
	bokeh.modulate = Color(1, 1, 1, 0.7)
	add_child(bokeh)
	var vg := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_offset(0, 0.45)
	grad.set_color(1, Color(0, 0, 0, 0.75))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 1.0)
	vg.texture = gt
	vg.stretch_mode = TextureRect.STRETCH_SCALE
	vg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vg)

func _build_column(d: Dictionary) -> void:
	column = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_BEGIN
	column.add_theme_constant_override("separation", 34)
	column.size = Vector2(1500, 10)
	column.position = Vector2(210, 1120)
	add_child(column)
	column.add_child(_label(String(d.get("title", "CREDIT:")), 64, Color(1.0, 0.82, 0.5), 10))
	column.add_child(_label(String(d.get("by", "")), 38, Color(0.98, 0.95, 0.9)))
	for b in d.get("blocks", []):
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 6)
		block.add_child(_label(String(b.get("role", "")), 28, Color(0.88, 0.74, 0.52)))
		block.add_child(_label(String(b.get("who", "")), 34, Color(0.97, 0.94, 0.88)))
		column.add_child(block)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(10, 12)
	column.add_child(spacer)
	column.add_child(_label(String(d.get("thanks", "")), 54, Color(1.0, 0.86, 0.6), 10))

func _build_end() -> void:
	end_box = VBoxContainer.new()
	end_box.alignment = BoxContainer.ALIGNMENT_CENTER
	end_box.add_theme_constant_override("separation", 18)
	end_box.position = Vector2(560, 885)
	end_box.size = Vector2(800, 160)
	end_box.modulate.a = 0.0
	add_child(end_box)
	back_btn = ButtonFX.make("KEMBALI KE MENU UTAMA", 34)
	back_btn.pressed.connect(_back)
	back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	end_box.add_child(back_btn)
	hint = _label("klik atau tekan tombol apa saja", 22, Color(0.9, 0.86, 0.8, 0.7))
	hint.custom_minimum_size = Vector2(800, 0)
	end_box.add_child(hint)

func _start_roll() -> void:
	var end_y := _rest_y()
	var dur := (column.position.y - end_y) / SCROLL_SPEED
	roll_tween = create_tween()
	roll_tween.tween_property(column, "position:y", end_y, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	roll_tween.finished.connect(_on_roll_done)

func _on_roll_done() -> void:
	if finished_roll:
		return
	finished_roll = true
	_auto_timer = AUTO_RETURN
	var t := create_tween().set_parallel(true)
	t.tween_property(end_box, "modulate:a", 1.0, 0.6)
	back_btn.grab_focus()

func _skip_roll() -> void:
	if finished_roll:
		return
	if roll_tween and roll_tween.is_valid():
		roll_tween.kill()
	column.position.y = _rest_y()
	_on_roll_done()

## Posisi akhir kolom: di tengah area atas (y 50..800), di atas tombol kembali.
func _rest_y() -> float:
	return 30.0 + maxf((740.0 - column.size.y) * 0.5, 0.0)

func _process(delta: float) -> void:
	_t += delta
	bg.position = Vector2(-60, -35) + Vector2(sin(_t * 0.07) * 30.0, cos(_t * 0.05) * 18.0)
	bokeh.position = Vector2(-60, -35) + Vector2(cos(_t * 0.11) * 40.0, -fmod(_t * 6.0, 30.0))
	if not finished_roll:
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE):
			_hold += delta
			if _hold >= SKIP_HOLD:
				_skip_roll()
		else:
			_hold = 0.0
	elif not leaving:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			_back()

func _unhandled_input(event: InputEvent) -> void:
	if leaving:
		return
	if not finished_roll:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("skip"):
			_skip_roll()
			get_viewport().set_input_as_handled()
		return
	var pressed: bool = (event is InputEventKey and event.pressed and not event.echo) or (event is InputEventMouseButton and event.pressed) or (event is InputEventJoypadButton and event.pressed)
	if pressed:
		get_viewport().set_input_as_handled()
		_back()

func _back() -> void:
	if leaving:
		return
	leaving = true
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("select")
	var rm = get_node_or_null("/root/RoomManager")
	if rm and rm.has_method("go_to_scene"):
		rm.go_to_scene(MENU_SCENE, 0.9, 0.9)
	else:
		get_tree().change_scene_to_file(MENU_SCENE)

func _check_shot() -> void:
	for arg in OS.get_cmdline_args():
		if String(arg).begins_with("--shot=") and String(arg).contains("credits"):
			_skip_roll()
			await get_tree().create_timer(1.0).timeout
			get_viewport().get_texture().get_image().save_png("res://tests/screenshots/%s.png" % String(arg).trim_prefix("--shot="))
			print("Screenshot captured")
			get_tree().quit(0)
