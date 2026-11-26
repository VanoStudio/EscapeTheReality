class_name PaperPickup
extends Area2D

# Selembar kertas yang tercecer (tujuan parkour). Digambar oleh kode: kertas krem
# bergaris dengan ujung sobek, melayang dan berkilau. Diambil saat disentuh.

signal collected(index: int)

@export var index: int = 0
## Pecahan foto asli (assets/processed/flow/photo_piece_N.png). Kosong = kertas digambar kode.
var piece_texture: Texture2D = null
var _t := 0.0
var _taken := false
var light: PointLight2D
var art: Node2D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13.0
	cs.shape = circle
	add_child(cs)
	body_entered.connect(_on_body_entered)

	light = PointLight2D.new()
	light.texture = RoomFX.light_texture()
	light.color = Color(1.0, 0.86, 0.55)
	light.energy = 0.9
	light.texture_scale = 0.35
	add_child(light)

	art = Node2D.new()
	art.z_index = 3
	add_child(art)
	art.draw.connect(_draw_paper)

	var sparkle := CPUParticles2D.new()
	sparkle.texture = RoomFX.dot_texture()
	sparkle.amount = 10
	sparkle.lifetime = 1.2
	sparkle.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	sparkle.emission_sphere_radius = 10.0
	sparkle.gravity = Vector2(0, -10)
	sparkle.scale_amount_min = 0.05
	sparkle.scale_amount_max = 0.12
	sparkle.color = Color(1.0, 0.92, 0.7, 0.9)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sparkle.material = mat
	add_child(sparkle)

func _draw_paper() -> void:
	if piece_texture:
		var ph := 20.0
		var pw := ph * float(piece_texture.get_width()) / float(piece_texture.get_height())
		art.draw_rect(Rect2(-pw * 0.5 - 1, -ph * 0.5 - 1, pw + 2, ph + 2), Color(1, 0.95, 0.8, 0.5))
		art.draw_texture_rect(piece_texture, Rect2(-pw * 0.5, -ph * 0.5, pw, ph), false)
		return
	var w := 12.0
	var h := 15.0
	var pts := PackedVector2Array([
		Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5 - 3, -h * 0.5), Vector2(w * 0.5, -h * 0.5 + 3),
		Vector2(w * 0.5, h * 0.5 - 2), Vector2(w * 0.25, h * 0.5), Vector2(0, h * 0.5 - 1.5),
		Vector2(-w * 0.25, h * 0.5), Vector2(-w * 0.5, h * 0.5 - 1.5)
	])
	art.draw_colored_polygon(pts, Color(0.98, 0.94, 0.84))
	var closed := pts.duplicate()
	closed.append(pts[0])
	art.draw_polyline(closed, Color(0.45, 0.32, 0.2), 1.0)
	art.draw_colored_polygon(PackedVector2Array([Vector2(w * 0.5 - 3, -h * 0.5), Vector2(w * 0.5, -h * 0.5 + 3), Vector2(w * 0.5 - 3, -h * 0.5 + 3)]), Color(0.85, 0.78, 0.65))
	for i in range(4):
		var y := -h * 0.5 + 4.0 + i * 2.6
		art.draw_line(Vector2(-w * 0.5 + 2, y), Vector2(w * 0.5 - 2.5, y), Color(0.55, 0.6, 0.8, 0.8), 0.6)

func _process(delta: float) -> void:
	if _taken:
		return
	_t += delta
	art.position.y = sin(_t * 2.2) * 2.0
	art.rotation = sin(_t * 1.3) * 0.12
	light.energy = 0.8 + sin(_t * 3.0) * 0.15

func _on_body_entered(body: Node2D) -> void:
	if _taken or not body.is_in_group("player"):
		return
	_taken = true
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("pickup")
	collected.emit(index)
	var t := create_tween().set_parallel(true)
	t.tween_property(art, "position", Vector2(0, -26), 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(art, "scale", Vector2(1.8, 1.8), 0.5)
	t.tween_property(self, "modulate:a", 0.0, 0.5).set_delay(0.35)
	t.tween_property(light, "energy", 2.5, 0.25)
	await t.finished
	queue_free()
