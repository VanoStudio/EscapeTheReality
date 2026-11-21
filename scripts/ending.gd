extends Control

@export var panel_1: TextureRect
@export var panel_2: TextureRect
@export var text_label: Label
@export var title_credit: Label
@export var team_credit: Label

var step: int = 0

func _ready() -> void:
	if panel_1: panel_1.modulate.a = 0.0
	if panel_2: panel_2.modulate.a = 0.0
	if text_label: text_label.modulate.a = 0.0
	if title_credit: title_credit.modulate.a = 0.0
	if team_credit: team_credit.modulate.a = 0.0
	
	_play_ending_sequence()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		if step >= 3:
			# Kembali ke main / reload
			get_tree().change_scene_to_file("res://scenes/main.tscn")

func _play_ending_sequence() -> void:
	# 1. Fade in Panel 1
	var tween1 = create_tween()
	tween1.tween_property(panel_1, "modulate:a", 1.0, 1.0)
	await tween1.finished
	await get_tree().create_timer(1.2).timeout
	step = 1
	
	# 2. Fade in Panel 2
	var tween2 = create_tween()
	tween2.tween_property(panel_2, "modulate:a", 1.0, 1.0)
	await tween2.finished
	await get_tree().create_timer(1.0).timeout
	step = 2
	
	# 3. Fade in Narasi & Kredit
	var tween3 = create_tween()
	tween3.tween_property(text_label, "modulate:a", 1.0, 0.8)
	tween3.tween_interval(0.5)
	tween3.tween_property(title_credit, "modulate:a", 1.0, 0.8)
	tween3.tween_property(team_credit, "modulate:a", 1.0, 0.8)
	await tween3.finished
	step = 3
