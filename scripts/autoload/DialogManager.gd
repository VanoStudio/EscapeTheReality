extends Node

# DialogManager: Orkestrator dialog, pilihan, time-loop, dan integrasi bot autoplay

signal event_finished(event_id: String)

var dialog_box: CanvasLayer = null
var is_active: bool = false
var bot_choice_type: String = ""

var dialog_cache: Dictionary = {}
var system_data: Dictionary = {}
var names_data: Dictionary = {}

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _get_room_manager() -> Node:
	return get_node_or_null("/root/RoomManager")

func _ready() -> void:
	_load_all_data()
	_parse_bot_args()
	_setup_dialog_box()

func _load_all_data() -> void:
	var files = {
		"prolog": "res://data/dialog/prolog.json",
		"k1": "res://data/dialog/k1.json",
		"k2": "res://data/dialog/k2.json",
		"k3": "res://data/dialog/k3.json",
		"rooms": "res://data/dialog/rooms.json",
		"system": "res://data/dialog/system.json",
		"names": "res://data/names.json"
	}
	for k in files.keys():
		var path = files[k]
		if ResourceLoader.exists(path):
			var f = FileAccess.open(path, FileAccess.READ)
			if f:
				dialog_cache[k] = JSON.parse_string(f.get_as_text())
				
	system_data = dialog_cache.get("system", {})
	names_data = dialog_cache.get("names", {})

func _parse_bot_args() -> void:
	var args = Array(OS.get_cmdline_user_args())
	args.append_array(OS.get_cmdline_args())
	for arg in args:
		if arg.begins_with("--bot="):
			bot_choice_type = arg.trim_prefix("--bot=").to_lower()

func _setup_dialog_box() -> void:
	if ResourceLoader.exists("res://scenes/ui/dialog_box.tscn"):
		var scene = load("res://scenes/ui/dialog_box.tscn") as PackedScene
		dialog_box = scene.instantiate() as CanvasLayer
		add_child(dialog_box)

func _freeze_player(freeze: bool) -> void:
	var rm = _get_room_manager()
	if rm and rm.current_player and rm.current_player.has_method("set_movement_enabled"):
		rm.current_player.set_movement_enabled(not freeze)

func is_dialog_active() -> bool:
	return is_active or (dialog_box != null and dialog_box.visible)

func show_shadow_dialog(text: String) -> void:
	if dialog_box == null:
		return
	is_active = true
	_freeze_player(true)
	dialog_box.show_line("bayangan", text, "biasa")
	await dialog_box.line_finished
	dialog_box.close_dialog()
	_freeze_player(false)
	is_active = false

func show_memory_line(key: String) -> void:
	if dialog_box == null:
		return
	var rooms_dict = dialog_cache.get("rooms", {})
	var entry = rooms_dict.get(key, {})
	var text = entry.get("text", "")
	var spk = entry.get("speaker", "kakak")
	if text == "":
		return
		
	is_active = true
	_freeze_player(true)
	dialog_box.show_line(spk, text, "biasa")
	await dialog_box.line_finished
	dialog_box.close_dialog()
	_freeze_player(false)
	is_active = false

func play_prolog() -> void:
	if dialog_box == null:
		return
	var prolog_data = dialog_cache.get("prolog", {})
	var lines = prolog_data.get("lines", [])
	if lines.is_empty():
		return
		
	is_active = true
	_freeze_player(true)
	for item in lines:
		var spk = item.get("speaker", "")
		var txt = item.get("text", "")
		dialog_box.show_line(spk, txt, "biasa")
		if bot_choice_type != "":
			await get_tree().create_timer(0.2).timeout
			dialog_box._finish_typing()
			await get_tree().create_timer(0.1).timeout
		else:
			await dialog_box.line_finished
			
	dialog_box.close_dialog()
	_freeze_player(false)
	is_active = false
	event_finished.emit("prolog")

func play_k1() -> void:
	if dialog_box == null:
		return
	var k1_data = dialog_cache.get("k1", {})
	var rounds = k1_data.get("rounds", [])
	if rounds.is_empty():
		return
		
	is_active = true
	var gs = _get_game_state()
	_freeze_player(true)
	if gs:
		gs.enter_event("k1")
	var r = rounds[0]
	
	# Setup lines
	for line in r.get("setup", []):
		dialog_box.show_line(line.get("speaker", ""), line.get("text", ""), "biasa")
		if bot_choice_type != "":
			await get_tree().create_timer(0.2).timeout
			dialog_box._finish_typing()
			await get_tree().create_timer(0.1).timeout
		else:
			await dialog_box.line_finished
			
	# Prompt pilihan
	var tier = gs.get_tier() if gs else 0
	dialog_box.prompt_choices(r.get("choices", []), tier)
	var selected_choice = {}
	if bot_choice_type != "":
		await get_tree().create_timer(0.2).timeout
		for c in r.get("choices", []):
			if c.get("type", "").to_lower() == bot_choice_type:
				selected_choice = c
				break
		if selected_choice.is_empty() and r.get("choices", []).size() > 0:
			selected_choice = r.get("choices", [])[0]
		dialog_box._on_choice_selected(selected_choice)
	else:
		selected_choice = await dialog_box.choice_resolved
		
	# Terapkan pilihan ke GameState
	var ctype = selected_choice.get("type", "jujur")
	var res = gs.apply_choice(ctype) if gs else {}
	
	# Reaksi penjual
	for reply in selected_choice.get("reply", []):
		dialog_box.show_line(reply.get("speaker", ""), reply.get("text", ""), "biasa")
		if bot_choice_type != "":
			await get_tree().create_timer(0.2).timeout
			dialog_box._finish_typing()
			await get_tree().create_timer(0.1).timeout
		else:
			await dialog_box.line_finished
			
	# Komentar Bayangan (Refleksi)
	_play_shadow_reflection(ctype)
	await dialog_box.line_finished
	
	dialog_box.close_dialog()
	_freeze_player(false)
	is_active = false
	event_finished.emit("k1")

func start_k2_round(round_idx: int) -> void:
	if dialog_box == null:
		return
	var k2_data = dialog_cache.get("k2", {})
	var rounds = k2_data.get("rounds", [])
	if round_idx < 1 or round_idx > rounds.size():
		return
		
	is_active = true
	var gs = _get_game_state()
	_freeze_player(true)
	if round_idx == 1 and gs:
		var penalty = gs.enter_event("k2")
		if penalty > 0:
			var bomb_text = system_data.get("pendam_bomb", {}).get("text", "Inget yang tadi kamu pendam? Aku masih bawa.")
			dialog_box.show_line("bayangan", bomb_text, "biasa")
			if bot_choice_type != "":
				await get_tree().create_timer(0.2).timeout
				dialog_box._finish_typing()
				await get_tree().create_timer(0.1).timeout
			else:
				await dialog_box.line_finished
		
	var r = rounds[round_idx - 1]
	for line in r.get("setup", []):
		dialog_box.show_line(line.get("speaker", ""), line.get("text", ""), "biasa")
		if bot_choice_type != "":
			await get_tree().create_timer(0.2).timeout
			dialog_box._finish_typing()
			await get_tree().create_timer(0.1).timeout
		else:
			await dialog_box.line_finished
			
	var tier = gs.get_tier() if gs else 0
	dialog_box.prompt_choices(r.get("choices", []), tier)
	var selected_choice = {}
	if bot_choice_type != "":
		await get_tree().create_timer(0.2).timeout
		for c in r.get("choices", []):
			if c.get("type", "").to_lower() == bot_choice_type:
				selected_choice = c
				break
		if selected_choice.is_empty() and r.get("choices", []).size() > 0:
			selected_choice = r.get("choices", [])[0]
		dialog_box._on_choice_selected(selected_choice)
	else:
		selected_choice = await dialog_box.choice_resolved
		
	var ctype = selected_choice.get("type", "jujur")
	var res = gs.apply_choice(ctype) if gs else {}
	
	_play_shadow_reflection(ctype)
	await dialog_box.line_finished
	
	dialog_box.close_dialog()
	_freeze_player(false)
	is_active = false
	
	# Cek apakah terjadi time loop
	if res.get("loop", false):
		_trigger_loop_sequence("k2")
		return
		
	var rm = _get_room_manager()
	if round_idx == 1:
		# Lanjut ke ronde 2
		var f3_node = rm.current_room_node if rm else null
		if f3_node and "k2_round" in f3_node:
			f3_node.k2_round = 2
			f3_node.is_k2_active = false
	elif round_idx == 2:
		if rm:
			rm.k2_finished = true
		event_finished.emit("k2")

func start_k3_round(round_idx: int) -> void:
	if dialog_box == null:
		return
	var k3_data = dialog_cache.get("k3", {})
	var rounds = k3_data.get("rounds", [])
	if round_idx < 1 or round_idx > rounds.size():
		return
		
	is_active = true
	var gs = _get_game_state()
	_freeze_player(true)
	if round_idx == 1 and gs:
		var penalty = gs.enter_event("k3")
		if penalty > 0:
			var bomb_text = system_data.get("pendam_bomb", {}).get("text", "Inget yang tadi kamu pendam? Aku masih bawa.")
			dialog_box.show_line("bayangan", bomb_text, "biasa")
			if bot_choice_type != "":
				await get_tree().create_timer(0.2).timeout
				dialog_box._finish_typing()
				await get_tree().create_timer(0.1).timeout
			else:
				await dialog_box.line_finished
		
	var r = rounds[round_idx - 1]
	for line in r.get("setup", []):
		dialog_box.show_line(line.get("speaker", ""), line.get("text", ""), "kaget" if line.get("speaker") == "adik" else "biasa")
		if bot_choice_type != "":
			await get_tree().create_timer(0.2).timeout
			dialog_box._finish_typing()
			await get_tree().create_timer(0.1).timeout
		else:
			await dialog_box.line_finished
			
	var tier = gs.get_tier() if gs else 0
	dialog_box.prompt_choices(r.get("choices", []), tier)
	var selected_choice = {}
	if bot_choice_type != "":
		await get_tree().create_timer(0.2).timeout
		for c in r.get("choices", []):
			if c.get("type", "").to_lower() == bot_choice_type:
				selected_choice = c
				break
		if selected_choice.is_empty() and r.get("choices", []).size() > 0:
			selected_choice = r.get("choices", [])[0]
		dialog_box._on_choice_selected(selected_choice)
	else:
		selected_choice = await dialog_box.choice_resolved
		
	var ctype = selected_choice.get("type", "jujur")
	var res = gs.apply_choice(ctype) if gs else {}
	
	# Cek apakah terjadi time loop global
	if res.get("loop", false):
		_trigger_loop_sequence("k3")
		return
		
	# Di K3, HANYA JUJUR YANG BISA ADVANCE!
	if ctype == "jujur":
		if round_idx == 1:
			_play_shadow_reflection(ctype)
			await dialog_box.line_finished
			dialog_box.close_dialog()
			# Langsung lanjut ke ronde 2 K3
			start_k3_round(2)
		elif round_idx == 2:
			dialog_box.show_line("bayangan", "Itu... yang selama ini aku tunggu.", "biasa")
			await dialog_box.line_finished
			dialog_box.close_dialog()
			_freeze_player(false)
			is_active = false
			event_finished.emit("k3")
			# Tunggu animasi Bayangan menyatu ke Kirana (0.8s) + fadeout (0.4s)
			await get_tree().create_timer(1.2).timeout
			# Pindah ke scene ending
			if ResourceLoader.exists("res://scenes/ending.tscn"):
				get_tree().change_scene_to_file("res://scenes/ending.tscn")
	else:
		# Memory Rewind: selain Jujur, Bayangan menegur dan ulang ronde itu
		dialog_box.show_line("bayangan", "Lagi? Kamu mau ngulang malam itu selamanya?", "biasa")
		await dialog_box.line_finished
		dialog_box.close_dialog()
		# Ulang ronde yang sama
		await get_tree().create_timer(1.0).timeout
		start_k3_round(round_idx)

func _play_shadow_reflection(ctype: String) -> void:
	var shadow_dict = system_data.get("shadow_comments", {})
	var comm = shadow_dict.get(ctype, {})
	var txt = comm.get("text", "")
	if txt != "":
		dialog_box.show_line("bayangan", txt, "biasa")

func _trigger_loop_sequence(event_id: String) -> void:
	dialog_box.show_line("bayangan", "Waktu berputar kembali...", "biasa")
	await dialog_box.line_finished
	dialog_box.close_dialog()
	
	# Efek rewind 1.5 detik
	var hud = get_tree().root.find_child("HUD", true, false)
	if hud and hud.has_method("_on_loop_triggered"):
		hud._on_loop_triggered()
		
	await get_tree().create_timer(1.5).timeout
	_freeze_player(false)
	
	# Restart dari ronde 1 kejadian tsb
	if event_id == "k2":
		start_k2_round(1)
	elif event_id == "k3":
		start_k3_round(1)
