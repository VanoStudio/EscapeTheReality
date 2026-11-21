extends Node

func _ready() -> void:
	# Cek apakah ada argumen CLI room
	var target_room = RoomManager.current_room_id
	var args = OS.get_cmdline_user_args()
	var skip_opening = false
	for arg in args:
		if arg == "--skip-opening" or arg.begins_with("--room="):
			skip_opening = true
			
	if skip_opening:
		RoomManager.change_room(target_room, true)
	else:
		# Jika opening scene ada, buka opening; jika belum, masuk ke R1
		if ResourceLoader.exists("res://scenes/opening.tscn"):
			get_tree().change_scene_to_file("res://scenes/opening.tscn")
		else:
			RoomManager.change_room("R1", true)
