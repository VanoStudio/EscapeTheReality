class_name F1Entrance
extends BaseRoom

# Rumah di dunia lain (FLOW KIRANA hal. 2).
# Kirana muncul dari portal di sisi KANAN -> "AAHHH! Ini dimana sih?!!?" -> portal menutup
# -> beberapa detik kemudian Bayangan muncul di kiri, depan pintu bercahaya -> percakapan
# -> Bayangan menghilang -> Kirana masuk pintu bercahaya (F2).

const PortalScript := preload("res://scripts/props/portal_gate.gd")
const FollowerScript := preload("res://scripts/actors/bayangan_follower.gd")

const FLOOR_Y := 171.0
const PORTAL_POS := Vector2(446, 171)
const SHADOW_POS := Vector2(96, 171)
const DOOR_POS := Vector2(46, 171)

var portal: PortalScript
var shadow: FollowerScript
var door_area: Area2D
var door_light: PointLight2D
var door_open := false

func _ready() -> void:
	super._ready()
	_build_bounds()
	_build_door()
	portal = PortalScript.new()
	portal.height = 92.0
	portal.position = PORTAL_POS
	portal.z_index = -1
	add_child(portal)
	var k = _find_player()
	if k and k.has_method("set_body_scale"):
		k.set_body_scale(1.2)
	_arrive()

func _build_bounds() -> void:
	var ground := StaticBody2D.new()
	add_child(ground)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(600, 40)
	cs.shape = r
	cs.position = Vector2(240, FLOOR_Y + 20)
	ground.add_child(cs)
	for x in [6.0, 470.0]:
		var wall := CollisionShape2D.new()
		var wr := RectangleShape2D.new()
		wr.size = Vector2(12, 300)
		wall.shape = wr
		wall.position = Vector2(x, 100)
		ground.add_child(wall)

func _build_door() -> void:
	door_light = PointLight2D.new()
	door_light.texture = RoomFX.light_texture()
	door_light.color = Color(0.85, 0.9, 1.0)
	door_light.energy = 0.35
	door_light.texture_scale = 0.9
	door_light.position = DOOR_POS + Vector2(0, -60)
	add_child(door_light)
	door_area = Area2D.new()
	door_area.collision_layer = 0
	door_area.collision_mask = 2
	door_area.position = DOOR_POS + Vector2(8, -35)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(46, 70)
	cs.shape = r
	door_area.add_child(cs)
	door_area.body_entered.connect(_on_door_entered)
	add_child(door_area)

func _dm() -> Node:
	return get_node_or_null("/root/DialogManager")

func _hint(text: String, dur: float = 4.0) -> void:
	var hud = RoomManager.hud_instance
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text, dur)

func _arrive() -> void:
	var k = _find_player()
	if k:
		k.set_movement_enabled(false)
		k.modulate.a = 0.0
		if k.has_method("face_left"):
			k.face_left(true)
	await get_tree().create_timer(0.35).timeout
	await portal.open(0.6)
	if k:
		var t := create_tween().set_parallel(true)
		k.global_position = PORTAL_POS + Vector2(-6, -24)
		t.tween_property(k, "modulate:a", 1.0, 0.25)
		t.tween_property(k, "global_position", Vector2(PORTAL_POS.x - 34, FLOOR_Y), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		await t.finished
	var dm = _dm()
	var b: Node = null
	if dm:
		b = dm.bubble(k, dm.flow("arrival/shout"), "shout", 1.6, Vector2(0, -100))
	await get_tree().create_timer(1.4).timeout
	portal.close(0.6)
	if b:
		await b.finished
	await get_tree().create_timer(1.2).timeout
	await _shadow_appear()
	if k and k.has_method("face_left"):
		k.face_left(true)
	if dm:
		await dm.play_lines(dm.flow("arrival/lines"), "arrival")
	await _shadow_vanish()
	door_open = true
	create_tween().tween_property(door_light, "energy", 1.4, 0.8)
	if k:
		k.set_movement_enabled(true)
	_hint("Masuk ke pintu bercahaya", 5.0)

func _shadow_appear() -> void:
	var k = _find_player()
	shadow = FollowerScript.new()
	add_child(shadow)
	shadow.setup(k)
	shadow.active = false
	shadow.global_position = SHADOW_POS
	var spr: AnimatedSprite2D = shadow.sprite
	if spr:
		spr.flip_h = false
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("rewind", 0.7, -8.0)
	shadow.scale = Vector2(0.6, 1.3)
	await create_tween().tween_property(shadow, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).finished

func _shadow_vanish() -> void:
	if shadow == null:
		return
	var burst := CPUParticles2D.new()
	burst.texture = RoomFX.dot_texture()
	burst.one_shot = true
	burst.explosiveness = 0.95
	burst.amount = 60
	burst.lifetime = 1.2
	burst.global_position = shadow.global_position + Vector2(0, -40)
	burst.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	burst.emission_rect_extents = Vector2(10, 30)
	burst.direction = Vector2(0, -1)
	burst.spread = 180.0
	burst.gravity = Vector2(0, -20)
	burst.initial_velocity_min = 20.0
	burst.initial_velocity_max = 70.0
	burst.scale_amount_min = 0.1
	burst.scale_amount_max = 0.3
	burst.color = Color(0.4, 0.25, 0.7, 0.9)
	add_child(burst)
	burst.emitting = true
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("rewind", 1.6, -6.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(shadow, "scale", Vector2(0.2, 1.8), 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	t.tween_property(shadow, "modulate:a", 0.0, 0.35)
	await t.finished
	shadow.queue_free()
	shadow = null

func _on_door_entered(body: Node2D) -> void:
	if door_open and body.is_in_group("player"):
		door_open = false
		RoomManager.change_room("F2", true)
