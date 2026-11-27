class_name EchoGate
extends Node2D

# Gerbang gema (percakapan K1-K7): tirai kabut ungu (shader) yang menahan jalan sampai Kirana
# menjawab jujur. Di dalam kabut ada sosok sesuai PEMBICARA naskah (dicek dari flow.json):
#   suara_adik     hanya suara -> tidak ada sosok, hanya riak cahaya
#   adik           siluet Adik samar (lilac terang, transparan)
#   adik_cermin    siluet Adik terbalik berkilau seperti pantulan cermin
#   bayangan_adik  sosok bayangan hitam pekat yang menyerupai Adik
# Dijawab jujur: tirai terbelah dari tengah, sosok larut jadi kelopak cahaya yang naik.

signal triggered(gate: EchoGate)

const VeilShader := preload("res://shaders/echo_veil.gdshader")
const KIRANA_FRAMES := "res://assets/processed/characters/kirana_fantasi/kirana_fantasy_frames.tres"

var gate_id := "K1"
var speaker := "adik"
var wall_height := 110.0
var veil_width := 52.0
var trigger_rect := Rect2()          # koordinat dunia
var figure_scale := 0.3              # skala sprite siluet (dunia P1)
var solved := false
var wall: StaticBody2D
var trigger: Area2D
var veil: ColorRect
var veil_mat: ShaderMaterial
var figure: AnimatedSprite2D
var glow: PointLight2D
var motes: CPUParticles2D
var _t := 0.0
var _near := 0.0

func _ready() -> void:
	wall = StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(10, wall_height)
	cs.shape = r
	cs.position = Vector2(0, -wall_height * 0.5)
	wall.add_child(cs)
	add_child(wall)

	trigger = Area2D.new()
	trigger.collision_layer = 0
	trigger.collision_mask = 2
	var ts := CollisionShape2D.new()
	var tr := RectangleShape2D.new()
	tr.size = trigger_rect.size
	ts.shape = tr
	trigger.add_child(ts)
	trigger.top_level = true
	add_child(trigger)
	trigger.global_position = trigger_rect.get_center()
	trigger.body_entered.connect(func(b: Node2D) -> void:
		if not solved and b.is_in_group("player"):
			triggered.emit(self))

	glow = PointLight2D.new()
	glow.texture = RoomFX.light_texture()
	glow.color = Color(0.55, 0.4, 1.0)
	glow.energy = 0.8
	glow.texture_scale = wall_height / 80.0
	glow.position = Vector2(0, -wall_height * 0.5)
	add_child(glow)

	_build_figure()

	veil = ColorRect.new()
	veil.size = Vector2(veil_width, wall_height + 16.0)
	veil.position = Vector2(-veil_width * 0.5, -wall_height - 10.0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil_mat = ShaderMaterial.new()
	veil_mat.shader = VeilShader
	veil_mat.set_shader_parameter("speed", 0.3 + randf() * 0.1)
	veil.material = veil_mat
	veil.z_index = 3
	add_child(veil)

	motes = CPUParticles2D.new()
	motes.texture = RoomFX.dot_texture()
	motes.amount = 18
	motes.lifetime = 2.4
	motes.preprocess = 2.4
	motes.position = Vector2(0, -wall_height * 0.5)
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(veil_width * 0.45, wall_height * 0.45)
	motes.direction = Vector2(0, -1)
	motes.spread = 15.0
	motes.gravity = Vector2(0, -8)
	motes.initial_velocity_min = 3.0
	motes.initial_velocity_max = 9.0
	motes.scale_amount_min = 0.04
	motes.scale_amount_max = 0.1
	motes.color = Color(0.85, 0.75, 1.0, 0.8)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	motes.material = m
	motes.z_index = 4
	add_child(motes)

func _build_figure() -> void:
	if speaker == "suara_adik" or not ResourceLoader.exists(KIRANA_FRAMES):
		return  # hanya suara: tidak ada sosok
	figure = AnimatedSprite2D.new()
	figure.sprite_frames = load(KIRANA_FRAMES) as SpriteFrames
	figure.play("idle")
	figure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Adik lebih kecil dari Kirana.
	var k := figure_scale * 0.9
	figure.scale = Vector2(k, k)
	figure.position = Vector2(0, -(240.0 - 128.0) * k)
	figure.flip_h = true
	figure.z_index = 2
	match speaker:
		"bayangan_adik":
			figure.modulate = Color(0.04, 0.02, 0.06, 0.95)
		"adik_cermin":
			figure.modulate = Color(0.75, 0.95, 1.1, 0.45)
			figure.flip_h = false
		_:
			figure.modulate = Color(0.85, 0.75, 1.05, 0.38)
	add_child(figure)

## 0..1: seberapa dekat Kirana (sosok makin jelas saat didekati).
func set_nearness(v: float) -> void:
	_near = clampf(v, 0.0, 1.0)

func _process(delta: float) -> void:
	_t += delta
	if solved:
		return
	glow.energy = 0.7 + 0.25 * sin(_t * 2.0) + 0.5 * _near
	if figure:
		var base_a := 0.95 if speaker == "bayangan_adik" else (0.45 if speaker == "adik_cermin" else 0.38)
		figure.modulate.a = lerpf(base_a * 0.35, base_a, _near)
		figure.position.y += sin(_t * 1.6) * 0.03
		if speaker == "adik_cermin":
			figure.modulate.b = 1.0 + 0.15 * sin(_t * 5.0)

## Dijawab jujur: tirai terbelah, sosok larut jadi kelopak cahaya.
func dissolve() -> void:
	solved = true
	wall.get_child(0).set_deferred("disabled", true)
	trigger.set_deferred("monitoring", false)
	var petals := CPUParticles2D.new()
	petals.texture = RoomFX.dot_texture()
	petals.one_shot = true
	petals.explosiveness = 0.7
	petals.amount = 70
	petals.lifetime = 2.2
	petals.position = Vector2(0, -wall_height * 0.5)
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(veil_width * 0.4, wall_height * 0.5)
	petals.direction = Vector2(0, -1)
	petals.spread = 60.0
	petals.gravity = Vector2(0, -18)
	petals.initial_velocity_min = 8.0
	petals.initial_velocity_max = 36.0
	petals.angular_velocity_min = -90.0
	petals.angular_velocity_max = 90.0
	petals.scale_amount_min = 0.05
	petals.scale_amount_max = 0.14
	petals.color = Color(1.0, 0.88, 0.6, 0.95)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	petals.material = m
	petals.z_index = 5
	add_child(petals)
	petals.emitting = true
	motes.emitting = false
	var t := create_tween().set_parallel(true)
	t.tween_method(func(v: float) -> void: veil_mat.set_shader_parameter("open", v), 0.0, 1.0, 1.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(glow, "color", Color(1.0, 0.85, 0.55), 0.4)
	t.tween_property(glow, "energy", 1.8, 0.4)
	t.chain().tween_property(glow, "energy", 0.0, 1.4)
	if figure:
		t.tween_property(figure, "modulate", Color(1.6, 1.4, 1.0, 0.0), 1.0)
		t.tween_property(figure, "scale", figure.scale * Vector2(0.6, 1.3), 1.0)
