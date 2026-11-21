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
		var hud = get_tree().root.find_child("HUD", true, false)
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

func show_choices(choices: Array, tier: int) -> void:
	current_choices = choices.duplicate()
	# Acak pilihan setiap ronde tampil
	current_choices.shuffle()
	
	# Hapus tombol lama
	for child in button_container.get_children():
		child.queue_free()
	buttons.clear()
	
	# Tentukan timer per tier
	match tier:
		GameState.Tier.TENANG:
			time_limit = 0.0
		GameState.Tier.KESEL:
			time_limit = 30.0
		GameState.Tier.HAMPIR_MELEDAK:
			time_limit = 15.0
			
	time_remaining = time_limit
	if timer_bar:
		timer_bar.visible = time_limit > 0.0
		timer_bar.max_value = time_limit
		timer_bar.value = time_limit
		
	# Buat 4 tombol
	for i in range(current_choices.size()):
		var c = current_choices[i]
		var btn = Button.new()
		btn.text = "%d. %s" % [i + 1, c.get("text", "")]
		btn.custom_minimum_size = Vector2(500, 48)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		var ctype = c.get("type", "").to_lower()
		_style_choice_button(btn, ctype, tier)
		
		btn.pressed.connect(_on_button_pressed.bind(c))
		button_container.add_child(btn)
		buttons.append(btn)
		
	is_active = true
	visible = true
	if buttons.size() > 0:
		buttons[0].grab_focus()

func _style_choice_button(btn: Button, ctype: String, tier: int) -> void:
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
