class_name M3Test
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
		Callable(M3Test, "test_hud_scene_load"),
		Callable(M3Test, "test_dialog_box_scene_load"),
		Callable(M3Test, "test_choice_panel_scene_load"),
		Callable(M3Test, "test_choice_panel_show_choices"),
		Callable(M3Test, "test_dialog_box_prompt_choices"),
		Callable(M3Test, "test_shader_resources"),
		Callable(M3Test, "test_f4_photo_puzzle_logic"),
		Callable(M3Test, "test_dialog_manager_cache")
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

static func test_hud_scene_load() -> String:
	if not ResourceLoader.exists("res://scenes/ui/hud.tscn"):
		return "hud.tscn does not exist"
	var scene = load("res://scenes/ui/hud.tscn") as PackedScene
	if scene == null:
		return "Failed to load hud.tscn"
	var inst = scene.instantiate()
	if inst == null:
		return "Failed to instantiate hud.tscn"
	inst.free()
	return ""

static func test_dialog_box_scene_load() -> String:
	if not ResourceLoader.exists("res://scenes/ui/dialog_box.tscn"):
		return "dialog_box.tscn does not exist"
	var scene = load("res://scenes/ui/dialog_box.tscn") as PackedScene
	if scene == null:
		return "Failed to load dialog_box.tscn"
	var inst = scene.instantiate()
	if inst == null:
		return "Failed to instantiate dialog_box.tscn"
	inst.free()
	return ""

static func test_choice_panel_scene_load() -> String:
	if not ResourceLoader.exists("res://scenes/ui/choice_panel.tscn"):
		return "choice_panel.tscn does not exist"
	var scene = load("res://scenes/ui/choice_panel.tscn") as PackedScene
	if scene == null:
		return "Failed to load choice_panel.tscn"
	var inst = scene.instantiate()
	if inst == null:
		return "Failed to instantiate choice_panel.tscn"
	inst.free()
	return ""

static func test_choice_panel_show_choices() -> String:
	var scene = load("res://scenes/ui/choice_panel.tscn") as PackedScene
	var inst = scene.instantiate()
	var test_choices = [
		{"type": "jujur", "text": "Tes jujur"},
		{"type": "pendam", "text": "Tes pendam"}
	]
	# Test with 2 arguments (choices, tier)
	inst.show_choices(test_choices, 1)
	if inst.buttons.size() != 2:
		inst.free()
		return "Expected 2 buttons created with 2 args"
	# Test with 3 arguments (choices, limit, tier)
	inst.show_choices(test_choices, 15.0, 2)
	if inst.buttons.size() != 2:
		inst.free()
		return "Expected 2 buttons created with 3 args"
	inst.free()
	return ""

static func test_dialog_box_prompt_choices() -> String:
	var scene = load("res://scenes/ui/dialog_box.tscn") as PackedScene
	var inst = scene.instantiate()
	var test_choices = [
		{"type": "jujur", "text": "Tes jujur"},
		{"type": "pendam", "text": "Tes pendam"}
	]
	inst.prompt_choices(test_choices, 1)
	inst.free()
	return ""

static func test_shader_resources() -> String:
	var tint_path = "res://shaders/emotion_tint.gdshader"
	var shadow_path = "res://shaders/shadow_character.gdshader"
	if not ResourceLoader.exists(tint_path):
		return "emotion_tint.gdshader missing"
	if not ResourceLoader.exists(shadow_path):
		return "shadow_character.gdshader missing"
	var s1 = load(tint_path)
	var s2 = load(shadow_path)
	if s1 == null or s2 == null:
		return "Failed to load shader resources"
	return ""

static func test_f4_photo_puzzle_logic() -> String:
	state.reset_state()
	if state.photo_scraps != 0:
		return "Initial photo scraps should be 0"
	state.add_photo_scrap()
	state.add_photo_scrap()
	state.add_photo_scrap()
	if state.photo_scraps != 3:
		return "Photo scraps should be 3 after 3 additions, got %d" % state.photo_scraps
	state.add_photo_scrap()
	if state.photo_scraps != 3:
		return "Photo scraps should clamp to 3, got %d" % state.photo_scraps
	return ""

static func test_dialog_manager_cache() -> String:
	var dm_script = load("res://scripts/autoload/DialogManager.gd")
	if dm_script == null:
		return "Failed to load DialogManager.gd"
	return ""
