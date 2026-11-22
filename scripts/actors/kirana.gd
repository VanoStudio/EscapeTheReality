class_name Kirana
extends CharacterBody2D

@export var sprite: Sprite2D
@export var collision_shape: CollisionShape2D

var walk_speed: float = 80.0
var jump_velocity: float = -230.0
var gravity: float = 600.0
var coyote_time_max: float = 0.1
var jump_buffer_max: float = 0.1

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var can_jump: bool = false
var is_movement_enabled: bool = true

# Prosedural squash & stretch
var base_scale: Vector2 = Vector2.ONE
var base_sprite_y: float = -22.0
var anim_phase: float = 0.0
var was_on_floor: bool = true
var footstep_timer: float = 0.2
var walk_frame_timer: float = 0.0
var current_is_fantasy: bool = false
var cached_ar: Node = null
var cached_am: Node = null

func _ready() -> void:
	add_to_group("player")
	_load_tuning()
	base_scale = scale
	cached_ar = get_node_or_null("/root/AssetRegistry")
	cached_am = get_node_or_null("/root/AudioManager")
	if sprite == null and has_node("Sprite2D"):
		sprite = $Sprite2D
	if sprite:
		base_sprite_y = sprite.position.y
	RoomManager.register_player(self)

func _load_tuning() -> void:
	if GameState and GameState.tuning:
		walk_speed = GameState.tuning.walk_speed
		jump_velocity = GameState.tuning.jump_velocity
		gravity = GameState.tuning.gravity
		coyote_time_max = GameState.tuning.coyote_time
		jump_buffer_max = GameState.tuning.jump_buffer

func set_movement_enabled(enabled: bool) -> void:
	is_movement_enabled = enabled
	if not enabled:
		velocity.x = 0
		if sprite:
			sprite.scale = Vector2.ONE
			sprite.position.y = base_sprite_y

func set_can_jump(allowed: bool) -> void:
	can_jump = allowed

func update_character_visual(is_fantasy: bool) -> void:
	current_is_fantasy = is_fantasy
	if sprite == null and has_node("Sprite2D"):
		sprite = $Sprite2D
	var ar = get_node_or_null("/root/AssetRegistry")
	if sprite and ar:
		var tex_key = "kirana_fantasi" if is_fantasy else "kirana_rumah"
		var path = ar.CHARACTERS.get(tex_key, "")
		if path != "":
			var tex = ar.get_texture(path)
			if tex:
				sprite.texture = tex

func _physics_process(delta: float) -> void:
	# Void fall check (di luar layar 270 px)
	if global_position.y > 300.0:
		RoomManager.respawn_player()
		return
		
	if not is_movement_enabled:
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += gravity * delta
		coyote_timer -= delta
	else:
		coyote_timer = coyote_time_max

	# Jump buffer
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_max
	else:
		jump_buffer_timer -= delta

	# Jump execution (hanya jika can_jump = true)
	if can_jump and jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		# Jump stretch
		if sprite:
			sprite.scale = Vector2(0.85, 1.2)
		if cached_am:
			cached_am.play_sfx("jump")

	# Landing squash
	if not was_on_floor and is_on_floor():
		if sprite:
			sprite.scale = Vector2(1.15, 0.85)
		if cached_am:
			cached_am.play_sfx("land")
	was_on_floor = is_on_floor()

	# Horizontal movement
	var dir = Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		velocity.x = dir * walk_speed
		if sprite:
			sprite.flip_h = dir < 0.0
			# Walk bobbing & frame animation
			anim_phase += delta * 12.0
			sprite.position.y = base_sprite_y + sin(anim_phase) * 1.5
			
			walk_frame_timer += delta * 8.0
			var frame_idx = int(walk_frame_timer) % 4
			var frame_key = ("kirana_fantasi_walk_" if current_is_fantasy else "kirana_rumah_walk_") + str(frame_idx)
			if cached_ar and cached_ar.CHARACTERS.has(frame_key):
				var frame_tex = cached_ar.get_texture(cached_ar.CHARACTERS[frame_key])
				if frame_tex:
					sprite.texture = frame_tex
					
		if is_on_floor():
			footstep_timer += delta
			if footstep_timer >= 0.28:
				footstep_timer = 0.0
				if cached_am:
					cached_am.play_sfx("footstep")
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed)
		anim_phase = 0.0
		footstep_timer = 0.2
		walk_frame_timer = 0.0
		if sprite:
			sprite.position.y = base_sprite_y
			# Reset to idle standing frame
			var idle_key = "kirana_fantasi" if current_is_fantasy else "kirana_rumah"
			if cached_ar and cached_ar.CHARACTERS.has(idle_key):
				var idle_tex = cached_ar.get_texture(cached_ar.CHARACTERS[idle_key])
				if idle_tex:
					sprite.texture = idle_tex

	# Recover squash/stretch
	if sprite:
		sprite.scale = sprite.scale.move_toward(Vector2.ONE, delta * 3.0)

	move_and_slide()
