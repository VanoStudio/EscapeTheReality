class_name R2Porch
extends BaseRoom

# Depan rumah, dunia nyata (FLOW KIRANA hal. 1).
# Jam bercahaya sudah tergeletak di lantai dekat tiang kanan sejak awal (gambar PDF hal. 1).
# Kirana keluar dari pintu kiri -> "duh laper banget.." -> lewat jendela "haduh keluar cari makan.."
# -> dekat jam: "lho itu jam apa?" -> tekan E -> "AAH!!!!"
# -> tersedot jam -> dunia lain (F1, muncul di sisi kanan).

const FLOOR_Y := 217.0
const WINDOW_X := 205.0
const CLOCK_POS := Vector2(392, 214)
const NOTICE_X := 318.0
const BUBBLE_OFFSET := Vector2(0, -98)

var clock: Area2D = null
var clock_sprite: Sprite2D = null
var clock_light: PointLight2D = null
var flash_overlay: ColorRect
var is_sucking := false
var _pulse := 0.0

func _ready() -> void:
	super._ready()
	_build_bounds()
	_build_flash()
	_spawn_clock()
	var k = _find_player()
	if k:
		if k.has_method("set_body_scale"):
			k.set_body_scale(1.22)
		if k.has_method("face_left"):
			k.face_left(false)
	if "--autotest" in OS.get_cmdline_user_args() or "--autotest" in OS.get_cmdline_args():
		_autotest.call_deferred()
	_intro()

func _build_bounds() -> void:
	var ground := StaticBody2D.new()
	ground.name = "Ground"
	add_child(ground)
	var floor_shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(600, 40)
	floor_shape.shape = r
	floor_shape.position = Vector2(240, FLOOR_Y + 20)
	ground.add_child(floor_shape)
	for x in [8.0, 446.0]:
		var wall := CollisionShape2D.new()
		var wr := RectangleShape2D.new()
		wr.size = Vector2(12, 300)
		wall.shape = wr
		wall.position = Vector2(x, 100)
		ground.add_child(wall)

func _build_flash() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 90
	add_child(canvas)
	flash_overlay = ColorRect.new()
	flash_overlay.color = Color(1, 1, 1, 0)
	flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(flash_overlay)

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

func _hud_hint(text: String, dur: float = 4.0) -> void:
	var hud = RoomManager.hud_instance
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text, dur)

func _say(key: String, style: String = "speech", hold: float = -1.0) -> Node:
	var dm = _dm()
	if dm == null:
		return null
	return dm.bubble(_find_player(), dm.flow("front_house/" + key), style, hold, BUBBLE_OFFSET)

func _intro() -> void:
	await get_tree().create_timer(0.9).timeout
	_say("lapar")
	await get_tree().create_timer(1.2).timeout
	_hud_hint("A / D   jalan", 4.0)

func _on_window() -> void:
	_say("jendela")

# ---------------------------------------------------------------- jam

func _spawn_clock() -> void:
	if clock:
		return
	var InteractScript := load("res://scripts/rooms/interactable_object.gd")
	clock = Area2D.new()
	clock.set_script(InteractScript)
	clock.name = "GroundWatch"
	clock.position = CLOCK_POS
	clock.set("trigger_once", true)
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 30.0
	cs.shape = circle
	clock.add_child(cs)
	clock_sprite = Sprite2D.new()
	clock_sprite.texture = load("res://assets/processed/props/ground_watch.png") as Texture2D
	clock_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	clock_sprite.position = Vector2(0, -8)
	clock_sprite.scale = Vector2.ZERO
	clock.add_child(clock_sprite)
	clock_light = PointLight2D.new()
	clock_light.texture = RoomFX.light_texture()
	clock_light.color = Color(1.0, 0.85, 0.5)
	clock_light.energy = 0.0
	clock_light.texture_scale = 0.5
	clock_light.position = Vector2(0, -8)
	clock.add_child(clock_light)
	add_child(clock)
	clock.connect("interacted", _on_clock_picked)

	clock_sprite.scale = Vector2(0.03, 0.03)
	clock_light.energy = 1.0

var _window_done := false

func _process(delta: float) -> void:
	# Cek posisi (bukan Area2D) supaya pemicu tidak terlewat walau Kirana berpindah cepat.
	var k = _find_player()
	if k and not is_sucking:
		if not _window_done and k.global_position.x >= WINDOW_X:
			_window_done = true
			_on_window()
		if clock and not _noticed and k.global_position.x >= NOTICE_X:
			_on_notice()
	if clock_sprite and clock_sprite.scale.x > 0.02 and not is_sucking:
		_pulse += delta * 4.0
		var s := 0.03 * (1.0 + sin(_pulse) * 0.1)
		clock_sprite.scale = Vector2(s, s)
		clock_light.energy = 1.0 + sin(_pulse) * 0.2

var _noticed := false

func _on_notice() -> void:
	if _noticed:
		return
	_noticed = true
	var k = _find_player()
	if k and k.has_method("face_left"):
		k.face_left(k.global_position.x > CLOCK_POS.x)
	_say("jam", "speech")
	_hud_hint("E   ambil jam", 5.0)

func _on_clock_picked() -> void:
	if is_sucking:
		return
	is_sucking = true
	var k = _find_player()
	if k and k.has_method("set_movement_enabled"):
		k.set_movement_enabled(false)
	var hud = RoomManager.hud_instance
	if hud and hud.has_method("hide_hint"):
		hud.hide_hint()
	_say("aah", "shout", 1.2)
	await get_tree().create_timer(0.5).timeout
	await _play_suck_sequence()
	RoomManager.change_room("F1", false)

func _play_suck_sequence() -> void:
	# Cahaya jam membesar, partikel berputar masuk ke jam, Kirana tersedot sambil berputar, layar putih.
	var am = get_node_or_null("/root/AudioManager")
	var player: Node2D = _find_player()
	var center: Vector2 = clock.global_position + Vector2(0, -8)

	var glow := PointLight2D.new()
	glow.texture = RoomFX.light_texture()
	glow.color = Color(0.45, 1.0, 0.92)
	glow.energy = 0.0
	glow.texture_scale = 0.3
	glow.global_position = center
	add_child(glow)

	var swirl := CPUParticles2D.new()
	swirl.texture = RoomFX.dot_texture()
	swirl.amount = 90
	swirl.lifetime = 1.2
	swirl.global_position = center
	swirl.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	swirl.emission_sphere_radius = 150.0
	swirl.gravity = Vector2.ZERO
	swirl.radial_accel_min = -260.0
	swirl.radial_accel_max = -180.0
	swirl.orbit_velocity_min = 0.25
	swirl.orbit_velocity_max = 0.45
	swirl.scale_amount_min = 0.15
	swirl.scale_amount_max = 0.4
	swirl.color = Color(0.6, 1.0, 0.95, 0.85)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	swirl.material = mat
	swirl.z_index = 20
	add_child(swirl)

	if am and am.has_method("play_sfx"):
		am.play_sfx("rewind")
	var t := create_tween().set_parallel(true)
	t.tween_property(glow, "energy", 3.5, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(glow, "texture_scale", 2.6, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if is_instance_valid(player):
		player.set_physics_process(false)
		var spr: Node2D = player.get_node_or_null("AnimatedSprite2D")
		t.tween_property(player, "global_position", center + Vector2(0, 20), 1.5).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		if spr:
			t.tween_property(spr, "rotation", TAU * 1.5, 1.5).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			t.tween_property(spr, "scale", spr.scale * 0.15, 1.5).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(player, "modulate", Color(2.0, 2.4, 2.4, 1.0), 1.5).set_delay(0.3)
	if camera:
		t.tween_property(camera, "zoom", camera.zoom * 1.12, 1.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(flash_overlay, "color:a", 1.0, 0.5).set_delay(1.4)
	await t.finished
	if am and am.has_method("play_sfx"):
		am.play_sfx("impact")

# ---------------------------------------------------------------- uji otomatis (CLI --autotest)

func _autotest() -> void:
	await get_tree().create_timer(1.0).timeout
	var k = _find_player()
	k.global_position = Vector2(380, FLOOR_Y)
	await get_tree().create_timer(1.0).timeout
	print("[AUTOTEST] clock spawned, noticed ", _noticed)
	clock.trigger_interaction()
	await get_tree().create_timer(5.0).timeout
	print("[AUTOTEST] room now ", RoomManager.current_room_id)
