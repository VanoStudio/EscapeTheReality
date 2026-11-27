class_name PortalGate
extends Node2D

# Portal batu bercahaya (assets/processed/flow/portal.png). Bisa dibuka/ditutup dengan animasi,
# dan memberi sinyal `entered` saat Kirana masuk (kalau `enterable`).

signal entered()

const TEX_PATH := "res://assets/processed/flow/portal.png"

@export var height: float = 64.0
@export var enterable: bool = false
## Gambar portal punya arah (bukaan miring ke kanan). true = dibalik menghadap kiri,
## dipakai untuk portal di sisi kanan layar yang dilewati Kirana ke arah kiri.
@export var face_left: bool = false

var sprite: Sprite2D
var light: PointLight2D
var swirl: CPUParticles2D
var area: Area2D
var is_open := false
var glow_boost := 0.0   # tambahan cahaya (mis. semua pecahan terkumpul)
var _t := 0.0

func _ready() -> void:
	sprite = Sprite2D.new()
	sprite.texture = load(TEX_PATH) as Texture2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.flip_h = face_left
	if sprite.texture:
		var k := height / float(sprite.texture.get_height())
		sprite.scale = Vector2(k, k)
	sprite.offset = Vector2(0, -sprite.texture.get_height() * 0.5) if sprite.texture else Vector2.ZERO
	add_child(sprite)

	light = PointLight2D.new()
	light.texture = RoomFX.light_texture()
	light.color = Color(0.45, 0.8, 1.0)
	light.energy = 0.0
	light.texture_scale = height / 90.0
	light.position = Vector2(0, -height * 0.55)
	add_child(light)

	swirl = CPUParticles2D.new()
	swirl.texture = RoomFX.dot_texture()
	swirl.amount = 26
	swirl.lifetime = 1.4
	swirl.position = Vector2(0, -height * 0.55)
	swirl.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	swirl.emission_sphere_radius = height * 0.35
	swirl.gravity = Vector2.ZERO
	swirl.radial_accel_min = -30.0
	swirl.radial_accel_max = -14.0
	swirl.orbit_velocity_min = 0.2
	swirl.orbit_velocity_max = 0.4
	swirl.scale_amount_min = 0.06
	swirl.scale_amount_max = 0.16
	swirl.color = Color(0.6, 0.9, 1.0, 0.8)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	swirl.material = mat
	swirl.emitting = false
	add_child(swirl)

	area = Area2D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(height * 0.35, height * 0.8)
	cs.shape = rect
	cs.position = Vector2(0, -height * 0.45)
	area.add_child(cs)
	area.body_entered.connect(_on_body_entered)
	add_child(area)

	scale = Vector2(0.0, 1.0)
	visible = false

func _process(delta: float) -> void:
	if not is_open:
		return
	_t += delta
	light.energy = 0.9 + glow_boost + sin(_t * 3.2) * 0.18
	sprite.scale.y = abs(sprite.scale.x) * (1.0 + sin(_t * 2.4) * 0.015)

func open(dur: float = 0.7) -> void:
	visible = true
	is_open = true
	swirl.emitting = true
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("rewind", 1.25, -6.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector2.ONE, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(light, "energy", 1.2, dur)
	await t.finished

func close(dur: float = 0.6) -> void:
	is_open = false
	swirl.emitting = false
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "scale", Vector2(0.0, 1.15), dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	t.tween_property(light, "energy", 0.0, dur)
	await t.finished
	visible = false

func _on_body_entered(body: Node2D) -> void:
	if enterable and is_open and body.is_in_group("player"):
		entered.emit()
