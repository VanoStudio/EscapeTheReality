extends CanvasLayer

@export var resume_button: Button
@export var restart_button: Button
@export var quit_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
		# Build web: keluar dari game tidak bisa dilakukan dari dalam browser.
		quit_button.visible = not OS.has_feature("web")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		# Jangan buka pause menu jika sedang di scene opening atau ending
		var cur_scene = get_tree().current_scene
		if cur_scene and (cur_scene.name == "Opening" or cur_scene.name == "Ending"):
			return
		_toggle_pause()
		get_viewport().set_input_as_handled()

func _toggle_pause() -> void:
	var new_state = not get_tree().paused
	get_tree().paused = new_state
	visible = new_state
	if visible and resume_button:
		resume_button.grab_focus()

func _on_resume_pressed() -> void:
	get_tree().paused = false
	visible = false

func _on_restart_pressed() -> void:
	get_tree().paused = false
	visible = false
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_method("reset_state"):
		gs.reset_state()
	var rm = get_node_or_null("/root/RoomManager")
	if rm and rm.has_method("change_room"):
		rm.change_room("R1", true)
	else:
		get_tree().change_scene_to_file("res://scenes/rooms/R1.tscn")

func _on_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().quit(0)
