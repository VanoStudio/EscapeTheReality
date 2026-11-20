class_name M1Test
extends RefCounted

static var state: Node

static func run_all_tests(p_state: Node) -> Dictionary:
	state = p_state
	var results: Dictionary = {
		"passed": 0,
		"failed": 0,
		"errors": []
	}
	
	var tests: Array[Callable] = [
		Callable(M1Test, "test_path_selalu_jujur"),
		Callable(M1Test, "test_path_selalu_memendam"),
		Callable(M1Test, "test_path_selalu_meledak"),
		Callable(M1Test, "test_path_campuran"),
		Callable(M1Test, "test_timeout_counts_as_pendam"),
		Callable(M1Test, "test_stability_clamped_0_to_100"),
		Callable(M1Test, "test_k3_honest_only_advance"),
		Callable(M1Test, "test_loop_resets_to_40_no_bomb_recalc"),
		Callable(M1Test, "test_data_validation")
	]
	
	for t in tests:
		var name: String = t.get_method()
		var err: String = t.call()
		if err == "":
			print("[PASS] " + name)
			results["passed"] += 1
		else:
			print("[FAIL] " + name + " -> " + err)
			results["failed"] += 1
			results["errors"].append(name + ": " + err)
			
	return results

static func test_path_selalu_jujur() -> String:
	state.reset_state()
	if state.stability != 60:
		return "Initial stability should be 60, got %d" % state.stability
	
	# K1 Jujur
	state.apply_choice("jujur")
	if state.stability != 75:
		return "K1 Jujur should be 75, got %d" % state.stability
	
	# Enter K2 (0 pendam)
	state.enter_event("k2")
	if state.stability != 75:
		return "K2 enter should remain 75, got %d" % state.stability
	
	# K2 Round 1 Jujur
	state.apply_choice("jujur")
	if state.stability != 90:
		return "K2 R1 Jujur should be 90, got %d" % state.stability
		
	# K2 Round 2 Jujur (clamped to 100)
	state.apply_choice("jujur")
	if state.stability != 100:
		return "K2 R2 Jujur should clamp to 100, got %d" % state.stability
		
	# Enter K3 (0 pendam)
	state.enter_event("k3")
	if state.stability != 100:
		return "K3 enter should be 100, got %d" % state.stability
		
	# K3 Round 1 Jujur
	state.apply_choice("jujur")
	if state.stability != 100:
		return "K3 R1 Jujur should be 100, got %d" % state.stability
		
	# K3 Round 2 Jujur
	state.apply_choice("jujur")
	if state.stability != 100:
		return "K3 R2 Jujur should be 100, got %d" % state.stability
		
	return ""

static func test_path_selalu_memendam() -> String:
	state.reset_state()
	if state.stability != 60:
		return "Initial stability should be 60, got %d" % state.stability
		
	# K1 Pendam
	state.apply_choice("pendam")
	if state.stability != 65 or state.pendam_count != 1:
		return "K1 Pendam: expected (65, pendam=1), got (%d, %d)" % [state.stability, state.pendam_count]
		
	# Enter K2: bomb -12
	var penalty_k2: int = state.enter_event("k2")
	if penalty_k2 != 12:
		return "K2 penalty expected 12, got %d" % penalty_k2
	if state.stability != 53:
		return "After K2 bomb: expected 53, got %d" % state.stability
		
	# K2 Round 1 Pendam
	state.apply_choice("pendam")
	if state.stability != 58 or state.pendam_count != 2:
		return "K2 R1: expected (58, pendam=2), got (%d, %d)" % [state.stability, state.pendam_count]
		
	# K2 Round 2 Pendam
	state.apply_choice("pendam")
	if state.stability != 63 or state.pendam_count != 3:
		return "K2 R2: expected (63, pendam=3), got (%d, %d)" % [state.stability, state.pendam_count]
		
	# Enter K3: bomb -36
	var penalty_k3: int = state.enter_event("k3")
	if penalty_k3 != 36:
		return "K3 penalty expected 36, got %d" % penalty_k3
	if state.stability != 27:
		return "After K3 bomb: expected 27, got %d" % state.stability
		
	return ""

static func test_path_selalu_meledak() -> String:
	state.reset_state()
	
	# K1 Ledak: 60 -> 40
	var res1: Dictionary = state.apply_choice("ledak")
	if state.stability != 40:
		return "K1 Ledak: expected 40, got %d" % state.stability
	if res1["loop"] != false:
		return "K1 Ledak should not trigger loop"
		
	# Enter K2: 0 pendam -> 40
	state.enter_event("k2")
	if state.stability != 40:
		return "K2 enter: expected 40, got %d" % state.stability
		
	# K2 Round 1 Ledak: 40 -> 20
	var res2: Dictionary = state.apply_choice("ledak")
	if state.stability != 20:
		return "K2 R1 Ledak: expected 20, got %d" % state.stability
	if res2["loop"] != false:
		return "K2 R1 Ledak should not trigger loop"
		
	# K2 Round 2 Ledak: 20 -> 0 -> Loop triggered! Reset to 40
	var res3: Dictionary = state.apply_choice("ledak")
	if res3["loop"] != true:
		return "K2 R2 Ledak should trigger loop"
	if state.stability != 40:
		return "After loop trigger, stability should reset to 40, got %d" % state.stability
		
	return ""

static func test_path_campuran() -> String:
	state.reset_state()
	
	# K1 Pendam: 60 -> 65 (pendam=1)
	state.apply_choice("pendam")
	if state.stability != 65:
		return "K1 Pendam: expected 65, got %d" % state.stability
		
	# Enter K2: bomb -12 -> 53
	state.enter_event("k2")
	if state.stability != 53:
		return "K2 enter: expected 53, got %d" % state.stability
		
	# K2 R1 Sindir: 53 -> 43 (pendam stays 1)
	state.apply_choice("sindir")
	if state.stability != 43 or state.pendam_count != 1:
		return "K2 R1 Sindir: expected (43, pendam=1), got (%d, %d)" % [state.stability, state.pendam_count]
		
	# K2 R2 Jujur: 43 -> 58 (pendam reset to 0)
	state.apply_choice("jujur")
	if state.stability != 58 or state.pendam_count != 0:
		return "K2 R2 Jujur: expected (58, pendam=0), got (%d, %d)" % [state.stability, state.pendam_count]
		
	# Enter K3: bomb 0 (pendam=0) -> 58
	state.enter_event("k3")
	if state.stability != 58:
		return "K3 enter: expected 58, got %d" % state.stability
		
	# K3 R1 Jujur: 58 -> 73
	state.apply_choice("jujur")
	if state.stability != 73:
		return "K3 R1 Jujur: expected 73, got %d" % state.stability
		
	# K3 R2 Jujur: 73 -> 88
	state.apply_choice("jujur")
	if state.stability != 88:
		return "K3 R2 Jujur: expected 88, got %d" % state.stability
		
	return ""

static func test_timeout_counts_as_pendam() -> String:
	state.reset_state()
	var res: Dictionary = state.on_timeout()
	if state.stability != 65:
		return "Timeout should increase stability to 65 (+5), got %d" % state.stability
	if state.pendam_count != 1:
		return "Timeout should increase pendam_count to 1, got %d" % state.pendam_count
	return ""

static func test_stability_clamped_0_to_100() -> String:
	state.reset_state()
	# Boost past 100
	state.apply_choice("jujur") # 75
	state.apply_choice("jujur") # 90
	state.apply_choice("jujur") # 100
	state.apply_choice("jujur") # 100
	if state.stability > 100:
		return "Stability should not exceed 100, got %d" % state.stability
		
	# Check tier
	if state.get_tier() != 0: # 0 is TENANG
		return "Tier at stability 100 should be TENANG"
		
	return ""

static func test_k3_honest_only_advance() -> String:
	if not state.can_advance_k3("jujur"):
		return "jujur should advance K3"
	if state.can_advance_k3("pendam"):
		return "pendam should not advance K3"
	if state.can_advance_k3("sindir"):
		return "sindir should not advance K3"
	if state.can_advance_k3("ledak"):
		return "ledak should not advance K3"
	return ""

static func test_loop_resets_to_40_no_bomb_recalc() -> String:
	state.reset_state()
	state.pendam_count = 2
	state.enter_event("k2") # 60 - 24 = 36
	if state.stability != 36:
		return "Expected 36, got %d" % state.stability
		
	# Cause loop
	state.apply_choice("ledak") # 36 - 20 = 16
	state.apply_choice("ledak") # 16 - 20 = -4 -> triggers loop! Reset to 40
	if state.stability != 40:
		return "Expected 40 on loop, got %d" % state.stability
		
	# Re-enter K2 event (simulating loop rewind)
	var bomb_recalc: int = state.enter_event("k2")
	if bomb_recalc != 0:
		return "Bomb should not be recalculated on loop, got penalty %d" % bomb_recalc
	if state.stability != 40:
		return "Stability should remain 40 after loop re-enter K2, got %d" % state.stability
		
	return ""

static func test_data_validation() -> String:
	# 1. Names
	var names_file: FileAccess = FileAccess.open("res://data/names.json", FileAccess.READ)
	if names_file == null:
		return "data/names.json missing"
	var names_json = JSON.parse_string(names_file.get_as_text())
	if not (names_json is Dictionary):
		return "data/names.json is not a JSON object"
	var valid_speakers: Array = names_json.keys()
	if not ("kakak" in valid_speakers and "adik" in valid_speakers and "bayangan" in valid_speakers and "penjual" in valid_speakers):
		return "names.json missing standard speakers"
		
	# 2. Check events K1, K2, K3
	var event_files: Array[String] = ["res://data/dialog/k1.json", "res://data/dialog/k2.json", "res://data/dialog/k3.json"]
	var required_types: Array[String] = ["jujur", "pendam", "sindir", "ledak"]
	
	for file_path in event_files:
		var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			return "Missing dialog file: " + file_path
		var data = JSON.parse_string(file.get_as_text())
		if not (data is Dictionary and data.has("rounds")):
			return "Invalid schema in " + file_path
			
		var rounds: Array = data["rounds"]
		if rounds.is_empty():
			return "No rounds in " + file_path
			
		for r_idx in range(rounds.size()):
			var r = rounds[r_idx]
			if not r.has("choices") or r["choices"].size() != 4:
				return "Round %d in %s does not have exactly 4 choices" % [r_idx, file_path]
				
			var types_found: Array[String] = []
			for choice in r["choices"]:
				var ctype: String = choice.get("type", "")
				var ctext: String = choice.get("text", "")
				if ctext.strip_edges() == "":
					return "Empty text in choice %s of %s" % [ctype, file_path]
				types_found.append(ctype)
				
				# Check replies if present
				if choice.has("reply"):
					for reply in choice["reply"]:
						var spk: String = reply.get("speaker", "")
						var txt: String = reply.get("text", "")
						if not (spk in valid_speakers):
							return "Unknown speaker '%s' in reply in %s" % [spk, file_path]
						if txt.strip_edges() == "":
							return "Empty reply text in %s" % file_path
							
			for req in required_types:
				if not (req in types_found):
					return "Missing choice type '%s' in round %d of %s" % [req, r_idx, file_path]
					
			# Check setup lines
			if r.has("setup"):
				for line in r["setup"]:
					var spk: String = line.get("speaker", "")
					var txt: String = line.get("text", "")
					if not (spk in valid_speakers):
						return "Unknown setup speaker '%s' in %s" % [spk, file_path]
					if txt.strip_edges() == "":
						return "Empty setup text in %s" % file_path

	# 3. Check prolog.json
	var prolog_file: FileAccess = FileAccess.open("res://data/dialog/prolog.json", FileAccess.READ)
	if prolog_file == null:
		return "prolog.json missing"
	var prolog_data = JSON.parse_string(prolog_file.get_as_text())
	if not prolog_data.has("lines"):
		return "prolog.json missing 'lines'"
	for line in prolog_data["lines"]:
		if not (line.get("speaker", "") in valid_speakers):
			return "Unknown speaker in prolog: " + line.get("speaker", "")
		if line.get("text", "").strip_edges() == "":
			return "Empty text in prolog line"
			
	# 4. Check rooms.json
	var rooms_file: FileAccess = FileAccess.open("res://data/dialog/rooms.json", FileAccess.READ)
	if rooms_file == null:
		return "rooms.json missing"
	var rooms_data = JSON.parse_string(rooms_file.get_as_text())
	for key in rooms_data.keys():
		var item = rooms_data[key]
		if not (item.get("speaker", "") in valid_speakers):
			return "Unknown speaker in rooms.json key: " + key
		if item.get("text", "").strip_edges() == "":
			return "Empty text in rooms.json key: " + key
			
	# 5. Check system.json
	var system_file: FileAccess = FileAccess.open("res://data/dialog/system.json", FileAccess.READ)
	if system_file == null:
		return "system.json missing"
	var system_data = JSON.parse_string(system_file.get_as_text())
	if not system_data.has("shadow_comments"):
		return "system.json missing shadow_comments"
	for type_key in system_data["shadow_comments"].keys():
		var comm = system_data["shadow_comments"][type_key]
		if comm.get("text", "").strip_edges() == "":
			return "Empty shadow comment for " + type_key
			
	return ""
