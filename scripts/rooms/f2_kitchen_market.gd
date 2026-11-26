class_name F2KitchenMarket
extends BaseRoom

# Pasar terapung Mbok Luna (FLOW KIRANA hal. 3-6).
# Kirana keluar dari portal kiri -> bicara dengan Mbok Luna (pilihan makan / tidak)
# -> Bayangan muncul lagi, memberi misi 4 kertas, lalu membuka portal di kanan -> P1 (parkour).

const PortalScript := preload("res://scripts/props/portal_gate.gd")
const FollowerScript := preload("res://scripts/actors/bayangan_follower.gd")

const FLOOR_Y := 113.0
const LEFT_ISLAND_END := 106.0
const RIGHT_ISLAND_START := 113.0
const MBOK_POS := Vector2(198, 113)
const ARRIVE_PORTAL := Vector2(18, 113)
const EXIT_PORTAL := Vector2(448, 113)
const BODY_SCALE := 0.88
const BUBBLE_OFFSET := Vector2(0, -70)

var arrive_portal: PortalScript
var exit_portal: PortalScript
var shadow: FollowerScript
var mbok: Node2D
var talked := false

func _ready() -> void:
	super._ready()
	_build_islands()
	_build_mbok()
	arrive_portal = PortalScript.new()
	arrive_portal.height = 70.0
	arrive_portal.position = ARRIVE_PORTAL
	add_child(arrive_portal)
	exit_portal = PortalScript.new()
	exit_portal.height = 70.0
	exit_portal.enterable = true
	exit_portal.position = EXIT_PORTAL
	add_child(exit_portal)
	exit_portal.entered.connect(_on_exit_portal)
	var k = _find_player()
	if k and k.has_method("set_body_scale"):
		k.set_body_scale(BODY_SCALE)
	var gs = get_node_or_null("/root/GameState")
	if gs and gs.has_heavy_legs() and k:
		k.set_heavy_legs(true)
	if gs and gs.wake_pending:
		# Energi habis di parkour: bangun di depan warung Mbok Luna.
		gs.wake_pending = false
		talked = true
		_wake.call_deferred()
		return
	_add_trigger(Vector2(MBOK_POS.x - 40, FLOOR_Y - 30), Vector2(24, 60), _talk)
	if "--autotest" in OS.get_cmdline_user_args() or "--autotest" in OS.get_cmdline_args():
		_autotest_choice.call_deferred()
		return
	_arrive()

# Jarak antar pulau 7 px: cukup diloncati, jatuh = kembali ke titik muncul.
func _build_islands() -> void:
	var body := StaticBody2D.new()
	add_child(body)
	for seg in [[-20.0, LEFT_ISLAND_END], [RIGHT_ISLAND_START, 500.0]]:
		var cs := CollisionShape2D.new()
		var r := RectangleShape2D.new()
		r.size = Vector2(seg[1] - seg[0], 20)
		cs.shape = r
		cs.position = Vector2((seg[0] + seg[1]) * 0.5, FLOOR_Y + 10)
		body.add_child(cs)
	for x in [4.0, 474.0]:
		var wall := CollisionShape2D.new()
		var wr := RectangleShape2D.new()
		wr.size = Vector2(10, 200)
		wall.shape = wr
		wall.position = Vector2(x, 20)
		body.add_child(wall)

func _build_mbok() -> void:
	mbok = Node2D.new()
	mbok.name = "MbokLuna"
	mbok.position = MBOK_POS
	add_child(mbok)
	var spr := Sprite2D.new()
	spr.texture = load("res://assets/processed/characters/penjual_clean.png") as Texture2D
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if spr.texture:
		# Badan di tekstur: y 30..240 dari 256. Tinggi Mbok ~58 px dunia.
		var k := 58.0 / 210.0
		spr.scale = Vector2(k, k)
		spr.position = Vector2(0, -(240.0 - 128.0) * k)
	spr.flip_h = true
	spr.light_mask = 1 | 2
	mbok.add_child(spr)

func _add_trigger(pos: Vector2, size: Vector2, cb: Callable) -> Area2D:
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
			a.set_deferred("monitoring", false)
			cb.call())
	return a

func _dm() -> Node:
	return get_node_or_null("/root/DialogManager")

func _hint(text: String, dur: float = 4.0) -> void:
	var hud = RoomManager.hud_instance
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text, dur)

func on_player_fell(player: Node2D) -> void:
	player.velocity = Vector2.ZERO
	player.global_position = Vector2(40, FLOOR_Y)

func _arrive() -> void:
	var k = _find_player()
	if k:
		k.set_movement_enabled(false)
		k.modulate.a = 0.0
		k.face_left(false)
	await get_tree().create_timer(0.3).timeout
	await arrive_portal.open(0.5)
	if k:
		k.global_position = ARRIVE_PORTAL + Vector2(6, -10)
		var t := create_tween().set_parallel(true)
		t.tween_property(k, "modulate:a", 1.0, 0.25)
		t.tween_property(k, "global_position", Vector2(ARRIVE_PORTAL.x + 28, FLOOR_Y), 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await t.finished
		k.set_movement_enabled(true)
	arrive_portal.close(0.5)
	_hint("A / D  jalan      Spasi / W  lompat", 5.0)

func _talk() -> void:
	if talked:
		return
	talked = true
	var k = _find_player()
	if k:
		k.face_left(false)
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
	shadow = FollowerScript.new()
	add_child(shadow)
	shadow.setup(k)
	shadow.active = false
	shadow.global_position = k.global_position + Vector2(-34, 0)
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("rewind", 0.7, -8.0)
	shadow.scale = Vector2(0.6, 1.3)
	await create_tween().tween_property(shadow, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).finished
	k.face_left(true)
	await dm.play_lines(dm.flow("mission/lines"), "mission")
	k.set_movement_enabled(false)
	# Bayangan membuka portal di ujung kanan.
	await exit_portal.open(0.8)
	shadow.active = true
	k.set_movement_enabled(true)
	k.face_left(false)
	_hint("Masuk ke portal", 5.0)

func _wake() -> void:
	var k = _find_player()
	var dm = _dm()
	var gs = get_node_or_null("/root/GameState")
	if k == null or dm == null:
		return
	k.set_movement_enabled(false)
	k.global_position = Vector2(MBOK_POS.x - 46, FLOOR_Y)
	k.face_left(false)
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
	shadow = FollowerScript.new()
	add_child(shadow)
	shadow.setup(k)
	shadow.active = false
	shadow.global_position = k.global_position + Vector2(-34, 0)
	var b = dm.bubble(shadow, dm.flow("mbok_wake/shadow"), "speech", -1.0, Vector2(0, -60))
	await exit_portal.open(0.8)
	if b:
		await b.finished
	shadow.active = true
	k.set_movement_enabled(true)
	_hint("Masuk ke portal untuk kembali", 5.0)
	print("[WAKE] energy ", gs.stability if gs else -1, " heavy ", gs.has_heavy_legs() if gs else false, " portal open ", exit_portal.is_open)

func _on_exit_portal() -> void:
	exit_portal.enterable = false
	RoomManager.change_room("P1", true)

# ---------------------------------------------------------------- uji otomatis (CLI --autotest)

func _autotest_choice() -> void:
	# Menampilkan kotak dialog + pilihan makan supaya tata letak bisa dicek lewat screenshot.
	var dm = _dm()
	await get_tree().create_timer(0.5).timeout
	var intro: Array = dm.flow("mbok_luna/intro")
	dm.dialog_box.show_line("penjual", intro[6]["text"], "biasa")
	dm.dialog_box._finish_typing()
	dm.dialog_box.prompt_simple_choices(dm.flow("mbok_luna/choices"))
