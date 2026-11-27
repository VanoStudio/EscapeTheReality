class_name BayanganFollower
extends Node2D

# Bayangan sebagai pendamping di dunia fantasi (GDD bagian 3: "Sprite ... Kirana yang
# digelapkan lewat shader"). Mengikuti Kirana dengan jeda, melayang pelan, meniru
# animasi Kirana, dan meninggalkan jejak asap tipis.

const FOLLOW_OFFSET := Vector2(-26, -6)
const DELAY_FRAMES := 18
const BOB_AMPLITUDE := 2.5

var target: Node2D = null
var sprite: AnimatedSprite2D
var history: Array[Dictionary] = []
var t := 0.0
var facing_left := false
var active := true

func setup(player: Node2D) -> void:
	target = player
	name = "BayanganFollower"
	z_index = 0
	sprite = AnimatedSprite2D.new()
	var src: AnimatedSprite2D = player.get_node_or_null("AnimatedSprite2D")
	if src:
		sprite.sprite_frames = src.sprite_frames
		sprite.scale = src.scale
		sprite.position = src.position
		sprite.texture_filter = src.texture_filter
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/shadow_character.gdshader") as Shader
	sprite.material = mat
	add_child(sprite)
	sprite.play("idle")
	modulate = Color(1, 1, 1, 0.0)
	global_position = player.global_position + FOLLOW_OFFSET
	_build_wisps()
	if start_visible:
		fade_to(0.82, 1.2)

## Bayangan tidak harus selalu terlihat: false = ikut dari jauh tapi tak tampak.
var start_visible := true
var _fade_tween: Tween

func fade_to(alpha: float, dur: float = 0.5) -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", alpha, dur)

func _build_wisps() -> void:
	var p := CPUParticles2D.new()
	p.texture = RoomFX.dot_texture()
	p.amount = 18
	p.lifetime = 1.6
	p.position = Vector2(0, -30)
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(8, 22)
	p.direction = Vector2(0, -1)
	p.spread = 25.0
	p.gravity = Vector2(0, -6)
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 6.0
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.35
	p.color = Color(0.35, 0.2, 0.6, 0.55)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.8))
	ramp.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	p.local_coords = false
	add_child(p)

func _physics_process(delta: float) -> void:
	if not active or not is_instance_valid(target):
		return
	t += delta
	var src: AnimatedSprite2D = target.get_node_or_null("AnimatedSprite2D")
	history.append({
		"pos": target.global_position,
		"anim": src.animation if src else &"idle",
		"flip": src.flip_h if src else false
	})
	if history.size() > DELAY_FRAMES:
		var h: Dictionary = history.pop_front()
		facing_left = h["flip"]
		var off := FOLLOW_OFFSET
		if facing_left:
			off.x = -off.x
		var dest: Vector2 = h["pos"] + off + Vector2(0, sin(t * 2.2) * BOB_AMPLITUDE)
		global_position = global_position.lerp(dest, 1.0 - exp(-delta * 8.0))
		sprite.flip_h = facing_left
		if sprite.sprite_frames and sprite.sprite_frames.has_animation(h["anim"]) and sprite.animation != h["anim"]:
			sprite.play(h["anim"])

func merge_into_player(duration: float = 0.9) -> void:
	# Dipakai di akhir K3: Bayangan menyatu ke tubuh Kirana.
	active = false
	if not is_instance_valid(target):
		queue_free()
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "global_position", target.global_position, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "modulate", Color(0.6, 1.0, 0.95, 0.0), duration)
	tw.tween_property(self, "scale", Vector2(0.6, 1.2), duration)
	await tw.finished
	queue_free()
