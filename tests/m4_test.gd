class_name M4Test
extends RefCounted

static func run_all_tests() -> Dictionary:
	var results: Dictionary = {
		"passed": 0,
		"failed": 0,
		"errors": []
	}
	
	var tests: Array[Callable] = [
		Callable(M4Test, "test_opening_scene_load"),
		Callable(M4Test, "test_ending_scene_load"),
		Callable(M4Test, "test_pause_menu_scene_load"),
		Callable(M4Test, "test_audio_manager_load"),
		Callable(M4Test, "test_export_presets_configured")
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

static func test_opening_scene_load() -> String:
	if not ResourceLoader.exists("res://scenes/opening.tscn"):
		return "scenes/opening.tscn missing"
	var scene = load("res://scenes/opening.tscn") as PackedScene
	if scene == null:
		return "Failed to load opening.tscn"
	var inst = scene.instantiate()
	if inst == null:
		return "Failed to instantiate opening.tscn"
	inst.free()
	return ""

static func test_ending_scene_load() -> String:
	if not ResourceLoader.exists("res://scenes/ending.tscn"):
		return "scenes/ending.tscn missing"
	var scene = load("res://scenes/ending.tscn") as PackedScene
	if scene == null:
		return "Failed to load ending.tscn"
	var inst = scene.instantiate()
	if inst == null:
		return "Failed to instantiate ending.tscn"
	inst.free()
	return ""

static func test_pause_menu_scene_load() -> String:
	if not ResourceLoader.exists("res://scenes/ui/pause_menu.tscn"):
		return "scenes/ui/pause_menu.tscn missing"
	var scene = load("res://scenes/ui/pause_menu.tscn") as PackedScene
	if scene == null:
		return "Failed to load pause_menu.tscn"
	var inst = scene.instantiate()
	if inst == null:
		return "Failed to instantiate pause_menu.tscn"
	inst.free()
	return ""

static func test_audio_manager_load() -> String:
	if not ResourceLoader.exists("res://scripts/autoload/AudioManager.gd"):
		return "AudioManager.gd missing"
	var script = load("res://scripts/autoload/AudioManager.gd")
	if script == null:
		return "Failed to load AudioManager.gd"
	return ""

static func test_export_presets_configured() -> String:
	if not FileAccess.file_exists("res://export_presets.cfg"):
		return "export_presets.cfg missing"
	var f = FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	if f == null:
		return "Could not open export_presets.cfg"
	var content = f.get_as_text()
	if not "Windows Desktop" in content:
		return "Windows Desktop preset missing in export_presets.cfg"
	return ""
