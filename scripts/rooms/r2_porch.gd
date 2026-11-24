class_name R2Porch
extends BaseRoom

@export var watch_node: Area2D
@export var flash_overlay: ColorRect

var is_sucking: bool = false
var watch_pulse: float = 0.0
var watch_sprite: Sprite2D = null

func _ready() -> void:
	super._ready()
	_setup_flash_overlay()
	_setup_watch_interaction()

func _setup_flash_overlay() -> void:
	if flash_overlay == null:
		var canvas = CanvasLayer.new()
		canvas.layer = 90
		add_child(canvas)
		flash_overlay = ColorRect.new()
		flash_overlay.color = Color(1, 1, 1, 0)
		flash_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		canvas.add_child(flash_overlay)

func _setup_watch_interaction() -> void:
	if watch_node == null and has_node("GroundWatch"):
		watch_node = $GroundWatch as Area2D
	if watch_node:
		watch_sprite = watch_node.get_node_or_null("WatchSprite") as Sprite2D
		if watch_node.has_signal("interacted"):
			watch_node.interacted.connect(_on_watch_picked)

func _process(delta: float) -> void:
	if watch_sprite:
		watch_pulse += delta * 4.0
		var s = 0.028 * (1.0 + sin(watch_pulse) * 0.15)
		watch_sprite.scale = Vector2(s, s)

func _on_watch_picked() -> void:
	if is_sucking:
		return
	is_sucking = true
	
	if RoomManager.current_player and RoomManager.current_player.has_method("set_movement_enabled"):
		RoomManager.current_player.set_movement_enabled(false)
		
	var dm = get_node_or_null("/root/DialogManager")
	if dm:
		await dm.show_memory_line("r2_clock")
			
	await _play_suck_sequence()
	RoomManager.change_room("F1", true)

func _play_suck_sequence() -> void:
	# Cahaya jam membesar, partikel berputar masuk ke jam, Kirana tersedot sambil berputar,
	# lalu layar putih (GDD: "cahaya jam yang menyedot Kirana", dibuat di Godot).
	var am = get_node_or_null("/root/AudioManager")
	var player: Node2D = RoomManager.current_player
	var center: Vector2 = watch_node.global_position if watch_node else Vector2(300, 190)

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
		t.tween_property(player, "global_position", center + Vector2(0, 30), 1.5).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		if spr:
			t.tween_property(spr, "rotation", TAU * 1.5, 1.5).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			t.tween_property(spr, "scale", spr.scale * 0.15, 1.5).set_delay(0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		t.tween_property(player, "modulate", Color(2.0, 2.4, 2.4, 1.0), 1.5).set_delay(0.3)
	var cam: Camera2D = get_node_or_null("Camera2D")
	if cam:
		t.tween_property(cam, "zoom", cam.zoom * 1.12, 1.8).set_trans(Tween.TRANS_SINE)
	t.tween_property(flash_overlay, "color:a", 1.0, 0.5).set_delay(1.4)
	await t.finished
	if am and am.has_method("play_sfx"):
		am.play_sfx("impact")
