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
var anim_phase: float = 0.0

func _ready() -> void:
	add_to_group("player")
	_load_tuning()
	base_scale = scale
	RoomManager.register_player(self)
	if sprite == null and has_node("Sprite2D"):
		sprite = $Sprite2D

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

func set_can_jump(allowed: bool) -> void:
	can_jump = allowed

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

	# Horizontal movement
	var dir = Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		velocity.x = dir * walk_speed
		if sprite:
			sprite.flip_h = dir < 0.0
			# Walk bobbing
			anim_phase += delta * 12.0
			sprite.position.y = -2.0 + sin(anim_phase) * 1.5
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed)
		anim_phase = 0.0
		if sprite:
			sprite.position.y = 0.0

	# Recover squash/stretch
	if sprite:
		sprite.scale = sprite.scale.move_toward(Vector2.ONE, delta * 3.0)

	move_and_slide()
