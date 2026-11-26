class_name TraumaZone
extends Area2D

# Zona trauma: kabut bayangan gelap berduri. Menyentuhnya memanggil kilasan trauma
# (lihat ParkourTower._on_trauma). Bisa diam atau bergerak bolak-balik (patrol).

signal hit(zone: TraumaZone)

@export var size := Vector2(28, 22)
@export var patrol := Vector2.ZERO        # offset ujung patroli dari posisi awal
@export var patrol_speed: float = 0.5     # putaran per detik (0 = diam)

var _origin := Vector2.ZERO
var _t := 0.0
var _seed := 0.0
var art: Node2D
var cooldown := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	_origin = position
	_seed = randf() * 10.0
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size * Vector2(0.7, 0.7)
	cs.shape = rect
	cs.position = Vector2(0, -size.y * 0.5)
	add_child(cs)
	body_entered.connect(_on_body_entered)

	art = Node2D.new()
	art.z_index = 2
	add_child(art)
	art.draw.connect(_draw_mist)

	var embers := CPUParticles2D.new()
	embers.texture = RoomFX.dot_texture()
	embers.amount = 14
	embers.lifetime = 1.3
	embers.position = Vector2(0, -size.y * 0.5)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = size * 0.45
	embers.gravity = Vector2(0, -14)
	embers.scale_amount_min = 0.04
	embers.scale_amount_max = 0.1
	embers.color = Color(0.9, 0.2, 0.35, 0.8)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	embers.material = mat
	add_child(embers)

	var glow := PointLight2D.new()
	glow.texture = RoomFX.light_texture()
	glow.color = Color(0.7, 0.1, 0.3)
	glow.energy = 0.6
	glow.texture_scale = maxf(size.x, size.y) / 60.0
	glow.position = Vector2(0, -size.y * 0.5)
	add_child(glow)

func _process(delta: float) -> void:
	_t += delta
	if cooldown > 0.0:
		cooldown -= delta
	if patrol != Vector2.ZERO and patrol_speed > 0.0:
		var k := (1.0 - cos(_t * patrol_speed * TAU)) * 0.5
		position = _origin + patrol * k
	art.queue_redraw()

func _draw_mist() -> void:
	# Gumpalan kabut berlapis yang berdenyut + duri tipis di bawah.
	var c := Vector2(0, -size.y * 0.5)
	# Aura merah berdenyut supaya bahaya terbaca jelas di langit gelap.
	var pulse := 0.5 + 0.5 * sin(_t * 3.0 + _seed)
	art.draw_circle(c, maxf(size.x, size.y) * (0.7 + 0.08 * pulse), Color(0.85, 0.08, 0.3, 0.16 + 0.1 * pulse))
	art.draw_circle(c, maxf(size.x, size.y) * 0.5, Color(0.95, 0.15, 0.35, 0.14))
	for i in range(7):
		var a := _seed + i * 1.7
		var off := Vector2(sin(_t * 1.3 + a) * size.x * 0.28, cos(_t * 1.1 + a * 1.3) * size.y * 0.22)
		var r := minf(size.x, size.y) * (0.32 + 0.08 * sin(_t * 2.0 + a))
		art.draw_circle(c + off, r, Color(0.07, 0.02, 0.1, 0.55))
	art.draw_circle(c, minf(size.x, size.y) * 0.3, Color(0.02, 0.0, 0.04, 0.85))
	var n := int(size.x / 5.0)
	for i in range(n):
		var x := -size.x * 0.5 + (i + 0.5) * size.x / n
		var hgt := size.y * (0.35 + 0.15 * sin(_t * 3.0 + i * 1.9 + _seed))
		art.draw_colored_polygon(PackedVector2Array([Vector2(x - 2.2, 0), Vector2(x + 2.2, 0), Vector2(x, -hgt)]), Color(0.45, 0.05, 0.18, 0.95))
	# Mata merah samar.
	var blink := 0.5 + 0.5 * sin(_t * 1.7 + _seed)
	art.draw_circle(c + Vector2(-3, -1), 1.0, Color(1.0, 0.2, 0.3, 0.6 * blink))
	art.draw_circle(c + Vector2(3, -1), 1.0, Color(1.0, 0.2, 0.3, 0.6 * blink))

func _on_body_entered(body: Node2D) -> void:
	if cooldown > 0.0 or not body.is_in_group("player"):
		return
	cooldown = 1.0
	hit.emit(self)
