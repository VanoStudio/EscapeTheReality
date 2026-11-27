class_name F2KitchenMarket
extends BaseRoom

# Pasar terapung Mbok Luna (FLOW KIRANA hal. 3-6), rombak #3.
# Kirana muncul dari portal KANAN -> berjalan ke kiri, lewat di DEPAN warung -> bicara dengan Mbok Luna
# (pilihan makan / tidak) -> Bayangan muncul di pulau kiri, memberi misi, membuka portal di sana -> P1.
# Bayangan tidak mengikuti terus: hanya muncul saat ada perlu, lalu memudar.

const PortalScript := preload("res://scripts/props/portal_gate.gd")
const FollowerScript := preload("res://scripts/actors/bayangan_follower.gd")

const LANE_Y := 135.0               # jalur jalan di rumput depan warung (warung ada di belakang)
const LEFT_ISLAND_END := 106.0
const RIGHT_ISLAND_START := 113.0
const MBOK_POS := Vector2(196, 124)
const ARRIVE_PORTAL := Vector2(458, LANE_Y)
const SHADOW_POS := Vector2(55, LANE_Y)
const EXIT_PORTAL := Vector2(24, LANE_Y)
const TALK_X := MBOK_POS.x + 42.0
const MEET_KIRANA_X := 266.0        # Kirana melangkah ke sini supaya Bayangan punya ruang
const MEET_SHADOW_X := 228.0        # Bayangan berhenti di sini (antara Mbok dan Kirana)
const BODY_SCALE := 0.8
const BUBBLE_OFFSET := Vector2(0, -70)
const CAM_ZOOM := 4.6
const BG_RECT := Rect2(-11.5, -2.7, 503.0, 275.4)

var owns_camera := true
var arrive_portal: PortalScript
var exit_portal: PortalScript
var shadow: FollowerScript
var mbok: Node2D
var talked := false
var _view_half := Vector2.ZERO

func _ready() -> void:
	super._ready()
	_build_islands()
	_build_mbok()
	arrive_portal = PortalScript.new()
	arrive_portal.height = 70.0
	arrive_portal.face_left = true
	arrive_portal.position = ARRIVE_PORTAL
	add_child(arrive_portal)
	exit_portal = PortalScript.new()
	exit_portal.height = 70.0
	exit_portal.enterable = true
	exit_portal.position = EXIT_PORTAL
	add_child(exit_portal)
	exit_portal.entered.connect(_on_exit_portal)
	var k = _find_player()
	if k:
		k.set_body_scale(BODY_SCALE)
		k.z_index = 2
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_heavy_legs() and k:
		k.set_heavy_legs(true)
	_snap_camera()
	if gs and gs.wake_pending:
		# Energi habis di parkour: bangun di depan warung Mbok Luna.
		gs.wake_pending = false
		talked = true
		_wake.call_deferred()
		return
	if "--autotest" in OS.get_cmdline_user_args() or "--autotest" in OS.get_cmdline_args():
		_autotest_choice.call_deferred()
		return
	_arrive()

# ---------------------------------------------------------------- kamera mengikuti

func _setup_camera() -> void:
	super._setup_camera()
	camera.zoom = Vector2(CAM_ZOOM, CAM_ZOOM)
	_view_half = Vector2(1920.0, 1080.0) / CAM_ZOOM * 0.5

func _cam_target() -> Vector2:
	var k = _find_player()
	var x: float = k.global_position.x if k else 240.0
	# Pulau di sepertiga bawah: pusat kamera sedikit di atas jalur.
	var y := LANE_Y - 22.0
	return Vector2(
		clampf(x, BG_RECT.position.x + _view_half.x, BG_RECT.end.x - _view_half.x),
		clampf(y, BG_RECT.position.y + _view_half.y, BG_RECT.end.y - _view_half.y))

func _snap_camera() -> void:
	if camera:
		camera.position = _cam_target()

func _process(delta: float) -> void:
	if camera:
		camera.position = camera.position.lerp(_cam_target(), 1.0 - exp(-4.0 * delta))
	var k = _find_player()
	if k and not talked and k.global_position.x <= TALK_X:
		talked = true
		_talk()

# ---------------------------------------------------------------- dunia

# Celah antar pulau 7 px (cukup dilewati); jatuh = kembali ke depan warung.
func _build_islands() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	for seg in [[-20.0, LEFT_ISLAND_END], [RIGHT_ISLAND_START, 500.0]]:
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(seg[1] - seg[0], 20)
		cs.shape = r
		cs.position = Vector2((seg[0] + seg[1]) * 0.5, LANE_Y + 10)
		body.add_child(cs)
	for x in [4.0, 476.0]:
		var wall := CollisionShape2D.new()
		var wr := RectangleShape2D.new()
		wr.size = Vector2(10, 200)
		wall.shape = wr
		wall.position = Vector2(x, 40)
		body.add_child(wall)

func _build_mbok() -> void:
	mbok = Node2D.new()
	mbok.name = "MbokLuna"
	mbok.position = MBOK_POS
	mbok.z_index = 1
	add_child(mbok)
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/processed/characters/penjual_clean.png") as Texture2D
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if spr.texture:
		# Badan di tekstur: y 30..240 dari 256. Tinggi Mbok ~58 px dunia.
		var k := 58.0 / 210.0
		spr.scale = Vector2(k, k)
		spr.position = Vector2(0, -(240.0 - 128.0) * k)
	spr.flip_h = true   # menghadap kanan, ke arah Kirana datang
	spr.light_mask = 1 | 2
	mbok.add_child(spr)

func _dm() -> Node:
	return get_node_or_null("/root/DialogManager")

func _hint(text: String, dur: float = 4.0) -> void:
	var hud = RoomManager.hud_instance
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text, dur)

func on_player_fell(player: Node2D) -> void:
	player.velocity = Vector2.ZERO
	player.global_position = Vector2(MBOK_POS.x + 60, LANE_Y)
	player.reset_air()

# ---------------------------------------------------------------- Bayangan: muncul saat perlu saja

func _shadow_appear(pos: Vector2) -> void:
	var k = _find_player()
	if shadow == null:
		shadow = FollowerScript.new()
		add_child(shadow)
		shadow.setup(k)
	shadow.active = false
	shadow.global_position = pos
	shadow.modulate.a = 0.0
	var spr: AnimatedSprite2D = shadow.sprite
	if spr and k:
		spr.flip_h = k.global_position.x < pos.x
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("rewind", 0.7, -8.0)
	shadow.scale = Vector2(0.6, 1.3)
	var t := create_tween().set_parallel(true)
	t.tween_property(shadow, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(shadow, "modulate:a", 0.85, 0.5)
	await t.finished

## Bayangan berjalan (animasi jalan) ke x tertentu di jalur.
func _shadow_walk_to(x: float, speed: float = 62.0) -> void:
	if shadow == null:
		return
	var spr: AnimatedSprite2D = shadow.sprite
	var dir := signf(x - shadow.global_position.x)
	if spr:
		spr.flip_h = dir < 0.0
		if spr.sprite_frames and spr.sprite_frames.has_animation("walk"):
			spr.play("walk")
	var dist := absf(x - shadow.global_position.x)
	var t := create_tween()
	t.tween_property(shadow, "global_position:x", x, maxf(dist / speed, 0.2))
	await t.finished
	if spr and spr.sprite_frames and spr.sprite_frames.has_animation("idle"):
		spr.play("idle")

## Kirana melangkah sendiri sedikit (mis. memberi ruang untuk Bayangan).
func _kirana_step_to(x: float) -> void:
	var k = _find_player()
	if k == null:
		return
	k.face_left(x < k.global_position.x)
	k._play_anim("walk")
	var t := create_tween()
	t.tween_property(k, "global_position:x", x, maxf(absf(x - k.global_position.x) / 70.0, 0.2))
	await t.finished
	k._play_anim("idle")

## Bayangan muncul di pulau kiri, berjalan menghampiri Kirana, (pemanggil menjalankan dialog),
## lalu kembali ke pulau kiri dan membuka portal di sana.
func _shadow_come() -> void:
	var k = _find_player()
	await _kirana_step_to(MEET_KIRANA_X)
	if k:
		k.face_left(true)
	await _shadow_appear(SHADOW_POS)
	await _shadow_walk_to(MEET_SHADOW_X)

func _shadow_return_and_open() -> void:
	await _shadow_walk_to(SHADOW_POS.x)
	var spr: AnimatedSprite2D = shadow.sprite if shadow else null
	if spr:
		spr.flip_h = true
	await exit_portal.open(0.8)
	if spr:
		spr.flip_h = false

func _shadow_vanish() -> void:
	if shadow == null:
		return
	var t := create_tween().set_parallel(true)
	t.tween_property(shadow, "modulate:a", 0.0, 0.7)
	t.tween_property(shadow, "scale", Vector2(0.7, 1.25), 0.7)
	await t.finished

# ---------------------------------------------------------------- alur

func _arrive() -> void:
	var k = _find_player()
	if k:
		k.set_movement_enabled(false)
		k.modulate.a = 0.0
		k.face_left(true)
		k.global_position = ARRIVE_PORTAL + Vector2(-6, -10)
	_snap_camera()
	await get_tree().create_timer(0.3).timeout
	await arrive_portal.open(0.5)
	if k:
		var t := create_tween().set_parallel(true)
		t.tween_property(k, "modulate:a", 1.0, 0.25)
		t.tween_property(k, "global_position", Vector2(ARRIVE_PORTAL.x - 30, LANE_Y), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await t.finished
		k.reset_air()
		k.set_movement_enabled(true)
	arrive_portal.close(0.5)
	_hint("A / D  jalan      Spasi / W  lompat", 5.0)

func _talk() -> void:
	var k = _find_player()
	if k:
		k.face_left(true)
	var dm = _dm()
	if dm == null:
		return
	var kind: String = await dm.play_food_choice()
	var gs = get_node_or_null("/root/GameState")
	if kind == "mau":
		if gs:
			gs.heal(10)
		_food_glow()
	elif k:
		k.set_heavy_legs(true)
	await get_tree().create_timer(0.6).timeout
	await _mission()

func _food_glow() -> void:
	var k = _find_player()
	if k == null:
		return
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("pickup", 1.1)
	var t := create_tween()
	t.tween_property(k, "modulate", Color(1.35, 1.25, 1.0), 0.3)
	t.tween_property(k, "modulate", Color.WHITE, 0.8)

func _mission() -> void:
	var k = _find_player()
	var dm = _dm()
	if k == null or dm == null:
		return
	k.set_movement_enabled(false)
	# Bayangan menghampiri dulu, baru bicara; lalu kembali dan membuka portal di pulau kiri.
	await _shadow_come()
	await dm.play_lines(dm.flow("mission/lines"), "mission")
	k.set_movement_enabled(false)
	await _shadow_return_and_open()
	k.set_movement_enabled(true)
	_hint("Masuk ke portal di pulau kiri", 5.0)

func _wake() -> void:
	var k = _find_player()
	var dm = _dm()
	var gs = get_node_or_null("/root/GameState")
	if k == null or dm == null:
		return
	k.set_movement_enabled(false)
	k.global_position = Vector2(MBOK_POS.x + 40, LANE_Y)
	k.reset_air()
	k.face_left(true)
	_snap_camera()
	k.modulate = Color(0.3, 0.3, 0.4, 0.0)
	await create_tween().tween_property(k, "modulate", Color.WHITE, 1.4).set_trans(Tween.TRANS_SINE).finished
	await dm.play_lines(dm.flow("mbok_wake/lines"))
	if gs and gs.has_heavy_legs():
		# Kesempatan kedua untuk makan: kalau mau, kaki berat hilang.
		var kind: String = await dm.play_offer(dm.flow("mbok_wake/offer"), dm.flow("mbok_luna/choices"))
		if kind == "mau":
			gs.set_food_choice(true)
			k.set_heavy_legs(false)
			_food_glow()
			await dm.play_lines(dm.flow("mbok_wake/reply_mau"))
		else:
			await dm.play_lines(dm.flow("mbok_wake/reply_tidak"))
	else:
		await dm.play_lines(dm.flow("mbok_wake/rested"))
	if gs:
		gs.set_energy(100)
	k.set_movement_enabled(false)
	await _shadow_come()
	var b = dm.bubble(shadow, dm.flow("mbok_wake/shadow"), "speech", -1.0, Vector2(0, -60))
	if b:
		await b.finished
	await _shadow_return_and_open()
	k.set_movement_enabled(true)
	_hint("Masuk ke portal di pulau kiri untuk kembali", 5.0)
	print("[WAKE] energy ", gs.stability if gs else -1, " heavy ", gs.has_heavy_legs() if gs else false, " portal open ", exit_portal.is_open)

func _on_exit_portal() -> void:
	exit_portal.enterable = false
	_shadow_vanish()
	RoomManager.change_room("P1", true)

# ---------------------------------------------------------------- uji otomatis (CLI --autotest)

func _autotest_choice() -> void:
	# Menampilkan kotak dialog + pilihan makan supaya tata letak bisa dicek lewat screenshot.
	var dm = _dm()
	talked = true
	await get_tree().create_timer(0.5).timeout
	var intro: Array = dm.flow("mbok_luna/intro")
	dm.dialog_box.show_line("penjual", intro[6]["text"], "biasa")
	dm.dialog_box._finish_typing()
	dm.dialog_box.prompt_simple_choices(dm.flow("mbok_luna/choices"))
