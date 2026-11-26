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
		Callable(M4Test, "test_export_presets_configured"),
		Callable(M4Test, "test_comic_data_matches_gdd"),
		Callable(M4Test, "test_comic_player_instantiates"),
		Callable(M4Test, "test_room_fx_config")
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

static func test_comic_data_matches_gdd() -> String:
	if not FileAccess.file_exists("res://data/comic.json"):
		return "data/comic.json missing"
	var d = JSON.parse_string(FileAccess.open("res://data/comic.json", FileAccess.READ).get_as_text())
	if not (d is Dictionary):
		return "comic.json invalid"
	var counts := {"opening": 13, "ending": 2}
	var texts: Array = []
	for cid in counts.keys():
		var n := 0
		for page in d[cid]["pages"]:
			for panel in page["panels"]:
				n += 1
				if not ResourceLoader.exists(panel["image"]):
					return "missing image " + panel["image"]
				if panel.has("balloon"):
					texts.append(panel["balloon"]["text"])
				for b in panel.get("balloons", []):
					texts.append(b["text"])
				# Tulisan SFX tambahan wajib ditandai draft (bukan teks naskah).
				for sx in panel.get("sfx_text", []):
					if not sx.get("draft", false):
						return "sfx_text without draft flag: " + str(sx.get("text", ""))
		if n != counts[cid]:
			return "%s panel count %d != %d" % [cid, n, counts[cid]]
	# Teks persis naskah opening webtoon (urutan cerita, dialog beat 2/5/8 dipecah 2 bubble).
	var expected := [
		"Kak? Kenapa sih?",
		"Kayak nggak ada kehidupan banget. Cerita aja.",
		"Iya, gapapa kok. Aman ini mah.",
		"Lah, gimana sih? Aku bisa jadi pendengar kakak, loh.",
		"Pantes aja kamu ngerasa kayak gitu.",
		"Hancur banget hidupmu, Kak.",
		"Lah, apaan sih? Kamu tuh nggak usah ngatur hidupku!",
		"Ini tuh masalah sepele juga!",
		"Kamu nggak usah segitunya lah!",
		"Lah, nggak jelas banget. Gitu aja nangis."
	]
	if texts != expected:
		return "balloon text differs from script: " + str(texts)
	var outro: Dictionary = d["ending"]["outro"]
	if outro["lines"] != ["Hari pertama selesai. Masih ada dua hari lagi."] or outro["title"] != "Bersambung":
		return "ending text differs from GDD"
	return ""

static func test_comic_player_instantiates() -> String:
	for path in ["res://scenes/opening.tscn", "res://scenes/ending.tscn"]:
		var scene = load(path) as PackedScene
		if scene == null:
			return "cannot load " + path
		var inst = scene.instantiate()
		if inst == null or not inst.has_method("_next"):
			return path + " is not a ComicPlayer"
		inst.free()
	return ""

static func test_room_fx_config() -> String:
	for room_id in ["R1", "R2", "F1", "F2", "F3", "F4", "F5"]:
		var cfg: Dictionary = RoomFX.load_config(room_id)
		if cfg.is_empty():
			return "room_fx.json missing " + room_id
		if not cfg.has("ambient") or not cfg.has("lights"):
			return room_id + " missing ambient/lights"
	return ""
