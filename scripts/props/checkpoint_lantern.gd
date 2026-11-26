class_name CheckpointLantern
extends Area2D

# Lentera checkpoint: menyala saat Kirana lewat, jadi titik kembali bila jatuh/terkena trauma.

signal reached(lantern: CheckpointLantern)

var lit := false
var light: PointLight2D
var art: Node2D
var _t := 0.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var cs := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 50)
	cs.shape = rect
	cs.position = Vector2(0, -25)
	add_child(cs)
	body_entered.connect(_on_body_entered)

	light = PointLight2D.new()
	light.texture = RoomFX.light_texture()
	light.color = Color(0.45, 0.95, 0.9)
	light.energy = 0.0
	light.texture_scale = 0.45
	light.position = Vector2(0, -22)
	add_child(light)

	art = Node2D.new()
	art.z_index = 1
	add_child(art)
	art.draw.connect(_draw_lantern)

func _draw_lantern() -> void:
	art.draw_line(Vector2(0, 0), Vector2(0, -16), Color(0.25, 0.2, 0.25), 1.5)
	var glass := Color(0.5, 1.0, 0.95, 0.9) if lit else Color(0.35, 0.4, 0.45, 0.8)
	art.draw_rect(Rect2(-3.5, -24, 7, 8), glass)
	art.draw_rect(Rect2(-3.5, -24, 7, 8), Color(0.2, 0.15, 0.2), false, 1.0)
	art.draw_rect(Rect2(-4.5, -26, 9, 2), Color(0.25, 0.2, 0.25))

func _process(delta: float) -> void:
	if lit:
		_t += delta
		light.energy = 0.85 + sin(_t * 4.0) * 0.1

func light_up(silent: bool = false) -> void:
	if lit:
		return
	lit = true
	art.queue_redraw()
	create_tween().tween_property(light, "energy", 0.9, 0.4)
	if not silent:
		var am = get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx("tick", 1.4, -4.0)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		var was := lit
		light_up()
		if not was:
			reached.emit(self)
