extends Node

func _ready() -> void:
	var args = Array(OS.get_cmdline_user_args())
	args.append_array(OS.get_cmdline_args())
	var target_room = RoomManager.current_room_id
	var is_direct_room = false
	var custom_stability = -1
	
	var direct_scene = ""
	for arg in args:
		if arg.begins_with("--scene="):
			var s = arg.trim_prefix("--scene=")
			if s == "opening": direct_scene = "res://scenes/opening.tscn"
			elif s == "ending": direct_scene = "res://scenes/ending.tscn"
			elif s == "menu": direct_scene = "res://scenes/ui/main_menu.tscn"
			elif s == "credits": direct_scene = "res://scenes/credits.tscn"
		elif arg.begins_with("--room="):
			is_direct_room = true
		elif arg.begins_with("--shot="):
			# If shot specifies room, direct to room
			if not arg.contains("opening") and not arg.contains("menu"):
				is_direct_room = true
		elif arg.begins_with("--stability="):
			custom_stability = int(arg.trim_prefix("--stability="))
			
	if custom_stability >= 0:
		var gs = get_node_or_null("/root/GameState")
		if gs:
			gs.stability = custom_stability
			gs.stability_changed.emit(custom_stability, 0)
			gs.tier_changed.emit(gs.get_tier())
			
	if direct_scene != "" and ResourceLoader.exists(direct_scene):
		get_tree().call_deferred("change_scene_to_file", direct_scene)
	elif is_direct_room:
		RoomManager.change_room(target_room, true)
	else:
		if ResourceLoader.exists("res://scenes/ui/main_menu.tscn"):
			get_tree().call_deferred("change_scene_to_file", "res://scenes/ui/main_menu.tscn")
		elif ResourceLoader.exists("res://scenes/opening.tscn"):
			get_tree().call_deferred("change_scene_to_file", "res://scenes/opening.tscn")
		else:
			RoomManager.change_room(target_room, true)
