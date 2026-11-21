extends Node

func _ready() -> void:
	var args = OS.get_cmdline_user_args()
	var target_room = RoomManager.current_room_id
	var skip_opening = false
	var custom_stability = -1
	
	for arg in args:
		if arg.begins_with("--room=") or arg.begins_with("--shot="):
			skip_opening = true
		elif arg.begins_with("--stability="):
			custom_stability = int(arg.trim_prefix("--stability="))
		elif arg == "--skip-opening":
			skip_opening = true
			
	if custom_stability >= 0:
		var gs = get_node_or_null("/root/GameState")
		if gs:
			gs.stability = custom_stability
			gs.stability_changed.emit(custom_stability, 0)
			gs.tier_changed.emit(gs.get_tier())
			
	if skip_opening:
		RoomManager.change_room(target_room, true)
	else:
		if ResourceLoader.exists("res://scenes/opening.tscn"):
			get_tree().call_deferred("change_scene_to_file", "res://scenes/opening.tscn")
		else:
			RoomManager.change_room(target_room, true)
