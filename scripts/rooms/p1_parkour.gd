class_name ParkourTower
extends BaseRoom

# Menara pulau melayang (FLOW KIRANA hal. 6), rombak #2 (keseimbangan pemula..pro).
# - 4 pecahan foto keluarga, pola arah bergantian per tingkat.
# - Energi (bar 0..100): trauma / jatuh / mendarat keras mengurangi, kertas / lentera / bekal memulihkan.
#   Kena trauma TIDAK teleport: Kirana terpental, kebal sebentar, lanjut jalan.
#   Jatuh ke kehampaan -> kembali ke pijakan aman terakhir.
#   Energi 0 -> pingsan, bangun di Mbok Luna (F2), kembali lewat portal ke tingkat kertas berikutnya.
# - Bantuan Bayangan: gagal 3x di tingkat yang sama -> pijakan bantuan + trauma melambat.
# - Ambil kertas: kamera mendekat, pecahan foto ditunjukkan, dialog, lalu lanjut.
# - Dekat portal dengan 4 pecahan: pecahan menyatu jadi foto utuh, masuk ke Kirana, Kirana masuk portal.
# Data tata letak & angka keseimbangan: scripts/rooms/p1_layout.gd.

const IslandScript := preload("res://scripts/props/floating_island.gd")
const PaperScript := preload("res://scripts/props/paper_pickup.gd")
const TraumaScript := preload("res://scripts/props/trauma_zone.gd")
const LanternScript := preload("res://scripts/props/checkpoint_lantern.gd")
const PortalScript := preload("res://scripts/props/portal_gate.gd")
const FoodScript := preload("res://scripts/props/food_pickup.gd")
const FollowerScript := preload("res://scripts/actors/bayangan_follower.gd")
const GateScript := preload("res://scripts/props/echo_gate.gd")
const L := preload("res://scripts/rooms/p1_layout.gd")

const WORLD := Rect2(0, 140, 1000, 1010)
const CAM_ZOOM := 3.6
const BODY_SCALE := 0.62
const MERGE_RANGE := 300.0
const BUBBLE_OFFSET := Vector2(0, -54)
const PIECE_DIR := "res://assets/processed/flow/"

var kill_y := 1230.0
var safe_pos := Vector2(930, 1080)
var shadow: FollowerScript
var final_portal: PortalScript
var movables: Array = []
var traumas: Array = []
var merging := false
var merge_block: Node = null
var invuln := 0.0
var echo_idx := 0
var finishing := false
var cutscene := false
var autotest := false
var bg_rect: TextureRect
var fx_layer: CanvasLayer
var flash_rect: ColorRect
var echo_label: Label
var shake := 0.0
var cam_zoom_target := CAM_ZOOM
var fails := [0, 0, 0, 0]
var assisted := [false, false, false, false]
var _aura_t := 0.0
var _blink_t := 0.0
var _finale_warned := false
var _cam_look_until := 0.0
var checkpoint_idx := 0
var _recall_hold := 0.0
var gates: Array = []
var echo_running := false
var _shadow_hide_t := 0.0
var _cam_focus := Vector2.INF

func _ready() -> void:
	super._ready()
	_build_backdrop()
	_build_fx()
	var gs = get_node_or_null("/root/GameState")
	var start_tier := 0
	# Debug CLI: --debug_papers=N -> anggap N pecahan pertama sudah diambil.
	for arg in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if gs and String(arg).begins_with("--debug_papers="):
			for i in range(int(String(arg).trim_prefix("--debug_papers="))):
				gs.collect_paper(i)
	if gs:
		if not gs.parkour_started:
			gs.parkour_started = true
			gs.set_energy(L.ENERGY_HEAVY if gs.has_heavy_legs() else L.ENERGY_ATE)
		start_tier = clampi(gs.next_missing_paper(), 0, 3)
		checkpoint_idx = maxi(gs.checkpoint_idx, _tier_start_checkpoint(start_tier))
		gs.checkpoint_idx = checkpoint_idx
	_build_level(start_tier)
	var k = _find_player()
	if k:
		k.set_body_scale(BODY_SCALE)
		k.set_physics_profile(L.WALK, L.JUMP, L.GRAVITY)
		k.set_feel(L.COYOTE, L.JUMP_BUFFER, L.APEX_GRAVITY, L.MAX_FALL)
		if gs and gs.has_heavy_legs():
			k.set_heavy_legs(true)
		k.global_position = L.CHECKPOINTS[checkpoint_idx]
		k.reset_air()
		k.face_left(start_tier % 2 == 0)
		k.landed.connect(_on_landed)
		safe_pos = k.global_position
		# Bayangan ikut dari jauh tapi tidak terlihat; muncul hanya saat ada perlu.
		shadow = FollowerScript.new()
		shadow.start_visible = false
		add_child(shadow)
		shadow.setup(k)
	_snap_camera()
	if "--autotest" in OS.get_cmdline_user_args() or "--autotest" in OS.get_cmdline_args():
		_autotest.call_deferred()
		return
	if "--autotest_collapse" in OS.get_cmdline_user_args() or "--autotest_collapse" in OS.get_cmdline_args():
		_autotest_collapse.call_deferred()
		return
	_intro(start_tier)

# ---------------------------------------------------------------- kamera

func _setup_camera() -> void:
	if camera == null:
		camera = get_node_or_null("Camera2D")
		if camera == null:
			camera = Camera2D.new()
			camera.name = "Camera2D"
			add_child(camera)
	camera.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)
	camera.limit_left = int(WORLD.position.x)
	camera.limit_top = int(WORLD.position.y)
	camera.limit_right = int(WORLD.end.x)
	camera.limit_bottom = int(WORLD.end.y)
	camera.make_current()

func _cam_target() -> Vector2:
	if _cam_focus != Vector2.INF:
		return _cam_focus
	if _cam_look_until > 0.0:
		return L.FINAL_PORTAL + Vector2(0, -40)
	var k = _find_player()
	if k == null:
		return WORLD.get_center()
	var p: Vector2 = k.global_position + Vector2(0, -30)
	if merging and is_instance_valid(merge_block):
		p = p.lerp(merge_block.global_position, 0.5)
	return p

func _snap_camera() -> void:
	if camera:
		camera.position = _cam_target()

func _process(delta: float) -> void:
	if camera:
		camera.position = camera.position.lerp(_cam_target(), 1.0 - exp(-5.0 * delta))
		var z := lerpf(camera.zoom.x, cam_zoom_target, 1.0 - exp(-4.0 * delta))
		camera.zoom = Vector2(z, z)
		if shake > 0.0:
			shake = maxf(shake - delta * 2.5, 0.0)
			camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * 6.0 * shake * shake
		else:
			camera.offset = Vector2.ZERO
		if bg_rect:
			var rel := (camera.position - WORLD.get_center()) / WORLD.size
			bg_rect.position = Vector2(-110, -80) - rel * Vector2(160, 120)
	if _cam_look_until > 0.0:
		_cam_look_until -= delta
	if invuln > 0.0:
		invuln -= delta
		_blink(delta)
	if _shadow_hide_t > 0.0:
		_shadow_hide_t -= delta
		if _shadow_hide_t <= 0.0 and not merging and shadow:
			shadow.fade_to(0.0, 0.8)
	_update_merge(delta)
	_update_recall(delta)
	var kk = _find_player()
	if kk:
		for g in gates:
			if is_instance_valid(g) and not g.solved:
				g.set_nearness(1.0 - clampf((kk.global_position.distance_to(g.global_position) - 30.0) / 120.0, 0.0, 1.0))

func _blink(delta: float) -> void:
	var k = _find_player()
	if k == null or cutscene or merging:
		return
	_blink_t += delta
	k.modulate.a = 1.0 if invuln <= 0.0 else (0.45 if int(_blink_t * 12.0) % 2 == 0 else 1.0)

func _physics_process(_delta: float) -> void:
	# Catat pijakan aman terakhir (pulau diam, tidak di dekat zona trauma diam).
	var k = _find_player()
	if k == null or cutscene or finishing:
		return
	var cp: Vector2 = L.CHECKPOINTS[checkpoint_idx]
	# Jatuh jauh di bawah checkpoint (ke tingkat bawah): tarik kembali, jangan suruh memanjat ulang.
	if k.global_position.y > cp.y + L.DEEP_FALL and k.global_position.y < kill_y:
		on_player_fell(k)
		return
	if not k.is_on_floor():
		return
	for i in range(k.get_slide_collision_count()):
		var col = k.get_slide_collision(i).get_collider()
		if col is IslandScript and (col.kind == "static" or (col.kind == "movable" and col.locked)):
			var half: float = col.width * 0.48 - 8.0
			var p := Vector2(clampf(k.global_position.x, col.global_position.x - half, col.global_position.x + half), col.global_position.y)
			# Pijakan aman hanya di tingkat checkpoint atau lebih tinggi (bukan setelah jatuh ke bawah).
			if not _near_static_trauma(p) and p.y <= cp.y + 40.0:
				safe_pos = p
			break

func _near_static_trauma(p: Vector2) -> bool:
	for z in traumas:
		if z.patrol == Vector2.ZERO and absf(z.position.x - p.x) < 30.0 and absf(z.position.y - p.y) < 30.0:
			return true
	return false

## Pembicara gerbang diambil dari naskah (flow.json), supaya sosok di kabut selalu cocok:
## suara_adik = hanya suara, adik = siluet Adik, adik_cermin = pantulan, bayangan_adik = bayangan hitam.
func _echo_speaker(id: String) -> String:
	var dm = _dm()
	if dm:
		var r = dm.flow("echo/%s/rounds" % id)
		if r is Array and not r.is_empty():
			return String(r[0].get("speaker", "adik"))
	return "adik"

func _tier_start_checkpoint(tier: int) -> int:
	return [0, 3, 6, 9][clampi(tier, 0, 3)]

func _reach_checkpoint(idx: int) -> void:
	# Checkpoint tidak boleh melewati pecahan yang belum diambil (kalau pemain melewatkan pecahan
	# lalu turun lagi untuk mengambilnya, ia tidak boleh ditarik kembali ke atas).
	var gs0 = _gs()
	if gs0:
		var miss: int = gs0.next_missing_paper()
		if miss < L.PAPER_CHECKPOINT.size():
			idx = mini(idx, L.PAPER_CHECKPOINT[miss])
	if idx <= checkpoint_idx:
		return
	checkpoint_idx = idx
	var gs = _gs()
	if gs:
		gs.checkpoint_idx = idx

## Tahan R: kembali ke checkpoint (kalau tersangkut).
func _update_recall(delta: float) -> void:
	var k = _find_player()
	if k == null or cutscene or finishing or merging or echo_running or _dialog_busy():
		_recall_hold = 0.0
		return
	if Input.is_key_pressed(KEY_R):
		_recall_hold += delta
		if _recall_hold >= L.RECALL_HOLD:
			_recall_hold = 0.0
			if not _damage(L.DMG_RECALL):
				_warp(k, L.CHECKPOINTS[checkpoint_idx])
	else:
		_recall_hold = 0.0

func _warp(k: Node2D, pos: Vector2) -> void:
	k.set_movement_enabled(false)
	k.velocity = Vector2.ZERO
	k.global_position = pos
	k.reset_air()
	safe_pos = pos
	_snap_camera()
	invuln = 0.8
	k.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(k, "modulate:a", 1.0, 0.35)
	await t.finished
	if not cutscene and not finishing and not echo_running:
		k.set_movement_enabled(true)

## Bayangan muncul sebentar (bicara/bantu), lalu memudar lagi.
func _shadow_show(hold: float = 3.0) -> void:
	if shadow == null:
		return
	shadow.fade_to(0.85, 0.4)
	_shadow_hide_t = hold

# ---------------------------------------------------------------- bangun level

func _build_backdrop() -> void:
	var layer := CanvasLayer.new()
	layer.layer = -10
	add_child(layer)
	bg_rect = TextureRect.new()
	bg_rect.texture = load("res://assets/processed/flow/bg_space.jpg") as Texture2D
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_rect.size = Vector2(2140, 1240)
	bg_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	layer.add_child(bg_rect)

	var stars := CPUParticles2D.new()
	stars.texture = RoomFX.dot_texture()
	stars.amount = 120
	stars.lifetime = 9.0
	stars.preprocess = 9.0
	stars.position = WORLD.get_center()
	stars.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	stars.emission_rect_extents = WORLD.size * 0.5
	stars.gravity = Vector2(0, -3)
	stars.initial_velocity_min = 1.0
	stars.initial_velocity_max = 5.0
	stars.scale_amount_min = 0.03
	stars.scale_amount_max = 0.1
	stars.color = Color(0.75, 0.9, 1.0, 0.7)
	stars.z_index = -5
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	stars.material = mat
	add_child(stars)

	var tint := CanvasModulate.new()
	tint.color = Color(0.86, 0.86, 0.95)
	add_child(tint)

func _build_fx() -> void:
	fx_layer = CanvasLayer.new()
	fx_layer.layer = 40
	add_child(fx_layer)
	flash_rect = ColorRect.new()
	flash_rect.color = Color(0.6, 0.0, 0.12, 0.0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(flash_rect)
	echo_label = Label.new()
	echo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	echo_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	echo_label.position = Vector2(160, 150)
	echo_label.size = Vector2(1600, 200)
	echo_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	echo_label.add_theme_font_size_override("font_size", 56)
	echo_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.94))
	echo_label.add_theme_color_override("font_outline_color", Color(0.35, 0.0, 0.08))
	echo_label.add_theme_constant_override("outline_size", 14)
	_apply_bold(echo_label)
	echo_label.modulate.a = 0.0
	echo_label.pivot_offset = echo_label.size * 0.5
	fx_layer.add_child(echo_label)

func _apply_bold(c: Control) -> void:
	var bold := "res://assets/processed/fonts/comic_dialog_bold.ttf"
	if ResourceLoader.exists(bold):
		c.add_theme_font_override("font", load(bold) as Font)

func _build_level(start_tier: int) -> void:
	var gs = get_node_or_null("/root/GameState")
	for row in L.LEVEL:
		var isl = IslandScript.new()
		isl.kind = row[0]
		isl.variant = row[1]
		isl.position = Vector2(row[2], row[3])
		if row.size() > 4:
			var opt: Dictionary = row[4]
			if opt.has("patrol"):
				isl.patrol = opt["patrol"]
				isl.patrol_speed = opt.get("speed", 0.25)
			if opt.has("target"):
				isl.target = opt["target"]
				isl.bounds = opt["bounds"]
		add_child(isl)
		if isl.kind == "movable":
			movables.append(isl)
			isl.placed.connect(_on_block_placed)
	# Tingkat 3 sudah selesai (kertas 3 ada) -> batunya langsung terpasang.
	if gs and gs.papers.has(2) and movables.size() > 0:
		movables[0].force_lock.call_deferred()
	for i in range(L.PAPERS.size()):
		if gs and gs.papers.has(i):
			continue
		var p = PaperScript.new()
		p.index = i
		p.piece_texture = load(PIECE_DIR + "photo_piece_%d.png" % (i + 1)) as Texture2D
		p.position = L.PAPERS[i]
		add_child(p)
		p.collected.connect(_on_paper)
	for i in range(L.LANTERNS.size()):
		var l = LanternScript.new()
		l.position = L.LANTERNS[i]
		add_child(l)
		var cp_idx: int = L.CHECKPOINTS.find(L.LANTERNS[i])
		l.set_meta("cp", cp_idx)
		if cp_idx <= checkpoint_idx:
			l.light_up(true)
		l.reached.connect(_on_lantern)
	for gdef in L.ECHO_GATES:
		if gs and gs.echo_done.has(gdef["id"]):
			continue
		var g = GateScript.new()
		g.gate_id = gdef["id"]
		g.speaker = _echo_speaker(gdef["id"])
		g.figure_scale = 0.35 * BODY_SCALE
		g.wall_height = gdef["h"]
		g.trigger_rect = gdef["trigger"]
		g.position = gdef["wall"]
		add_child(g)
		g.triggered.connect(_on_gate)
		gates.append(g)
	for tz in L.TRAUMAS:
		var z = TraumaScript.new()
		z.position = tz[0]
		z.size = tz[1]
		z.patrol = tz[2]
		z.patrol_speed = tz[3]
		add_child(z)
		z.hit.connect(_on_trauma)
		traumas.append(z)
	for pos in L.FOODS:
		var f = FoodScript.new()
		f.position = pos
		add_child(f)
		f.collected.connect(func(_p: Node) -> void: _heal(L.HEAL_FOOD))
	final_portal = PortalScript.new()
	final_portal.height = 78.0
	final_portal.position = L.FINAL_PORTAL
	final_portal.z_index = -1
	add_child(final_portal)
	final_portal.open(0.01)
	var fz: Rect2 = L.FINALE_ZONE
	_add_trigger(fz.get_center(), fz.size, _on_finale_zone, false)
	_add_trigger(Vector2(650, 1040), Vector2(24, 70), _warn_trauma)
	_add_trigger(Vector2(745, 660), Vector2(24, 70), _merge_tutorial)

func _add_trigger(pos: Vector2, size: Vector2, cb: Callable, once: bool = true) -> Area2D:
	var a := Area2D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	a.position = pos
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	a.add_child(cs)
	add_child(a)
	a.body_entered.connect(func(b: Node2D) -> void:
		if b.is_in_group("player") and a.monitoring:
			if once:
				a.set_deferred("monitoring", false)
			cb.call())
	return a

# ---------------------------------------------------------------- narasi kecil

func _dm() -> Node:
	return get_node_or_null("/root/DialogManager")

func _gs() -> Node:
	return get_node_or_null("/root/GameState")

func _hint(text: String, dur: float = 4.0) -> void:
	var hud = RoomManager.hud_instance
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text, dur)

func _refresh_hud() -> void:
	var hud = RoomManager.hud_instance
	if hud and hud.has_method("update_hud"):
		hud.update_hud()

func _bubble(who: Node2D, path: String, style: String = "speech", hold: float = -1.0) -> Node:
	var dm = _dm()
	if dm == null or who == null:
		return null
	var off := BUBBLE_OFFSET if who == _find_player() else Vector2(0, -50)
	if who == shadow:
		_shadow_show(4.0)
	return dm.bubble(who, dm.flow(path), style, hold, off)

func _intro(start_tier: int) -> void:
	_refresh_hud()
	await get_tree().create_timer(0.8).timeout
	var gs = _gs()
	if start_tier == 0 and gs and gs.has_heavy_legs():
		var b = _bubble(_find_player(), "parkour/heavy", "hollow")
		if b:
			await b.finished
	if gs and gs.has_all_papers():
		_hint("Semua pecahan terkumpul  ·  pergi ke portal di puncak", 5.0)
	elif start_tier == 0:
		_hint("Kumpulkan 4 pecahan foto  ·  Spasi / W  lompat (tahan = lebih tinggi)", 6.0)
		await get_tree().create_timer(6.5).timeout
		_hint("Tersangkut?  Tahan R  kembali ke checkpoint", 4.5)
	else:
		_hint("Lanjut cari pecahan ke-%d" % (start_tier + 1), 4.0)

func _warn_trauma() -> void:
	if shadow:
		_bubble(shadow, "parkour/trauma_warn", "cold")

func _merge_tutorial() -> void:
	if shadow:
		_bubble(shadow, "parkour/merge_tutorial", "speech")
	_hint("Tahan Q  menyatu  ·  A / D / W / S  geser batu", 6.0)

# ---------------------------------------------------------------- energi

func _popup(text: String, color: Color) -> void:
	var k = _find_player()
	if k == null:
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 40)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
	l.add_theme_constant_override("outline_size", 10)
	_apply_bold(l)
	fx_layer.add_child(l)
	var sp: Vector2 = get_viewport().get_canvas_transform() * (k.global_position + Vector2(0, -60))
	l.position = sp - Vector2(40, 20)
	var t := create_tween().set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 60.0, 1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.6)
	await t.finished
	l.queue_free()

func _heal(amount: int) -> void:
	var gs = _gs()
	if gs == null:
		return
	gs.heal(amount)
	_popup("+%d" % amount, Color(0.55, 1.0, 0.85))

## Kurangi energi. Hasil true kalau energi habis (Kirana pingsan).
func _damage(amount: int) -> bool:
	var gs = _gs()
	if gs == null:
		return false
	var out: bool = gs.drain(amount)
	_popup("-%d" % amount, Color(1.0, 0.45, 0.5))
	if out:
		_collapse()
	return out

func _fail() -> void:
	var k = _find_player()
	if k == null:
		return
	var tier := L.tier_of(k.global_position.y)
	fails[tier] += 1
	if fails[tier] >= L.ASSIST_AFTER and not assisted[tier]:
		_assist(tier)

func _assist(tier: int) -> void:
	# Bayangan membantu: pijakan tambahan + zona trauma di tingkat ini melambat.
	assisted[tier] = true
	for pos in L.ASSISTS[tier]:
		var isl = IslandScript.new()
		isl.kind = "static"
		isl.variant = "S"
		isl.position = pos
		add_child(isl)
		isl.sprite.modulate = Color(0.75, 0.6, 1.2, 0.0)
		create_tween().tween_property(isl.sprite, "modulate:a", 0.9, 0.8)
	for z in traumas:
		if L.tier_of(z.position.y) == tier:
			z.patrol_speed *= 0.6
	if shadow:
		_bubble(shadow, "parkour/assist", "speech")

func _on_lantern(lan: Node) -> void:
	_reach_checkpoint(int(lan.get_meta("cp", 0)))
	_heal(L.HEAL_LANTERN)

# ---------------------------------------------------------------- trauma & jatuh

func _on_trauma(zone: Node) -> void:
	if invuln > 0.0 or merging or finishing or cutscene:
		return
	invuln = L.INVULN_SEC
	_blink_t = 0.0
	var k = _find_player()
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("impact", 0.6, -3.0)
		am.play_sfx("heartbeat", 1.2, -2.0)
	shake = 0.8
	flash_rect.color.a = 0.45
	create_tween().tween_property(flash_rect, "color:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_show_echo()
	if k:
		var dir := signf(k.global_position.x - zone.global_position.x)
		if dir == 0.0:
			dir = -1.0
		k.knockback(Vector2(dir * 150.0, -200.0), 0.3)
	_fail()
	_damage(L.DMG_TRAUMA)

func _show_echo() -> void:
	var dm = _dm()
	if dm == null:
		return
	var echoes = dm.flow("parkour/trauma_echoes")
	if not (echoes is Array) or echoes.is_empty():
		return
	echo_label.text = String(echoes[echo_idx % echoes.size()].get("text", ""))
	echo_idx += 1
	echo_label.scale = Vector2(1.15, 1.15)
	var t := create_tween().set_parallel(true)
	t.tween_property(echo_label, "modulate:a", 1.0, 0.15)
	t.tween_property(echo_label, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_interval(1.2)
	t.chain().tween_property(echo_label, "modulate:a", 0.0, 0.5)

func _on_landed(drop: float) -> void:
	if drop <= L.LAND_SAFE_DROP or invuln > 0.0 or cutscene or finishing:
		return
	var dmg := clampi(L.DMG_LAND_MIN + int((drop - L.LAND_SAFE_DROP) / 25.0), L.DMG_LAND_MIN, L.DMG_LAND_MAX)
	shake = 0.5
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("land", 0.7, 2.0)
	_damage(dmg)

func on_player_fell(player: Node2D) -> void:
	if finishing:
		return
	if invuln > 0.5:
		return
	_fail()
	if _damage(L.DMG_VOID):
		return
	_warp(player, safe_pos)

func _collapse() -> void:
	# Energi habis: pingsan, bangun di pasar Mbok Luna.
	if finishing:
		return
	finishing = true
	_end_merge()
	var k = _find_player()
	if k:
		k.set_movement_enabled(false)
	if shadow:
		_bubble(shadow, "parkour/collapse", "cold")
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(black)
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("heartbeat", 0.8)
	await create_tween().tween_property(black, "color:a", 1.0, 1.6).set_trans(Tween.TRANS_SINE).finished
	var gs = _gs()
	if gs:
		gs.wake_pending = true
	RoomManager.change_room("F2", true)

# ---------------------------------------------------------------- menyatu dengan Bayangan

func _nearest_movable() -> Node:
	var k = _find_player()
	if k == null:
		return null
	var best: Node = null
	var best_d := MERGE_RANGE
	for m in movables:
		if m.locked:
			continue
		var d: float = k.global_position.distance_to(m.global_position)
		if d < best_d:
			best_d = d
			best = m
	return best

func _update_merge(delta: float) -> void:
	var k = _find_player()
	if k == null or finishing or autotest or cutscene:
		return
	var held := Input.is_action_pressed("merge")
	if not merging:
		if held and k.is_on_floor() and not _dialog_busy():
			var m = _nearest_movable()
			if m:
				_start_merge(m)
		return
	if not held or not is_instance_valid(merge_block) or merge_block.locked:
		_end_merge()
		return
	var dir := Vector2(Input.get_axis("move_left", "move_right"), 0.0)
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		dir.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		dir.y += 1.0
	merge_block.drive(dir.limit_length(1.0), delta)
	_aura_t += delta
	k.modulate = Color(0.75, 1.1, 1.15).lerp(Color(0.55, 1.2, 1.25), 0.5 + 0.5 * sin(_aura_t * 5.0))

func _dialog_busy() -> bool:
	var dm = _dm()
	return dm != null and dm.is_dialog_active()

func _start_merge(m: Node) -> void:
	merging = true
	merge_block = m
	var k = _find_player()
	k.set_movement_enabled(false)
	m.set_controlled(true)
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("rewind", 1.5, -10.0)
	if shadow:
		# Bayangan muncul sekejap lalu masuk ke tubuh Kirana.
		shadow.active = false
		shadow.modulate.a = 0.85
		var t := create_tween().set_parallel(true)
		t.tween_property(shadow, "global_position", k.global_position, 0.3).set_trans(Tween.TRANS_SINE)
		t.tween_property(shadow, "modulate:a", 0.0, 0.35)

func _end_merge() -> void:
	if not merging:
		return
	merging = false
	if is_instance_valid(merge_block):
		merge_block.set_controlled(false)
	merge_block = null
	var k = _find_player()
	if k:
		k.modulate = Color.WHITE
		k.set_movement_enabled(true)
	if shadow:
		shadow.active = true
		shadow.fade_to(0.0, 0.3)

func _on_block_placed(_block: Node) -> void:
	_end_merge()
	shake = 0.4
	var left := 0
	for m in movables:
		if not m.locked:
			left += 1
	if left == 1:
		_hint("Satu batu lagi", 2.5)

# ---------------------------------------------------------------- gerbang gema (K1-K8)

func _on_gate(g: Node) -> void:
	if echo_running or cutscene or finishing:
		return
	var ok: bool = await _run_echo(g.gate_id)
	if ok and is_instance_valid(g):
		g.dissolve()
		shake = 0.3
		var am = get_node_or_null("/root/AudioManager")
		if am:
			am.play_sfx("tick", 1.2, 2.0)

## Kartu adegan + 2 ronde. Hanya Jujur yang maju; selain itu ronde diulang (pilihan diacak lagi)
## dan energi berkurang. Hasil false kalau energi habis di tengah percakapan.
func _run_echo(id: String) -> bool:
	var dm = _dm()
	var gs = _gs()
	if dm == null:
		return true
	var data = dm.flow("echo/" + id)
	if not (data is Dictionary):
		return true
	echo_running = true
	_end_merge()
	var k = _find_player()
	if k:
		k.set_movement_enabled(false)
	var old_inv := invuln
	invuln = 999.0
	# Tanpa kartu "K1: ..." (ruangan di naskah tidak ada di dunia pulau melayang):
	# Bayangan berbisik satu kalimat penghubung, lalu suara Adik langsung terdengar.
	var hush := _make_overlay()
	create_tween().tween_property(hush["dim"], "color:a", 0.32, 0.6)
	var am0 = get_node_or_null("/root/AudioManager")
	if am0:
		am0.play_sfx("heartbeat", 0.9, -8.0)
	var bridge = dm.flow("echo_bridge/" + id)
	if bridge is Dictionary and shadow:
		shadow.active = false
		var kp: Vector2 = k.global_position if k else Vector2.ZERO
		shadow.global_position = kp + Vector2(22.0 if k and not k.get_node("AnimatedSprite2D").flip_h else -22.0, 0)
		var b = _bubble(shadow, "echo_bridge/" + id, "speech", 1.6)
		if b:
			await b.finished
		shadow.fade_to(0.0, 0.5)
		shadow.active = true
	var rounds: Array = data.get("rounds", [])
	var r := 0
	var am = get_node_or_null("/root/AudioManager")
	while r < rounds.size():
		var picked: Dictionary = await dm.play_echo_round(rounds[r])
		var kind := String(picked.get("type", ""))
		var delta := int(L.ECHO_ENERGY.get(kind, 0))
		if kind == "jujur":
			r += 1
			if am:
				am.play_sfx("tick", 1.4)
			if delta > 0:
				_heal(delta)
		else:
			shake = 0.5
			flash_rect.color.a = 0.3
			create_tween().tween_property(flash_rect, "color:a", 0.0, 0.6)
			if am:
				am.play_sfx("rewind", 0.8, -6.0)
			if delta < 0 and _damage(-delta):
				dm.close_echo()
				if is_instance_valid(hush["layer"]):
					hush["layer"].queue_free()
				echo_running = false
				return false
	dm.close_echo()
	if is_instance_valid(hush["layer"]):
		var hout := create_tween()
		hout.tween_property(hush["dim"], "color:a", 0.0, 0.5)
		hout.tween_callback(hush["layer"].queue_free)
	if gs and not gs.echo_done.has(id):
		gs.echo_done.append(id)
	echo_running = false
	invuln = maxf(old_inv, 0.6) if old_inv < 900.0 else 0.6
	if k and not finishing and not cutscene:
		k.set_movement_enabled(true)
	return true

## Kartu adegan (judul + deskripsi dari naskah), lanjut dengan Enter / klik.
func _scene_card(title: String, scene: String) -> void:
	var ov := _make_overlay()
	var layer: CanvasLayer = ov["layer"]
	var dim: ColorRect = ov["dim"]
	var box := VBoxContainer.new()
	box.position = Vector2(260, 300)
	box.size = Vector2(1400, 400)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	box.modulate.a = 0.0
	layer.add_child(box)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 56)
	t.add_theme_color_override("font_color", Color(1.0, 0.84, 0.55))
	_apply_bold(t)
	box.add_child(t)
	var d := Label.new()
	d.text = scene
	d.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(1400, 0)
	d.add_theme_font_size_override("font_size", 34)
	d.add_theme_color_override("font_color", Color(0.95, 0.92, 0.88))
	_apply_bold(d)
	box.add_child(d)
	var h := Label.new()
	h.text = "Enter / klik  lanjut"
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_theme_font_size_override("font_size", 24)
	h.add_theme_color_override("font_color", Color(0.9, 0.85, 0.8, 0.6))
	box.add_child(h)
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("heartbeat", 0.9, -6.0)
	var tin := create_tween().set_parallel(true)
	tin.tween_property(dim, "color:a", 0.75, 0.5)
	tin.tween_property(box, "modulate:a", 1.0, 0.6)
	await tin.finished
	var dm = _dm()
	var waited := 0.0
	var limit := 0.3 if (dm and dm.is_bot()) or autotest else 12.0
	while waited < limit:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if waited > 0.4 and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("interact") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
			break
	var tout := create_tween().set_parallel(true)
	tout.tween_property(dim, "color:a", 0.0, 0.4)
	tout.tween_property(box, "modulate:a", 0.0, 0.4)
	await tout.finished
	layer.queue_free()

# ---------------------------------------------------------------- kertas: zoom + tunjukkan pecahan

func _make_overlay() -> Dictionary:
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.01, 0.05, 0.0)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dim)
	return {"layer": layer, "dim": dim}

func _piece_rect(tex: Texture2D, h: float) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = tex
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.size = Vector2(h * float(tex.get_width()) / float(tex.get_height()), h)
	tr.pivot_offset = tr.size * 0.5
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

func _kirana_screen() -> Vector2:
	var k = _find_player()
	if k == null:
		return Vector2(960, 540)
	return get_viewport().get_canvas_transform() * (k.global_position + Vector2(0, -24))

func _on_paper(idx: int) -> void:
	var gs = _gs()
	if gs:
		gs.collect_paper(idx)
	_reach_checkpoint(L.PAPER_CHECKPOINT[idx])
	_refresh_hud()
	_paper_scene(idx)

func _paper_scene(idx: int) -> void:
	cutscene = true
	_end_merge()
	var k = _find_player()
	if k:
		k.set_movement_enabled(false)
		k.modulate = Color.WHITE
	cam_zoom_target = 5.4
	var ov := _make_overlay()
	var dim: ColorRect = ov["dim"]
	var tex := load(PIECE_DIR + "photo_piece_%d.png" % (idx + 1)) as Texture2D
	var piece := _piece_rect(tex, 520.0)
	(ov["layer"] as CanvasLayer).add_child(piece)
	var start := _kirana_screen() - piece.size * 0.5
	var center := Vector2(960, 390) - piece.size * 0.5
	piece.position = start
	piece.scale = Vector2(0.06, 0.06)
	piece.rotation = deg_to_rad(-18)
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("tick", 1.3)
	var t := create_tween().set_parallel(true)
	t.tween_property(dim, "color:a", 0.6, 0.5)
	t.tween_property(piece, "position", center, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.25)
	t.tween_property(piece, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.25)
	t.tween_property(piece, "rotation", deg_to_rad(-3 if idx % 2 == 0 else 3), 0.9).set_delay(0.25)
	await t.finished
	_heal(L.HEAL_PAPER)
	var dm = _dm()
	if dm:
		var lines = dm.flow("parkour/papers")
		if lines is Array and idx < lines.size():
			await dm.play_lines([lines[idx]])
	if k:
		k.set_movement_enabled(false)
	var back := create_tween().set_parallel(true)
	back.tween_property(piece, "position", _kirana_screen() - piece.size * 0.5, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	back.tween_property(piece, "scale", Vector2(0.04, 0.04), 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	back.tween_property(dim, "color:a", 0.0, 0.6)
	await back.finished
	(ov["layer"] as CanvasLayer).queue_free()
	cam_zoom_target = CAM_ZOOM
	if k:
		var glow := create_tween()
		glow.tween_property(k, "modulate", Color(1.4, 1.3, 1.05), 0.15)
		glow.tween_property(k, "modulate", Color.WHITE, 0.5)
		k.set_movement_enabled(true)
	invuln = 0.6
	cutscene = false
	var gs = _gs()
	if gs and gs.has_all_papers():
		_show_portal()
	elif gs:
		_hint("Pecahan %d/4" % gs.papers.size(), 2.5)

## Setelah pecahan ke-4: kamera menengok ke portal yang menyala lebih terang, lalu kembali.
func _show_portal() -> void:
	var k = _find_player()
	if k:
		k.set_movement_enabled(false)
	_cam_look_until = 1.8
	cam_zoom_target = 3.2
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("rewind", 1.3, -6.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(final_portal, "glow_boost", 1.3, 0.8)
	t.tween_property(final_portal, "scale", Vector2(1.25, 1.25), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.chain().tween_property(final_portal, "scale", Vector2(1.1, 1.1), 0.5)
	_hint("Semua pecahan terkumpul  ·  pergi ke portal di puncak", 5.0)
	await get_tree().create_timer(1.8).timeout
	cam_zoom_target = CAM_ZOOM
	if k and not cutscene and not finishing:
		k.set_movement_enabled(true)

# ---------------------------------------------------------------- portal terakhir: pecahan menyatu

func _on_finale_zone() -> void:
	if finishing or cutscene:
		return
	var gs = _gs()
	if gs == null or not gs.has_all_papers():
		if shadow and not _finale_warned:
			_finale_warned = true
			var b = _bubble(shadow, "parkour/portal_incomplete", "cold")
			if b:
				await b.finished
			_finale_warned = false
		return
	_finale()

func _finale() -> void:
	finishing = true
	cutscene = true
	_end_merge()
	var k = _find_player()
	k.set_movement_enabled(false)
	k.face_left(L.FINAL_PORTAL.x < k.global_position.x)
	k.modulate = Color.WHITE
	invuln = 999.0
	var hud = RoomManager.hud_instance
	if hud and hud.has_method("hide_hint"):
		hud.hide_hint()
	cam_zoom_target = 4.3
	# Kirana berhenti dengan jarak lega dari portal.
	await _walk_kirana_to(L.FINALE_KIRANA_X)
	k.face_left(true)
	# Bayangan milik Kirana tidak ikut; yang datang adalah bayangan ADIK (K8).
	if shadow:
		shadow.fade_to(0.0, 0.3)
	var adik_shadow := _make_adik_shadow(Vector2(L.FINALE_SHADOW_X, L.FINAL_PORTAL.y))
	_cam_focus = Vector2((L.FINAL_PORTAL.x + L.FINALE_KIRANA_X) * 0.5, L.FINAL_PORTAL.y + 18.0)
	await get_tree().create_timer(1.0).timeout
	var gs8 = _gs()
	if gs8 == null or not gs8.echo_done.has("K8"):
		var ok: bool = await _run_echo("K8")
		if not ok:
			return
	var dm8 = _dm()
	if dm8:
		var closing = dm8.flow("echo/K8/closing")
		if closing is Dictionary:
			await dm8.play_lines([closing])
	k.set_movement_enabled(false)
	invuln = 999.0
	var am8 = get_node_or_null("/root/AudioManager")
	if am8:
		am8.play_sfx("tick", 1.0, 2.0)
	# Bayangan Adik tersenyum lalu larut menjadi cahaya.
	var st8 := create_tween().set_parallel(true)
	st8.tween_property(adik_shadow, "modulate", Color(1.6, 1.5, 1.2, 0.0), 1.4)
	st8.tween_property(adik_shadow, "scale", adik_shadow.scale * Vector2(0.5, 1.4), 1.4)
	await st8.finished
	adik_shadow.queue_free()
	_cam_focus = Vector2.INF
	var ov := _make_overlay()
	var layer: CanvasLayer = ov["layer"]
	var dim: ColorRect = ov["dim"]
	create_tween().tween_property(dim, "color:a", 0.65, 0.6)
	await get_tree().create_timer(0.6).timeout

	# Susun 4 pecahan dari tubuh Kirana menjadi foto utuh di tengah layar.
	var meta := _photo_meta()
	var photo_h := 600.0
	var s := photo_h / float(meta["size"][1])
	var origin := Vector2(960.0 - float(meta["size"][0]) * s * 0.5, 400.0 - photo_h * 0.5)
	var pieces: Array = []
	var am = get_node_or_null("/root/AudioManager")
	for i in range(4):
		var info: Dictionary = meta["pieces"][i]
		var tex := load(PIECE_DIR + String(info["file"])) as Texture2D
		var pr := _piece_rect(tex, float(info["size"][1]) * s)
		layer.add_child(pr)
		pr.position = _kirana_screen() - pr.size * 0.5
		pr.scale = Vector2(0.05, 0.05)
		pr.rotation = deg_to_rad(-25 + i * 15)
		var dest := origin + Vector2(float(info["pos"][0]), float(info["pos"][1])) * s
		var t := create_tween().set_parallel(true)
		t.tween_property(pr, "position", dest, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(pr, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(pr, "rotation", 0.0, 0.9)
		pieces.append(pr)
		if am:
			am.play_sfx("pickup", 0.85 + i * 0.1)
		await get_tree().create_timer(0.35).timeout
	await get_tree().create_timer(0.9).timeout
	var flash := ColorRect.new()
	flash.color = Color(1, 0.97, 0.88, 0.0)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash)
	if am:
		am.play_sfx("tick", 0.8, 2.0)
	var f := create_tween()
	f.tween_property(flash, "color:a", 0.55, 0.12)
	f.tween_property(flash, "color:a", 0.0, 0.7)
	await f.finished
	var dm = _dm()
	if dm:
		var line = dm.flow("parkour/finale")
		if line is Dictionary:
			await dm.play_lines([line])
	k.set_movement_enabled(false)

	# Foto utuh masuk ke tubuh Kirana.
	if am:
		am.play_sfx("rewind", 1.1, -4.0)
	var target := _kirana_screen()
	var m := create_tween().set_parallel(true)
	for pr in pieces:
		m.tween_property(pr, "position", target - pr.size * 0.5, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		m.tween_property(pr, "scale", Vector2(0.03, 0.03), 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	m.tween_property(dim, "color:a", 0.0, 0.8)
	await m.finished
	for pr in pieces:
		pr.queue_free()
	var g := create_tween()
	g.tween_property(k, "modulate", Color(1.8, 1.7, 1.3), 0.2)
	g.tween_property(k, "modulate", Color(1.15, 1.1, 1.0), 0.6)
	shake = 0.5
	if shadow:
		shadow.active = false
		var st := create_tween().set_parallel(true)
		st.tween_property(shadow, "global_position", k.global_position, 0.6)
		st.tween_property(shadow, "modulate:a", 0.0, 0.6)
	await get_tree().create_timer(0.8).timeout

	# Kirana berjalan masuk portal.
	cam_zoom_target = 4.2
	k.face_left(L.FINAL_PORTAL.x < k.global_position.x)
	k._play_anim("walk")
	var dist: float = absf(L.FINAL_PORTAL.x - k.global_position.x)
	var walk := create_tween()
	walk.tween_property(k, "global_position:x", L.FINAL_PORTAL.x, maxf(dist / 70.0, 0.4))
	await walk.finished
	k._play_anim("idle")
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, 0)
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(white)
	if am:
		am.play_sfx("impact", 1.2)
	var w := create_tween().set_parallel(true)
	w.tween_property(k, "modulate:a", 0.0, 0.8)
	w.tween_property(k, "scale", Vector2(0.4, 1.3), 0.8)
	w.tween_property(final_portal, "scale", Vector2(1.5, 1.5), 1.2)
	w.tween_property(white, "color:a", 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	await w.finished
	RoomManager.go_to_scene("res://scenes/ending.tscn")

func _walk_kirana_to(x: float) -> void:
	var k = _find_player()
	if k == null or absf(k.global_position.x - x) < 2.0:
		return
	k.face_left(x < k.global_position.x)
	k._play_anim("walk")
	var t := create_tween()
	t.tween_property(k, "global_position:x", x, absf(x - k.global_position.x) / 70.0)
	await t.finished
	k._play_anim("idle")

## Sosok bayangan Adik (hitam pekat, lebih kecil dari Kirana) untuk pertemuan terakhir.
func _make_adik_shadow(pos: Vector2) -> AnimatedSprite2D:
	var a := AnimatedSprite2D.new()
	a.sprite_frames = load("res://assets/processed/characters/kirana_fantasi/kirana_fantasy_frames.tres") as SpriteFrames
	a.play("idle")
	a.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var sc := 0.35 * BODY_SCALE * 0.9
	a.scale = Vector2(sc, sc)
	a.global_position = pos + Vector2(0, -(240.0 - 128.0) * sc)
	a.flip_h = false
	a.modulate = Color(0.04, 0.02, 0.06, 0.0)
	a.z_index = 1
	add_child(a)
	var mist := CPUParticles2D.new()
	mist.texture = RoomFX.dot_texture()
	mist.amount = 24
	mist.lifetime = 1.8
	mist.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	mist.emission_rect_extents = Vector2(10, 22)
	mist.gravity = Vector2(0, -10)
	mist.scale_amount_min = 0.08
	mist.scale_amount_max = 0.2
	mist.color = Color(0.25, 0.1, 0.35, 0.7)
	a.add_child(mist)
	create_tween().tween_property(a, "modulate:a", 0.95, 1.0)
	return a

func _photo_meta() -> Dictionary:
	var path := PIECE_DIR + "photo_pieces.json"
	if FileAccess.file_exists(path):
		var d = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
		if d is Dictionary:
			return d
	return {"size": [896, 1200], "pieces": [
		{"file": "photo_piece_1.png", "pos": [0, 0], "size": [448, 600]},
		{"file": "photo_piece_2.png", "pos": [448, 0], "size": [448, 600]},
		{"file": "photo_piece_3.png", "pos": [0, 600], "size": [448, 600]},
		{"file": "photo_piece_4.png", "pos": [448, 600], "size": [448, 600]}]}

# ---------------------------------------------------------------- uji otomatis (CLI --autotest)

func _autotest() -> void:
	# Jalur jarang tersentuh: trauma (tanpa teleport), jatuh, bantuan, kertas+cutscene, batu, finale.
	await get_tree().create_timer(1.0).timeout
	autotest = true
	var k = _find_player()
	var gs = _gs()
	var dm = _dm()
	var before: int = gs.stability
	var pos_before: Vector2 = k.global_position
	# Gerbang gema K1 (jalankan dengan --bot=jujur supaya pilihan otomatis).
	var g1: Node = gates[0] if not gates.is_empty() else null
	if g1:
		k.global_position = Vector2(g1.trigger_rect.get_center().x, g1.position.y)
		await get_tree().create_timer(0.5).timeout
		while echo_running:
			await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		print("[AUTOTEST] gate K1 solved ", g1.solved, " energy ", gs.stability, " done ", gs.echo_done)
	k.global_position = L.CHECKPOINTS[0]
	await get_tree().create_timer(0.3).timeout
	before = gs.stability
	pos_before = k.global_position
	_on_trauma(traumas[0])
	await get_tree().create_timer(0.6).timeout
	print("[AUTOTEST] trauma energy ", before, " -> ", gs.stability, " stayed near ", k.global_position.distance_to(pos_before) < 120.0)
	invuln = 0.0
	k.global_position = Vector2(500, 1200)
	await get_tree().create_timer(0.8).timeout
	print("[AUTOTEST] void fall energy ", gs.stability, " back at safe ", k.global_position.distance_to(safe_pos) < 2.0)
	invuln = 0.0
	_fail()
	_fail()
	print("[AUTOTEST] assist tier0 ", assisted[0])
	for i in range(L.PAPERS.size()):
		k.global_position = L.PAPERS[i] + Vector2(0, 10)
		await get_tree().create_timer(1.6).timeout
		while dm.is_dialog_active():
			dm.dialog_box._finish_typing()
			dm.dialog_box.line_finished.emit()
			await get_tree().create_timer(0.1).timeout
		while cutscene:
			await get_tree().process_frame
	print("[AUTOTEST] papers ", gs.papers, " all ", gs.has_all_papers(), " energy ", gs.stability, " cp ", checkpoint_idx)
	# Jatuh ke tingkat bawah setelah checkpoint tingkat 3: harus ditarik ke checkpoint, bukan ke bawah.
	safe_pos = L.CHECKPOINTS[checkpoint_idx]
	invuln = 0.0
	k.global_position = Vector2(300, 1030)
	await get_tree().create_timer(0.9).timeout
	print("[AUTOTEST] deep fall back near checkpoint ", k.global_position.distance_to(L.CHECKPOINTS[checkpoint_idx]) < 60.0, " pos ", k.global_position)
	invuln = 0.0

	for m in movables:
		k.global_position = m.target + Vector2(-60, -2)
		_start_merge(m)
		var guard := 0
		while not m.locked and guard < 400:
			m.drive((m.target - m.position).normalized(), 1.0 / 60.0)
			await get_tree().physics_frame
			guard += 1
		print("[AUTOTEST] block locked ", m.locked)
		_end_merge()
	k.global_position = Vector2(L.FINALE_ZONE.get_center().x, L.FINAL_PORTAL.y)
	await get_tree().create_timer(4.5).timeout
	while dm.is_dialog_active():
		dm.dialog_box._finish_typing()
		dm.dialog_box.line_finished.emit()
		await get_tree().create_timer(0.1).timeout
	print("[AUTOTEST] finale running ", finishing)

func _autotest_collapse() -> void:
	await get_tree().create_timer(1.0).timeout
	_gs().set_energy(10)
	_on_trauma(traumas[0])
	print("[AUTOTEST] collapse started ", finishing)
