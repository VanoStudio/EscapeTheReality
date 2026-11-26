class_name FoodPickup
extends Area2D

# Bekal dari Mbok Luna (nasi kepal) yang melayang di jalur sulit: memulihkan energi.

signal collected(pickup: FoodPickup)

var _t := 0.0
var _taken := false
var art: Node2D
var light: PointLight2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = 9.0
	cs.shape = c
	add_child(cs)
	body_entered.connect(_on_body_entered)
	light = PointLight2D.new()
	light.texture = RoomFX.light_texture()
	light.color = Color(1.0, 0.8, 0.5)
	light.energy = 0.7
	light.texture_scale = 0.25
	add_child(light)
	art = Node2D.new()
	art.z_index = 3
	add_child(art)
	art.draw.connect(_draw_food)

func _draw_food() -> void:
	# Nasi kepal segitiga + rumput laut.
	var tri := PackedVector2Array([Vector2(0, -6), Vector2(6, 4.5), Vector2(-6, 4.5)])
	art.draw_colored_polygon(tri, Color(0.98, 0.97, 0.93))
	var closed := tri.duplicate()
	closed.append(tri[0])
	art.draw_polyline(closed, Color(0.35, 0.3, 0.28), 0.8)
	art.draw_rect(Rect2(-2.5, 0.5, 5, 4), Color(0.12, 0.2, 0.15))

func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	art.position.y = sin(_t * 2.6) * 1.5
	light.energy = 0.6 + sin(_t * 3.0) * 0.15

func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("pickup", 1.3, -2.0)
	collected.emit(self)
	var t := create_tween().set_parallel(true)
	t.tween_property(art, "position", Vector2(0, -14), 0.3)
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	await t.finished
	queue_free()
