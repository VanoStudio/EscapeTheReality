class_name M5Test
extends RefCounted

# Rombak FLOW KIRANA: teks persis PDF, ruangan baru, level parkour, state makan/kertas/trauma.

const FLOW_PATH := "res://data/dialog/flow.json"
const ParkourScript := preload("res://scripts/rooms/p1_layout.gd")
const GameStateScript := preload("res://scripts/autoload/GameState.gd")

static func run_all_tests() -> Dictionary:
	var results: Dictionary = {"passed": 0, "failed": 0, "errors": []}
	var tests: Array[Callable] = [
		Callable(M5Test, "test_flow_text_matches_pdf"),
		Callable(M5Test, "test_flow_drafts_marked"),
		Callable(M5Test, "test_flow_rooms_load"),
		Callable(M5Test, "test_parkour_layout"),
		Callable(M5Test, "test_flow_state"),
		Callable(M5Test, "test_opening_leads_to_front_house"),
		Callable(M5Test, "test_merge_input_exists"),
		Callable(M5Test, "test_parkour_jumps_reachable"),
		Callable(M5Test, "test_energy_drain"),
		Callable(M5Test, "test_rework2_assets"),
		Callable(M5Test, "test_menu_and_credits")
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

static func _flow() -> Dictionary:
	if not FileAccess.file_exists(FLOW_PATH):
		return {}
	var d = JSON.parse_string(FileAccess.open(FLOW_PATH, FileAccess.READ).get_as_text())
	return d if d is Dictionary else {}

static func _texts(lines: Array) -> Array:
	var out: Array = []
	for l in lines:
		out.append(l["text"])
	return out

static func test_flow_text_matches_pdf() -> String:
	var f := _flow()
	if f.is_empty():
		return "flow.json missing or invalid"
	var fh: Dictionary = f["front_house"]
	if [fh["lapar"]["text"], fh["jendela"]["text"], fh["jam"]["text"], fh["aah"]["text"]] != [
		"duh laper banget.. kenapa sih ada aja masalah dirumah tuh?",
		"haduh keluar cari makan, pulang lagi males!",
		"lho itu jam apa?",
		"AAH!!!!"]:
		return "front_house text differs from PDF"
	if f["arrival"]["shout"]["text"] != "AAHHH! Ini dimana sih?!!?":
		return "arrival shout differs"
	if _texts(f["arrival"]["lines"]) != [
		"Hai. Akhirnya ya? Ketemu juga.",
		"kamu siapa? disini ada makanan gak sih? aku lapar!",
		"kamu ini ya, memang sering banget nahan lapar.",
		"Ikuti aku, masuk saja pintu bercahaya di belakangku ini"]:
		return "arrival lines differ"
	var mb: Dictionary = f["mbok_luna"]
	if _texts(mb["intro"]).size() != 7 or mb["intro"][6]["text"] != "Hehe... sudahlah. Kamu sudah jauh-jauh datang, mau Mbok siapkan makanan?":
		return "mbok intro differs"
	var ch: Array = mb["choices"]
	if ch.size() != 2 or ch[0]["text"] != "Boleh... kalau nggak merepotkan." or ch[1]["text"] != "Enggak usah, Mbok. Aku nggak lapar.":
		return "mbok choices differ"
	if ch[0]["reply"].back()["text"] != "Nanti juga kamu akan tahu." or ch[1]["reply"].back()["text"] != "Tidak semua perjalanan bisa ditempuh dengan tenaga yang sama.":
		return "mbok replies differ"
	for c in ch:
		for l in c["reply"]:
			if not (l["speaker"] in ["kakak", "penjual"]):
				return "unknown speaker in mbok reply"
	return ""

static func test_flow_drafts_marked() -> String:
	var f := _flow()
	for l in f["mission"]["lines"]:
		if not l.get("draft", false):
			return "mission line not marked draft"
	var pk: Dictionary = f["parkour"]
	for key in ["heavy", "trauma_warn", "merge_tutorial", "collapse", "portal_incomplete", "portal_complete", "finale", "assist"]:
		if not pk[key].get("draft", false):
			return "parkour/%s not marked draft" % key
	if pk["papers"].size() != 4:
		return "need 4 paper lines"
	for l in pk["papers"]:
		if not l.get("draft", false):
			return "paper line not marked draft"
	var wake: Dictionary = f["mbok_wake"]
	for l in wake["lines"] + wake["reply_mau"] + wake["reply_tidak"] + wake["rested"] + [wake["offer"], wake["shadow"]]:
		if not l.get("draft", false):
			return "mbok_wake line not marked draft: " + l["text"]
	# Gema trauma diambil persis dari naskah opening (bukan draft).
	var opening_lines := ["Hancur banget hidupmu, Kak.", "Pantes aja kamu ngerasa kayak gitu.", "Lah, nggak jelas banget. Gitu aja nangis.", "Lah, gimana sih? Aku bisa jadi pendengar kakak, loh."]
	for e in pk["trauma_echoes"]:
		if not (e["text"] in opening_lines):
			return "trauma echo not from opening script: " + e["text"]
	return ""

static func test_flow_rooms_load() -> String:
	# Dibaca sebagai teks: skrip ruangan butuh autoload yang tidak ada di runner headless.
	for path in ["res://scenes/rooms/R2.tscn", "res://scenes/rooms/F1.tscn", "res://scenes/rooms/F2.tscn", "res://scenes/rooms/P1.tscn"]:
		if not FileAccess.file_exists(path):
			return "missing " + path
		var txt := FileAccess.open(path, FileAccess.READ).get_as_text()
		if not txt.contains("[node name=\"Kirana\"") or not txt.contains("SpawnLeft"):
			return path + " needs Kirana and SpawnLeft"
	for p in ["res://assets/processed/flow/portal.png", "res://assets/processed/flow/bg_front_house.jpg", "res://assets/processed/flow/bg_arrival.jpg", "res://assets/processed/flow/bg_market.jpg", "res://assets/processed/flow/bg_space.jpg", "res://assets/processed/flow/platform_1.png"]:
		if not ResourceLoader.exists(p):
			return "missing asset " + p
	return ""

static func test_parkour_layout() -> String:
	if ParkourScript.PAPERS.size() != 4:
		return "parkour needs exactly 4 papers"
	var movable := 0
	for row in ParkourScript.LEVEL:
		if row[0] == "movable":
			movable += 1
			var opt: Dictionary = row[4]
			var b: Rect2 = opt["bounds"]
			var target: Vector2 = opt["target"]
			if not b.has_point(target) or not b.has_point(Vector2(row[2], row[3])):
				return "movable start/target outside bounds at %s" % str(target)
	if movable != 3:
		return "expected 3 movable blocks (1 for paper 3, 2 for paper 4), got %d" % movable
	if ParkourScript.TRAUMAS.size() < 4:
		return "need trauma zones on every tier"
	# Pola arah: kertas 1 kiri, 2 kanan, 3 kiri, 4 kanan; tiap kertas lebih tinggi.
	var p: Array = ParkourScript.PAPERS
	if not (p[0].x < 300 and p[1].x > 700 and p[2].x < 300 and p[3].x > 700):
		return "papers must alternate left/right"
	if not (p[0].y > p[1].y and p[1].y > p[2].y and p[2].y > p[3].y):
		return "papers must climb upward"
	return ""

static func test_flow_state() -> String:
	var gs = GameStateScript.new()
	if gs.has_heavy_legs():
		gs.free()
		return "heavy legs before choice"
	gs.set_food_choice(false)
	if not gs.has_heavy_legs():
		gs.free()
		return "refusing food should give heavy legs"
	gs.set_food_choice(true)
	if gs.has_heavy_legs():
		gs.free()
		return "eating should not give heavy legs"
	gs.collect_paper(0)
	gs.collect_paper(0)
	gs.collect_paper(2)
	if gs.papers.size() != 2 or gs.has_all_papers():
		gs.free()
		return "paper collection should dedupe"
	gs.stability = 20
	var collapsed: bool = gs.apply_trauma(12)
	if collapsed or gs.stability != 8:
		gs.free()
		return "trauma 20-12 should be 8"
	collapsed = gs.apply_trauma(12)
	if not collapsed or gs.stability != gs.tuning.stability_loop_reset:
		gs.free()
		return "trauma past zero should collapse to loop reset"
	gs.reset_state()
	if gs.papers.size() != 0 or gs.food_answered:
		gs.free()
		return "reset_state should clear flow state"
	gs.free()
	return ""

static func test_opening_leads_to_front_house() -> String:
	var d = JSON.parse_string(FileAccess.open("res://data/comic.json", FileAccess.READ).get_as_text())
	if d["opening"]["next"] != "room:R2":
		return "opening should lead to room:R2 (depan rumah)"
	return ""

static func test_merge_input_exists() -> String:
	if not InputMap.has_action("merge"):
		return "input action 'merge' (Q) missing"
	return ""

# Semua lompatan antar pulau di jalur utama harus terjangkau, juga dengan "kaki berat".
static func _flight_time(v: float, g: float, rise: float) -> float:
	var d := v * v - 2.0 * g * rise
	if d < 0.0:
		return -1.0
	return (v + sqrt(d)) / g

static func test_parkour_jumps_reachable() -> String:
	var W := {"L": 150.0, "M": 80.0, "S": 42.0, "G": 170.0}
	var path: Array = []
	for row in ParkourScript.LEVEL:
		var x: float = row[2]
		var y: float = row[3]
		var xs: Array = [x]
		if row[0] == "movable":
			var t: Vector2 = row[4]["target"]
			x = t.x
			y = t.y
			xs = [x]
		elif row[0] == "moving":
			xs = [x, x + float(row[4]["patrol"].x)]
		path.append({"w": W[row[1]], "xs": xs, "y": y})
	for prof in [[-ParkourScript.JUMP, ParkourScript.WALK, 20.0, "normal"], [-ParkourScript.JUMP * 0.9, ParkourScript.WALK * 0.88, 6.0, "heavy"]]:
		for i in range(path.size() - 1):
			var a: Dictionary = path[i]
			var b: Dictionary = path[i + 1]
			var best := -INF
			for ax in a["xs"]:
				var bx: float = b["xs"][0]
				var wa: float = a["w"] * 0.48
				var wb: float = b["w"] * 0.48
				var gap: float = ((bx - wb) - (ax + wa)) if bx > ax else ((ax - wa) - (bx + wb))
				gap -= 11.0
				var tt := _flight_time(prof[0], ParkourScript.GRAVITY, a["y"] - b["y"])
				if tt < 0.0:
					continue
				best = maxf(best, prof[1] * tt - 6.0 - gap)
			if best < prof[2]:
				return "%s: hop %d -> %d margin %.1f < %.1f" % [prof[3], i, i + 1, best, prof[2]]
	return ""

static func test_energy_drain() -> String:
	var gs = GameStateScript.new()
	gs.set_energy(20)
	var out: bool = gs.drain(15)
	if out or gs.stability != 5:
		gs.free()
		return "20-15 should be 5 without collapse"
	out = gs.drain(15)
	if not out or gs.stability != 0:
		gs.free()
		return "draining past zero should stop at 0 and report collapse"
	gs.collect_paper(0)
	gs.collect_paper(1)
	if gs.next_missing_paper() != 2:
		gs.free()
		return "next missing paper should be 2"
	gs.free()
	return ""

static func test_rework2_assets() -> String:
	for i in range(1, 5):
		if not ResourceLoader.exists("res://assets/processed/flow/photo_piece_%d.png" % i):
			return "missing photo piece %d" % i
	var meta = JSON.parse_string(FileAccess.open("res://assets/processed/flow/photo_pieces.json", FileAccess.READ).get_as_text())
	if not (meta is Dictionary) or meta["pieces"].size() != 4:
		return "photo_pieces.json must list 4 pieces"
	for n in ["idle_12f.png", "walk_12f.png"]:
		var path: String = "res://assets/processed/characters/kirana_rumah/spritesheets_strip_12x1/" + String(n)
		var tex := load(path) as Texture2D
		if tex == null or tex.get_width() != 3072 or tex.get_height() != 256:
			return n + " must be a 3072x256 strip"
	return ""

static func test_menu_and_credits() -> String:
	var c = JSON.parse_string(FileAccess.open("res://data/credits.json", FileAccess.READ).get_as_text())
	if not (c is Dictionary) or c["by"] != "By: ERINA APRILIA & STEVANO SUNUPRAKOSO SOSRORAHARJO" or c["thanks"] != "THANK YOU PAK SEPTIAN & FRIENDS! :3":
		return "credits.json text differs from owner's text"
	var d = JSON.parse_string(FileAccess.open("res://data/comic.json", FileAccess.READ).get_as_text())
	if d["ending"]["outro"].get("credits_scene", "") != "res://scenes/credits.tscn":
		return "ending must hand off to the credits scene"
	for f in ["menu_bg.jpg", "menu_swirl.jpg", "menu_bokeh.jpg", "menu_mist.jpg", "menu_frame.png", "menu_kirana.png", "menu_logo.png"]:
		if not ResourceLoader.exists("res://assets/processed/menu/" + f):
			return "missing menu layer " + f
	if not ResourceLoader.exists("res://scenes/credits.tscn"):
		return "credits scene missing"
	return ""
