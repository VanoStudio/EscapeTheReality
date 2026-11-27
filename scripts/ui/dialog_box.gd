class_name DialogBox
extends CanvasLayer

signal line_finished()
signal dialog_completed()
signal choice_resolved(choice: Dictionary)

@export var portrait_rect: TextureRect
@export var speaker_label: Label
@export var text_label: RichTextLabel
@export var next_indicator: Control
@export var choice_panel: Control

var current_text: String = ""
var visible_chars: int = 0
var typing_speed: float = 0.02
var typing_timer: float = 0.0
var is_typing: bool = false
var is_waiting_for_input: bool = false
var is_waiting_for_choice: bool = false
var cached_am: Node = null

var shadow_material: ShaderMaterial

func _ready() -> void:
	layer = 20
	visible = false
	cached_am = get_node_or_null("/root/AudioManager")
	_setup_shadow_material()
	if choice_panel:
		choice_panel.choice_selected.connect(_on_choice_selected)

func _setup_shadow_material() -> void:
	if ResourceLoader.exists("res://shaders/shadow_character.gdshader"):
		var shader = load("res://shaders/shadow_character.gdshader") as Shader
		shadow_material = ShaderMaterial.new()
		shadow_material.shader = shader

func _process(delta: float) -> void:
	if is_typing:
		typing_timer += delta
		if typing_timer >= typing_speed:
			typing_timer = 0.0
			visible_chars += 1
			text_label.visible_characters = visible_chars
			if visible_chars % 2 == 1 and cached_am:
				cached_am.play_sfx("text_blip")
			if visible_chars >= current_text.length():
				_finish_typing()

func _finish_typing() -> void:
	is_typing = false
	text_label.visible_characters = -1
	if not is_waiting_for_choice:
		is_waiting_for_input = true
		if next_indicator:
			next_indicator.visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
		
	if is_typing and (event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept")):
		_finish_typing()
		get_viewport().set_input_as_handled()
	elif is_waiting_for_input and (event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept")):
		is_waiting_for_input = false
		if next_indicator:
			next_indicator.visible = false
		line_finished.emit()
		get_viewport().set_input_as_handled()

func show_line(speaker_key: String, text: String, expression: String = "biasa") -> void:
	visible = true
	is_waiting_for_input = false
	is_waiting_for_choice = false
	if next_indicator:
		next_indicator.visible = false
	if choice_panel:
		choice_panel.visible = false
		
	# Update speaker name & portrait
	_update_speaker(speaker_key, expression)
	
	current_text = text
	text_label.text = text
	text_label.visible_characters = 0
	visible_chars = 0
	typing_timer = 0.0
	is_typing = true

func _get_asset_registry() -> Node:
	return get_node_or_null("/root/AssetRegistry")

func _update_speaker(speaker_key: String, expression: String) -> void:
	var spk = speaker_key.to_lower()
	var names_data = {}
	if ResourceLoader.exists("res://data/names.json"):
		var f = FileAccess.open("res://data/names.json", FileAccess.READ)
		if f:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				names_data = parsed
			
	var display_name = names_data.get(spk, spk.capitalize())
	if speaker_label:
		speaker_label.text = display_name
		
	var ar = _get_asset_registry()
	if portrait_rect and ar:
		portrait_rect.material = null # Reset shader
		var tex: Texture2D = null
		
		match spk:
			"kakak":
				var key = "kakak_" + expression
				tex = ar.get_portrait(key)
				if tex == null:
					tex = ar.get_portrait("kakak_biasa")
			"adik":
				var key = "adik_" + expression
				tex = ar.get_portrait(key)
				if tex == null:
					tex = ar.get_portrait("adik_biasa")
			"penjual":
				tex = ar.get_portrait("penjual")
			"suara_adik", "adik_cermin":
				tex = ar.get_portrait("adik_biasa")
			"bayangan_adik":
				# Sosok Adik yang berubah jadi bayangan hitam.
				tex = ar.get_portrait("adik_biasa")
				portrait_rect.material = shadow_material
			"bayangan":
				# Gunakan potret Kirana dengan shadow shader
				tex = ar.get_portrait("kakak_biasa")
				portrait_rect.material = shadow_material
			_:
				tex = ar.get_portrait("kakak_biasa")
				
		portrait_rect.texture = tex

## Pilihan biasa tanpa batas waktu dan tanpa efek tier (mis. tawaran makan Mbok Luna).
func prompt_simple_choices(choices: Array) -> void:
	is_waiting_for_choice = true
	is_waiting_for_input = false
	if next_indicator:
		next_indicator.visible = false
	if choice_panel:
		choice_panel.show_choices(choices, 0.0, 0)

func prompt_choices(choices: Array, tier: int) -> void:
	is_waiting_for_choice = true
	is_waiting_for_input = false
	if next_indicator:
		next_indicator.visible = false
	if choice_panel:
		choice_panel.show_choices(choices, tier)

func _on_choice_selected(choice_data: Dictionary) -> void:
	is_waiting_for_choice = false
	choice_resolved.emit(choice_data)

func close_dialog() -> void:
	visible = false
	is_typing = false
	is_waiting_for_input = false
	is_waiting_for_choice = false
	if choice_panel:
		choice_panel.visible = false
	dialog_completed.emit()
