class_name Kirana
extends CharacterBody2D

@export var anim_sprite: AnimatedSprite2D
@export var sprite: Sprite2D
@export var collision_shape: CollisionShape2D

var walk_speed: float = 135.0
var jump_velocity: float = -250.0
var gravity: float = 650.0
var coyote_time_max: float = 0.12
var jump_buffer_max: float = 0.12

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

var can_jump: bool = false
var is_movement_enabled: bool = true

var current_is_fantasy: bool = false
var cached_ar: Node = null
var cached_am: Node = null
var base_scale: Vector2 = Vector2(0.18, 0.18)
var footstep_timer: float = 0.2
var was_on_floor: bool = true

func _ready() -> void:
	add_to_group("player")
	_load_tuning()
	cached_ar = get_node_or_null("/root/AssetRegistry")
	cached_am = get_node_or_null("/root/AudioManager")
	
	if anim_sprite == null and has_node("AnimatedSprite2D"):
		anim_sprite = $AnimatedSprite2D
	if sprite == null and has_node("Sprite2D"):
		sprite = $Sprite2D
		
	if anim_sprite:
		base_scale = anim_sprite.scale
	elif sprite:
		base_scale = sprite.scale
		
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
		_play_anim("idle")

func set_can_jump(allowed: bool) -> void:
	can_jump = allowed

func update_character_visual(is_fantasy: bool) -> void:
	current_is_fantasy = is_fantasy
	_play_anim("idle")

func _play_anim(anim_type: String) -> void:
	if anim_sprite == null:
		return
	var target_anim = anim_type
	if not current_is_fantasy:
		if anim_type == "walk":
			target_anim = "walk_rumah"
		else:
			target_anim = "idle_rumah"
			
	if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(target_anim):
		if anim_sprite.animation != target_anim or not anim_sprite.is_playing():
			anim_sprite.play(target_anim)

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
		if cached_am:
			cached_am.play_sfx("jump")

	# Landing sound
	if not was_on_floor and is_on_floor():
		if cached_am:
			cached_am.play_sfx("land")
	was_on_floor = is_on_floor()

	# Horizontal movement
	var dir = Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		velocity.x = dir * walk_speed
		if anim_sprite:
			anim_sprite.flip_h = dir < 0.0
		elif sprite:
			sprite.flip_h = dir < 0.0
			
		if is_on_floor():
			_play_anim("walk")
			footstep_timer += delta
			if footstep_timer >= 0.28:
				footstep_timer = 0.0
				if cached_am:
					cached_am.play_sfx("footstep")
		else:
			if velocity.y < 0:
				_play_anim("jump")
			else:
				_play_anim("fall")
	else:
		velocity.x = move_toward(velocity.x, 0.0, walk_speed)
		footstep_timer = 0.2
		if is_on_floor():
			_play_anim("idle")
		else:
			if velocity.y < 0:
				_play_anim("jump")
			else:
				_play_anim("fall")

	move_and_slide()
