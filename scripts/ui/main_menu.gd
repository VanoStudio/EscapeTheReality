class_name MainMenu
extends Control

@export var start_button: Button
@export var settings_button: Button
@export var credits_button: Button
@export var quit_button: Button

@export var settings_panel: Control
@export var credits_panel: Control

@export var master_slider: HSlider
@export var bgm_slider: HSlider
@export var sfx_slider: HSlider

@export var close_settings_btn: Button
@export var close_credits_btn: Button

func _ready() -> void:
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if credits_button:
		credits_button.pressed.connect(_on_credits_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
		
	if close_settings_btn:
		close_settings_btn.pressed.connect(func(): if settings_panel: settings_panel.visible = false)
	if close_credits_btn:
		close_credits_btn.pressed.connect(func(): if credits_panel: credits_panel.visible = false)
		
	if master_slider:
		master_slider.value_changed.connect(_on_master_volume_changed)
	if bgm_slider:
		bgm_slider.value_changed.connect(_on_bgm_volume_changed)
	if sfx_slider:
		sfx_slider.value_changed.connect(_on_sfx_volume_changed)
		
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_music"):
		am.play_music("fantasy_piano")
		
	_check_pending_screenshot()

func _check_pending_screenshot() -> void:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--shot="):
			var shot_name = arg.trim_prefix("--shot=")
			await get_tree().create_timer(0.3).timeout
			var img = get_viewport().get_texture().get_image()
			img.save_png("res://tests/screenshots/%s.png" % shot_name)
			print("Screenshot captured: res://tests/screenshots/%s.png" % shot_name)
			get_tree().quit(0)
			return

func _on_start_pressed() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("select")
	get_tree().change_scene_to_file("res://scenes/opening.tscn")

func _on_settings_pressed() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("select")
	if settings_panel:
		settings_panel.visible = true
	if credits_panel:
		credits_panel.visible = false

func _on_credits_pressed() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("select")
	if credits_panel:
		credits_panel.visible = true
	if settings_panel:
		settings_panel.visible = false

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_master_volume_changed(val: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(max(val, 0.001)))

func _on_bgm_volume_changed(val: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(max(val, 0.001)))

func _on_sfx_volume_changed(val: float) -> void:
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(max(val, 0.001)))
