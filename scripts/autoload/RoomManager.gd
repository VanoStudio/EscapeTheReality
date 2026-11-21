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
	"F5": "res://scenes/rooms/F5.tscn"
}

var current_room_id: String = "R1"
var current_room_node: Node = null
var current_player: CharacterBody2D = null
var is_transitioning: bool = false
var fade_overlay: ColorRect = null

# Flag progress kejadian
var k2_finished: bool = false
var photo_puzzle_solved: bool = false

func _ready() -> void:
	_setup_fade_overlay()
	_parse_cli_arguments()

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
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--room="):
			var r = arg.trim_prefix("--room=").to_upper()
			if ROOM_SCENES.has(r):
				current_room_id = r

func register_room(room_node: Node, room_id: String) -> void:
	current_room_node = room_node
	current_room_id = room_id
	GameState.current_room = room_id
	room_changed.emit(room_id)

func register_player(player_node: CharacterBody2D) -> void:
	current_player = player_node
	# Update player jumping capability based on world (R vs F)
	if current_player.has_method("set_can_jump"):
		current_player.set_can_jump(is_fantasy_world())

func is_fantasy_world() -> bool:
	return current_room_id.begins_with("F")

func change_room(target_room_id: String, spawn_at_left: bool = true) -> void:
	if is_transitioning:
		return
	if not ROOM_SCENES.has(target_room_id):
		push_error("RoomManager: Unknown room " + target_room_id)
		return
		
	is_transitioning = true
	transition_started.emit()
	
	if current_player and current_player.has_method("set_movement_enabled"):
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
	
	# Reposition player if registered
	if current_player and current_room_node:
		var spawn_pos = Vector2(30, 210) if spawn_at_left else Vector2(450, 210)
		var marker_name = "SpawnLeft" if spawn_at_left else "SpawnRight"
		if current_room_node.has_node(marker_name):
			spawn_pos = current_room_node.get_node(marker_name).global_position
		current_player.global_position = spawn_pos
		
	# Fade in 0.3s
	var tween_in = create_tween()
	tween_in.tween_property(fade_overlay, "color:a", 0.0, 0.3)
	await tween_in.finished
	
	if current_player and current_player.has_method("set_movement_enabled"):
		current_player.set_movement_enabled(true)
		
	is_transitioning = false
	transition_finished.emit()

func respawn_player() -> void:
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
