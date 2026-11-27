class_name ChoicePanel
extends Control

const ChoiceStyleScript := preload("res://scripts/ui/choice_style.gd")
const ChoiceCardScript := preload("res://scripts/ui/choice_card.gd")

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
	if (event.is_action_pressed("ui_down") or event.is_action_pressed("ui_up")) and buttons.size() > 0:
		var focused := get_viewport().gui_get_focus_owner()
		if not (focused in buttons):
			buttons[0 if event.is_action_pressed("ui_down") else buttons.size() - 1].grab_focus()
			get_viewport().set_input_as_handled()
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
		
	# Kotak pilihan baru (ChoiceCard): gaya dari data/choice_style.tres, bisa diatur di Inspector.
	var st := ChoiceStyleScript.load_default()
	_layout_container(st)
	for i in range(current_choices.size()):
		var c = current_choices[i]
		var btn = ChoiceCardScript.new()
		btn.setup(st, String(c.get("text", "")), i + 1)
		var ctype = String(c.get("type", "")).to_lower()
		_apply_tier(btn, ctype, tier)
		btn.pressed.connect(_on_button_pressed.bind(c))
		button_container.add_child(btn)
		buttons.append(btn)
		# Muncul satu per satu dari kanan.
		if is_inside_tree():
			var target_mod: Color = btn.modulate
			btn.modulate.a = 0.0
			var tw := btn.create_tween()
			tw.tween_interval(st.appear_stagger * i)
			tw.tween_property(btn, "modulate:a", target_mod.a, 0.22)

	is_active = true
	visible = true
	# Tidak ada tombol yang disorot duluan (dulu tombol pertama terlihat seperti "jawaban benar").
	# Fokus keyboard baru muncul saat pemain menekan panah; angka 1-4 tetap bisa dipakai.
	if is_inside_tree() and get_viewport().gui_get_focus_owner():
		get_viewport().gui_get_focus_owner().release_focus()

func _layout_container(st: ChoiceStyle) -> void:
	if button_container == null:
		return
	button_container.add_theme_constant_override("separation", int(st.gap))
	button_container.alignment = BoxContainer.ALIGNMENT_END
	button_container.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	button_container.offset_right = -st.right_margin
	button_container.offset_left = -st.right_margin - st.card_width
	button_container.offset_bottom = -st.bottom_above_dialog
	button_container.offset_top = -st.bottom_above_dialog - 600.0
	button_container.grow_vertical = Control.GROW_DIRECTION_BEGIN

func _apply_tier(btn: Control, ctype: String, tier: int) -> void:
	match tier:
		1:
			if ctype == "jujur":
				btn.modulate = Color(1, 1, 1, 0.75)
		2:
			if ctype == "jujur":
				btn.modulate = Color(1, 1, 1, 0.55)
			elif ctype == "ledak" or ctype == "pendam":
				btn.modulate = Color(1.2, 0.8, 0.8, 1.0)

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
