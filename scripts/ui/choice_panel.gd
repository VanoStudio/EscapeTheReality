class_name ChoicePanel
extends Control

signal choice_selected(choice_data: Dictionary)

@export var button_container: VBoxContainer
@export var timer_bar: ProgressBar

var current_choices: Array = []
var time_limit: float = 0.0
var time_remaining: float = 0.0
var is_active: bool = false
var buttons: Array[Button] = []
var cached_hud: Node = null

func _get_game_state() -> Node:
	if is_inside_tree():
		return get_node_or_null("/root/GameState")
	elif Engine.get_main_loop() and "root" in Engine.get_main_loop():
		return Engine.get_main_loop().root.get_node_or_null("GameState")
	return null

func _get_hud() -> Node:
	if cached_hud == null and is_inside_tree():
		cached_hud = get_tree().root.find_child("HUD", true, false)
	return cached_hud

func _ready() -> void:
	if button_container == null and has_node("VBoxContainer"):
		button_container = $VBoxContainer
	if timer_bar == null and has_node("TimerBar"):
		timer_bar = $TimerBar

func _process(delta: float) -> void:
	if not is_active:
		return
		
	if time_limit > 0.0:
		time_remaining -= delta
		if timer_bar:
			timer_bar.value = time_remaining
		# Update countdown di HUD jika ada
		var hud = _get_hud()
		if hud and hud.has_method("set_timer_display"):
			hud.set_timer_display(time_remaining, true)
			
		if time_remaining <= 0.0:
			_on_timeout()

func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
		
	# Tombol numerik 1-4
	if event.is_action_pressed("choice_1") and buttons.size() >= 1:
		buttons[0].emit_signal("pressed")
	elif event.is_action_pressed("choice_2") and buttons.size() >= 2:
		buttons[1].emit_signal("pressed")
	elif event.is_action_pressed("choice_3") and buttons.size() >= 3:
		buttons[2].emit_signal("pressed")
	elif event.is_action_pressed("choice_4") and buttons.size() >= 4:
		buttons[3].emit_signal("pressed")

func show_choices(choices: Array, arg2: Variant = 0, arg3: Variant = null) -> void:
	# Bersihkan tombol sebelumnya
	for b in buttons:
		b.queue_free()
	buttons.clear()
	
	var limit: float = 0.0
	var tier: int = 0
	
	if arg3 != null:
		# Dipanggil dengan 3 argumen: (choices, limit, tier)
		limit = float(arg2)
		tier = int(arg3)
	else:
		# Dipanggil dengan 2 argumen: (choices, tier)
		tier = int(arg2)
		var gs = _get_game_state()
		if gs and gs.tuning:
			match tier:
				0: limit = gs.tuning.timer_tenang
				1: limit = gs.tuning.timer_kesel
				2: limit = gs.tuning.timer_hampir_meledak
				_: limit = 0.0
		else:
			match tier:
				0: limit = 0.0
				1: limit = 30.0
				2: limit = 15.0
				_: limit = 0.0
	
	current_choices = choices.duplicate()
	time_limit = limit
	time_remaining = limit
	
	if timer_bar:
		timer_bar.visible = limit > 0.0
		timer_bar.max_value = time_limit
		timer_bar.value = time_limit
		
	# Buat 4 tombol dengan banner bergaya steampunk
	for i in range(current_choices.size()):
		var c = current_choices[i]
		var btn = Button.new()
		btn.text = "%d. %s" % [i + 1, c.get("text", "")]
		btn.custom_minimum_size = Vector2(650, 56)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		var ctype = c.get("type", "").to_lower()
		_style_choice_button(btn, ctype, tier)
		
		btn.pressed.connect(_on_button_pressed.bind(c))
		button_container.add_child(btn)
		buttons.append(btn)
		
	is_active = true
	visible = true
	if buttons.size() > 0 and is_inside_tree():
		buttons[0].grab_focus()

func _style_choice_button(btn: Button, ctype: String, tier: int) -> void:
	var tex_normal = load("res://assets/processed/ui/choice_banner.png")
	var tex_hover = load("res://assets/processed/ui/choice_banner_hover.png")
	
	if tex_normal:
		var style_n = StyleBoxTexture.new()
		style_n.texture = tex_normal
		style_n.texture_margin_left = 32
		style_n.texture_margin_right = 32
		style_n.texture_margin_top = 16
		style_n.texture_margin_bottom = 16
		style_n.content_margin_left = 36
		style_n.content_margin_right = 36
		style_n.content_margin_top = 8
		style_n.content_margin_bottom = 8
		btn.add_theme_stylebox_override("normal", style_n)
		
	if tex_hover:
		var style_h = StyleBoxTexture.new()
		style_h.texture = tex_hover
		style_h.texture_margin_left = 32
		style_h.texture_margin_right = 32
		style_h.texture_margin_top = 16
		style_h.texture_margin_bottom = 16
		style_h.content_margin_left = 36
		style_h.content_margin_right = 36
		style_h.content_margin_top = 8
		style_h.content_margin_bottom = 8
		btn.add_theme_stylebox_override("hover", style_h)
		btn.add_theme_stylebox_override("focus", style_h)
		btn.add_theme_stylebox_override("pressed", style_h)

	btn.add_theme_color_override("font_color", Color(0.18, 0.14, 0.12, 1.0))
	btn.add_theme_color_override("font_hover_color", Color(0.55, 0.15, 0.1, 1.0))
	btn.add_theme_color_override("font_focus_color", Color(0.55, 0.15, 0.1, 1.0))
	btn.add_theme_font_size_override("font_size", 17)

	match tier:
		GameState.Tier.TENANG:
			btn.modulate = Color(1, 1, 1, 1)
		GameState.Tier.KESEL:
			if ctype == "jujur":
				btn.modulate = Color(1, 1, 1, 0.75) # Pilihan Jujur sedikit pudar
			else:
				btn.modulate = Color(1, 1, 1, 1)
		GameState.Tier.HAMPIR_MELEDAK:
			if ctype == "jujur":
				btn.modulate = Color(1, 1, 1, 0.55) # Pilihan Jujur pudar
			elif ctype == "ledak" or ctype == "pendam":
				btn.modulate = Color(1.2, 0.8, 0.8, 1.0) # Tebal / bercahaya kemerahan
			else:
				btn.modulate = Color(1, 1, 1, 1)

func _on_button_pressed(choice_data: Dictionary) -> void:
	if not is_active:
		return
	is_active = false
	visible = false
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("select")
	var hud = get_tree().root.find_child("HUD", true, false)
	if hud and hud.has_method("set_timer_display"):
		hud.set_timer_display(0.0, false)
	choice_selected.emit(choice_data)

func _on_timeout() -> void:
	if not is_active:
		return
	is_active = false
	visible = false
	var hud = get_tree().root.find_child("HUD", true, false)
	if hud and hud.has_method("set_timer_display"):
		hud.set_timer_display(0.0, false)
	# Cari pilihan tipe pendam
	var pendam_choice = {}
	for c in current_choices:
		if c.get("type", "").to_lower() == "pendam":
			pendam_choice = c
			break
	if pendam_choice.is_empty() and current_choices.size() > 0:
		pendam_choice = current_choices[0]
	choice_selected.emit(pendam_choice)
