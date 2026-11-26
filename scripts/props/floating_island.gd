class_name FloatingIsland
extends AnimatableBody2D

# Pulau melayang untuk parkour (sprite dari assets/processed/flow/platform_*.png).
# Titik asal node = permukaan rumput (tengah). Tabrakan satu arah: bisa dilompati dari bawah.
#
# kind:
#   static   diam
#   crumble  retak, runtuh ~0.6 detik setelah diinjak, muncul lagi beberapa detik kemudian
#   moving   bergerak bolak-balik (patrol) sambil membawa Kirana
#   movable  batu teka-teki: digeser saat Kirana menyatu dengan Bayangan, menempel ke slot tetap

signal placed(island: FloatingIsland)

const SPRITES := {
	"L": "res://assets/processed/flow/platform_1.png",
	"M": "res://assets/processed/flow/platform_2.png",
	"S": "res://assets/processed/flow/platform_3.png",
	"Lc": "res://assets/processed/flow/platform_4.png",
	"Mc": "res://assets/processed/flow/platform_5.png",
	"Sc": "res://assets/processed/flow/platform_6.png",
	"G": "res://assets/processed/flow/platform_wide_1.png",
	"Gc": "res://assets/processed/flow/platform_wide_2.png"
}
const WIDTHS := {"L": 150.0, "M": 80.0, "S": 42.0, "G": 170.0}
const SNAP_DIST := 12.0
const MOVE_SPEED := 95.0

@export var kind: String = "static"
@export var variant: String = "M"
@export var patrol := Vector2.ZERO
@export var patrol_speed: float = 0.25
@export var target := Vector2.ZERO          # movable: posisi slot (koordinat induk)
@export var bounds := Rect2()               # movable: area gerak (koordinat induk)

var width: float = 80.0
var sprite: Sprite2D
var shape: CollisionShape2D
var _origin := Vector2.ZERO
var _t := 0.0
var _crumbling := false
var controlled := false
var locked := false
var slot_art: Node2D
var glow: PointLight2D

func _ready() -> void:
	sync_to_physics = kind == "moving"
	collision_layer = 1
	collision_mask = 0
	_origin = position
	var base := variant
	width = float(WIDTHS.get(base, 80.0))
	var key := base + ("c" if kind == "crumble" else "")
	sprite = Sprite2D.new()
	sprite.texture = load(SPRITES.get(key, SPRITES[base])) as Texture2D
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	if sprite.texture:
		var k := width / float(sprite.texture.get_width())
		sprite.scale = Vector2(k, k)
		sprite.position = Vector2(-width * 0.5, -3.0)
	sprite.light_mask = 1 | 2
	add_child(sprite)

	shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(width * 0.96, 8)
	shape.shape = rect
	shape.position = Vector2(0, 4)
	shape.one_way_collision = true
	shape.one_way_collision_margin = 6.0
	add_child(shape)

	if kind == "crumble":
		var feet := Area2D.new()
		feet.collision_layer = 0
		feet.collision_mask = 2
		var fs := CollisionShape2D.new()
		var fr := RectangleShape2D.new()
		fr.size = Vector2(width * 0.85, 6)
		fs.shape = fr
		fs.position = Vector2(0, -3)
		feet.add_child(fs)
		feet.body_entered.connect(_on_feet)
		add_child(feet)
	elif kind == "movable":
		_build_movable_fx()

func _physics_process(delta: float) -> void:
	_t += delta
	if kind == "moving" and patrol != Vector2.ZERO:
		var k := (1.0 - cos(_t * patrol_speed * TAU)) * 0.5
		position = _origin + patrol * k
	elif kind == "movable" and not locked:
		if not controlled:
			position.y = _origin.y + sin(_t * 1.6) * 2.0
		if glow:
			glow.energy = (1.3 if controlled else 0.7) + sin(_t * 4.0) * 0.15

# ---------------------------------------------------------------- runtuh

func _on_feet(body: Node2D) -> void:
	if _crumbling or not body.is_in_group("player"):
		return
	_crumbling = true
	var t := create_tween()
	# ~0.9 detik bergetar sebelum runtuh (cukup waktu untuk pemula melompat lagi).
	for i in range(10):
		t.tween_property(sprite, "position:x", -width * 0.5 + (1.5 if i % 2 == 0 else -1.5), 0.084)
	t.tween_property(sprite, "position:x", -width * 0.5, 0.06)
	await t.finished
	shape.set_deferred("disabled", true)
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("land", 0.7, -2.0)
	var f := create_tween().set_parallel(true)
	f.tween_property(sprite, "position:y", 60.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	f.tween_property(sprite, "modulate:a", 0.0, 0.7)
	await f.finished
	await get_tree().create_timer(2.6).timeout
	sprite.position = Vector2(-width * 0.5, -3.0)
	shape.set_deferred("disabled", false)
	create_tween().tween_property(sprite, "modulate:a", 1.0, 0.4)
	_crumbling = false

# ---------------------------------------------------------------- teka-teki menyatu

func _build_movable_fx() -> void:
	sprite.modulate = Color(0.75, 1.0, 1.0)
	glow = PointLight2D.new()
	glow.texture = RoomFX.light_texture()
	glow.color = Color(0.4, 1.0, 0.92)
	glow.energy = 0.7
	glow.texture_scale = width / 70.0
	add_child(glow)
	# Slot tujuan: garis putus-putus berbentuk pulau di posisi tetap.
	slot_art = Node2D.new()
	slot_art.top_level = true
	slot_art.z_index = 1
	add_child(slot_art)
	slot_art.draw.connect(_draw_slot)
	slot_art.global_position = get_parent().to_global(target) if get_parent() else target
	# Batu belum di slot: tabrakan aktif supaya bisa dipijak setelah ditempatkan saja.
	shape.disabled = true

func _draw_slot() -> void:
	if locked:
		return
	var w := width * 0.92
	var r := Rect2(-w * 0.5, -3, w, 14)
	var col := Color(0.45, 1.0, 0.92, 0.55 + 0.25 * sin(_t * 3.0))
	var dash := 5.0
	var x := r.position.x
	while x < r.end.x:
		slot_art.draw_line(Vector2(x, r.position.y), Vector2(minf(x + dash, r.end.x), r.position.y), col, 1.5)
		slot_art.draw_line(Vector2(x, r.end.y), Vector2(minf(x + dash, r.end.x), r.end.y), col, 1.5)
		x += dash * 2.0
	slot_art.draw_line(r.position, Vector2(r.position.x, r.end.y), col, 1.5)
	slot_art.draw_line(Vector2(r.end.x, r.position.y), r.end, col, 1.5)

func _process(_delta: float) -> void:
	if slot_art and not locked:
		slot_art.queue_redraw()

func set_controlled(on: bool) -> void:
	if locked:
		return
	controlled = on
	var t := create_tween()
	t.tween_property(sprite, "modulate", Color(0.6, 1.25, 1.2) if on else Color(0.75, 1.0, 1.0), 0.2)
	if not on:
		_origin = position

## Digerakkan saat menyatu. dir = arah input (-1..1). Menempel ke slot bila cukup dekat.
func drive(dir: Vector2, delta: float) -> void:
	if locked or not controlled:
		return
	var p := position + dir * MOVE_SPEED * delta
	if bounds.size != Vector2.ZERO:
		p.x = clampf(p.x, bounds.position.x, bounds.end.x)
		p.y = clampf(p.y, bounds.position.y, bounds.end.y)
	position = p
	if position.distance_to(target) <= SNAP_DIST:
		_lock()

func _lock() -> void:
	locked = true
	controlled = false
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position", target, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "modulate", Color(1, 1, 1), 0.5)
	if glow:
		t.tween_property(glow, "energy", 2.2, 0.15)
		t.chain().tween_property(glow, "energy", 0.35, 0.8)
	shape.set_deferred("disabled", false)
	_origin = target
	if slot_art:
		slot_art.queue_redraw()
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("pickup", 0.8)
	placed.emit(self)

## Langsung terpasang di slot tanpa animasi (mis. kembali ke tingkat yang sudah diselesaikan).
func force_lock() -> void:
	if kind != "movable" or locked:
		return
	locked = true
	controlled = false
	position = target
	_origin = target
	sprite.modulate = Color.WHITE
	if glow:
		glow.energy = 0.35
	shape.set_deferred("disabled", false)
	if slot_art:
		slot_art.queue_redraw()
