class_name BaseRoom
extends Node2D

@export var room_id: String = "R1"
@export var next_room_id: String = ""
@export var prev_room_id: String = ""

@export var background_sprite: Sprite2D
@export var camera: Camera2D

func _ready() -> void:
	RoomManager.register_room(self, room_id)
	_setup_camera()
	_setup_background()
	_setup_particles()
	_connect_doors()

func _setup_particles() -> void:
	if room_id.begins_with("F"):
		var particles = CPUParticles2D.new()
		particles.name = "FantasySparks"
		particles.amount = 25
		particles.lifetime = 4.0
		particles.preprocess = 2.0
		particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		particles.emission_rect_extents = Vector2(240, 135)
		particles.position = Vector2(240, 135)
		particles.direction = Vector2(0, -1)
		particles.gravity = Vector2(0, -4)
		particles.initial_velocity_min = 4.0
		particles.initial_velocity_max = 12.0
		particles.scale_amount_min = 1.0
		particles.scale_amount_max = 2.5
		particles.color = Color(0.65, 0.85, 1.0, 0.45)
		add_child(particles)

func _setup_camera() -> void:
	if camera == null:
		if has_node("Camera2D"):
			camera = $Camera2D
		else:
			camera = Camera2D.new()
			camera.name = "Camera2D"
			add_child(camera)
	camera.position = Vector2(240, 135)
	camera.zoom = Vector2(4, 4)
	camera.make_current()

func _setup_background() -> void:
	if background_sprite == null and has_node("Background"):
		background_sprite = $Background
	if background_sprite and AssetRegistry:
		var tex = AssetRegistry.get_room_bg(room_id)
		if tex:
			background_sprite.texture = tex
			# Background asli berukuran 2752x1536
			# Kita scale agar pas mencakup 480x270 (2752 * (270/1536) = 483.75)
			var scale_y = 270.0 / float(tex.get_height())
			background_sprite.scale = Vector2(scale_y, scale_y)
			background_sprite.position = Vector2(240, 135)
			background_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _connect_doors() -> void:
	var exit_r = get_node_or_null("ExitRight") as Area2D
	if exit_r and not exit_r.body_entered.is_connected(_on_exit_right_body_entered):
		exit_r.body_entered.connect(_on_exit_right_body_entered)
		
	var exit_l = get_node_or_null("ExitLeft") as Area2D
	if exit_l and not exit_l.body_entered.is_connected(_on_exit_left_body_entered):
		exit_l.body_entered.connect(_on_exit_left_body_entered)

func _on_exit_right_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and next_room_id != "":
		RoomManager.change_room(next_room_id, true)

func _on_exit_left_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and prev_room_id != "":
		RoomManager.change_room(prev_room_id, false)
