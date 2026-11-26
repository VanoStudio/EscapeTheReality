extends Node

# RoomManager: Mengatur perpindahan 7 ruangan, transisi layar, loop tangga F3, dan respawn void

signal room_changed(new_room_id: String)
signal transition_started()
signal transition_finished()

const ROOM_SCENES = {
	"R1": "res://scenes/rooms/R1.tscn",
	"R2": "res://scenes/rooms/R2.tscn",
	"F1": "res://scenes/rooms/F1.tscn",
	"F2": "res://scenes/rooms/F2.tscn",
	"F3": "res://scenes/rooms/F3.tscn",
	"F4": "res://scenes/rooms/F4.tscn",
	"F5": "res://scenes/rooms/F5.tscn",
	"P1": "res://scenes/rooms/P1.tscn"
}

var current_room_id: String = "R1"
var current_room_node: Node = null
var current_player: CharacterBody2D = null
var is_transitioning: bool = false
var fade_overlay: ColorRect = null

# Flag progress kejadian
var k2_finished: bool = false
var photo_puzzle_solved: bool = false
var hud_instance: Node = null
var pause_instance: Node = null
var pending_screenshot: String = ""
var next_spawn_left: bool = true
# Debug CLI: --shot_delay=<detik> (tunda screenshot), --pos=x,y (taruh Kirana di titik itu).
var shot_delay: float = 0.0
var debug_pos := Vector2.INF

func _ready() -> void:
	_setup_fade_overlay()
	_setup_hud()
	_setup_pause_menu()
	_parse_cli_arguments()

func _setup_hud() -> void:
	if ResourceLoader.exists("res://scenes/ui/hud.tscn"):
		var scene = load("res://scenes/ui/hud.tscn") as PackedScene
		hud_instance = scene.instantiate()
		hud_instance.name = "HUD"
		add_child(hud_instance)

func _setup_pause_menu() -> void:
	if ResourceLoader.exists("res://scenes/ui/pause_menu.tscn"):
		var scene = load("res://scenes/ui/pause_menu.tscn") as PackedScene
		pause_instance = scene.instantiate()
		pause_instance.name = "PauseMenu"
		add_child(pause_instance)

func _setup_fade_overlay() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.name = "TransitionCanvas"
	add_child(canvas)
	
	fade_overlay = ColorRect.new()
	fade_overlay.name = "FadeOverlay"
	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(fade_overlay)

func _parse_cli_arguments() -> void:
	var args = Array(OS.get_cmdline_user_args())
	args.append_array(OS.get_cmdline_args())
	for arg in args:
		if arg.begins_with("--room="):
			var r = arg.trim_prefix("--room=").to_upper()
			if ROOM_SCENES.has(r):
				current_room_id = r
		elif arg.begins_with("--shot="):
			pending_screenshot = arg.trim_prefix("--shot=")
		elif arg.begins_with("--shot_delay="):
			shot_delay = float(arg.trim_prefix("--shot_delay="))
		elif arg.begins_with("--pos="):
			var xy = arg.trim_prefix("--pos=").split(",")
			if xy.size() == 2:
				debug_pos = Vector2(float(xy[0]), float(xy[1]))

func _reposition_player() -> void:
	if is_instance_valid(current_player) and is_instance_valid(current_room_node):
		var marker_name = "SpawnLeft" if next_spawn_left else "SpawnRight"
		if current_room_node.has_node(marker_name):
			current_player.global_position = current_room_node.get_node(marker_name).global_position

func register_room(room_node: Node, room_id: String) -> void:
	if hud_instance:
		hud_instance.visible = true
	current_room_node = room_node
	current_room_id = room_id
	GameState.current_room = room_id
	_reposition_player()
	room_changed.emit(room_id)

func register_player(player_node: CharacterBody2D) -> void:
	current_player = player_node
	# Update player jumping capability based on world (R vs F)
	if current_player.has_method("set_can_jump"):
		current_player.set_can_jump(is_fantasy_world())
	if current_player.has_method("update_character_visual"):
		current_player.update_character_visual(is_fantasy_world())
	_reposition_player()

func is_fantasy_world() -> bool:
	return current_room_id.begins_with("F") or current_room_id.begins_with("P")

func change_room(target_room_id: String, spawn_at_left: bool = true) -> void:
	if is_transitioning:
		return
	if not ROOM_SCENES.has(target_room_id):
		push_error("RoomManager: Unknown room " + target_room_id)
		return
		
	is_transitioning = true
	transition_started.emit()
	next_spawn_left = spawn_at_left
	
	if is_instance_valid(current_player) and current_player.has_method("set_movement_enabled"):
		current_player.set_movement_enabled(false)
		
	# Fade out 0.3s
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.3)
	await tween.finished
	
	# Ganti scene ruangan
	current_room_id = target_room_id
	GameState.current_room = target_room_id
	var scene_path = ROOM_SCENES[target_room_id]
	get_tree().change_scene_to_file(scene_path)
	
	# Tunggu frame agar scene baru siap
	await get_tree().process_frame
	await get_tree().process_frame
	
	_reposition_player()
		
	# Fade in 0.3s
	var tween_in = create_tween()
	tween_in.tween_property(fade_overlay, "color:a", 0.0, 0.3)
	await tween_in.finished
	
	if is_instance_valid(current_player) and current_player.has_method("set_movement_enabled"):
		current_player.set_movement_enabled(true)
		
	is_transitioning = false
	transition_finished.emit()
	
	if pending_screenshot != "":
		var sname = pending_screenshot
		pending_screenshot = ""
		_save_screenshot(sname)

func _save_screenshot(shot_name: String) -> void:
	if debug_pos != Vector2.INF and is_instance_valid(current_player):
		current_player.global_position = debug_pos
		if current_room_node and current_room_node.has_method("_snap_camera"):
			current_room_node._snap_camera()
	if shot_delay > 0.0:
		await get_tree().create_timer(shot_delay).timeout
	for i in range(5):
		await get_tree().process_frame
	var dir = DirAccess.open("res://")
	if not dir.dir_exists("tests/screenshots"):
		dir.make_dir_recursive("tests/screenshots")
	var img = get_viewport().get_texture().get_image()
	img.save_png("res://tests/screenshots/%s.png" % shot_name)
	print("Screenshot captured: res://tests/screenshots/%s.png" % shot_name)
	get_tree().quit(0)

func respawn_player() -> void:
	if current_player and current_room_node and current_room_node.has_method("on_player_fell"):
		current_room_node.on_player_fell(current_player)
		return
	if current_player and current_room_node:
		var spawn_pos = Vector2(30, 210)
		if current_room_node.has_node("SpawnLeft"):
			spawn_pos = current_room_node.get_node("SpawnLeft").global_position
		current_player.velocity = Vector2.ZERO
		current_player.global_position = spawn_pos

func handle_f3_loop() -> void:
	# Khusus F3: Keluar kanan masuk kiri sampai K2 selesai
	if current_player and current_room_node:
		var left_x = 20.0
		if current_room_node.has_node("SpawnLeft"):
			left_x = current_room_node.get_node("SpawnLeft").global_position.x
		current_player.global_position.x = left_x

## Pindah ke scene non-ruangan (mis. ending comic): HUD disembunyikan, layar fade.
func go_to_scene(scene_path: String) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.4)
	await tween.finished
	if hud_instance:
		hud_instance.visible = false
	current_player = null
	current_room_node = null
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	var tween_in = create_tween()
	tween_in.tween_property(fade_overlay, "color:a", 0.0, 0.4)
	await tween_in.finished
	is_transitioning = false
