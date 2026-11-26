class_name Kirana
extends CharacterBody2D

## Mendarat setelah di udara. drop = jarak jatuh dari titik tertinggi (px dunia).
signal landed(drop: float)

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

# Feel gerak (fase C)
const ACCEL_GROUND := 1100.0
const ACCEL_AIR := 700.0
const DECEL_GROUND := 1400.0
const JUMP_CUT := 0.5
var squash_tween: Tween = null
var dust: CPUParticles2D = null
var jam_light: PointLight2D = null
var jam_pulse: float = 0.0
var fall_speed_peak: float = 0.0
const TIER_COLORS := [Color(0.35, 1.0, 0.9), Color(1.0, 0.6, 0.2), Color(1.0, 0.18, 0.15)]

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
		
	_build_dust()
	_build_jam_light()
	_build_contact_shadow()
	RoomManager.register_player(self)
	var gs = get_node_or_null("/root/GameState")
	if gs and not gs.tier_changed.is_connected(_on_tier_changed):
		gs.tier_changed.connect(_on_tier_changed)
		_on_tier_changed(gs.get_tier())

func _build_dust() -> void:
	dust = CPUParticles2D.new()
	dust.name = "Dust"
	dust.emitting = false
	dust.one_shot = true
	dust.explosiveness = 0.9
	dust.amount = 10
	dust.lifetime = 0.45
	dust.texture = RoomFX.dot_texture()
	dust.position = Vector2(0, -1)
	dust.direction = Vector2(0, -1)
	dust.spread = 80.0
	dust.gravity = Vector2(0, 30)
	dust.initial_velocity_min = 12.0
	dust.initial_velocity_max = 30.0
	dust.scale_amount_min = 0.12
	dust.scale_amount_max = 0.3
	dust.color = Color(0.92, 0.88, 0.8, 0.6)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0.9))
	ramp.set_color(1, Color(1, 1, 1, 0))
	dust.color_ramp = ramp
	dust.local_coords = false
	add_child(dust)

var contact_shadow: Sprite2D = null
const SHADOW_SIZE := Vector2(38, 9)

func _build_contact_shadow() -> void:
	# Bayangan lonjong di lantai: mengikat karakter ke garis jalan supaya tidak terlihat melayang.
	contact_shadow = Sprite2D.new()
	contact_shadow.name = "ContactShadow"
	contact_shadow.texture = RoomFX.dot_texture()
	contact_shadow.top_level = true
	contact_shadow.z_index = -1
	contact_shadow.modulate = Color(0.02, 0.01, 0.05, 0.55)
	add_child(contact_shadow)
	_update_contact_shadow()

func _update_contact_shadow() -> void:
	if contact_shadow == null or not is_inside_tree():
		return
	var space := get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -2), global_position + Vector2(0, 160), 1)
	q.exclude = [get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		contact_shadow.visible = false
		return
	contact_shadow.visible = true
	var ground_y: float = hit["position"].y
	var height: float = max(ground_y - global_position.y, 0.0)
	var k: float = clamp(1.0 - height / 120.0, 0.35, 1.0)
	contact_shadow.global_position = Vector2(global_position.x, ground_y)
	contact_shadow.scale = SHADOW_SIZE * k / 32.0
	contact_shadow.modulate.a = 0.7 * k

func _puff(amount: int) -> void:
	if dust == null:
		return
	dust.amount = amount
	dust.restart()
	dust.emitting = true

func _build_jam_light() -> void:
	# Cahaya jam kalung di dada Kirana, warnanya ikut tier emosi (GDD bagian 5).
	jam_light = PointLight2D.new()
	jam_light.name = "JamLight"
	jam_light.texture = RoomFX.light_texture()
	jam_light.texture_scale = 0.45
	jam_light.position = Vector2(0, -42)
	jam_light.energy = 0.6
	# Hanya menerangi background (light_mask bit 2), bukan sprite Kirana sendiri.
	jam_light.range_item_cull_mask = 2
	jam_light.blend_mode = Light2D.BLEND_MODE_ADD
	jam_light.visible = false
	add_child(jam_light)

func _on_tier_changed(tier: int) -> void:
	if jam_light:
		var c: Color = TIER_COLORS[clamp(tier, 0, 2)]
		create_tween().tween_property(jam_light, "color", c, 0.6)

func _squash(s: Vector2, dur: float = 0.16) -> void:
	var node: Node2D = anim_sprite if anim_sprite else sprite
	if node == null:
		return
	if squash_tween and squash_tween.is_valid():
		squash_tween.kill()
	node.scale = Vector2(base_scale.x * s.x, base_scale.y * s.y)
	squash_tween = create_tween()
	squash_tween.tween_property(node, "scale", base_scale, dur).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	if jam_light:
		jam_light.visible = is_fantasy
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

# ---------------------------------------------------------------- profil per ruangan

var body_scale: float = 1.0
var _base_collision_size := Vector2.ZERO
var _base_collision_pos := Vector2.ZERO
var _base_sprite_pos := Vector2.ZERO
var heavy_legs: bool = false

## Ruang parkour memakai karakter lebih kecil (dunia lebih luas) dan fisika lompat lebih tinggi.
func set_body_scale(k: float) -> void:
	var node: Node2D = anim_sprite if anim_sprite else sprite
	if node == null:
		return
	if _base_collision_size == Vector2.ZERO and collision_shape and collision_shape.shape is RectangleShape2D:
		_base_collision_size = (collision_shape.shape as RectangleShape2D).size
		_base_collision_pos = collision_shape.position
		_base_sprite_pos = node.position
	body_scale = k
	base_scale = base_scale * (k / maxf(body_scale_prev, 0.001))
	body_scale_prev = k
	node.scale = base_scale
	node.position = _base_sprite_pos * k
	if collision_shape and _base_collision_size != Vector2.ZERO:
		var rect := RectangleShape2D.new()
		rect.size = _base_collision_size * k
		collision_shape.shape = rect
		collision_shape.position = _base_collision_pos * k
	if jam_light:
		jam_light.position = Vector2(0, -42) * k

var body_scale_prev: float = 1.0

func set_physics_profile(speed: float, jump: float, grav: float) -> void:
	walk_speed = speed
	jump_velocity = jump
	gravity = grav
	if heavy_legs:
		_apply_heavy()

## Tidak makan di Mbok Luna: kaki terasa berat (lompat ~12% lebih rendah, jalan lebih pelan).
func set_heavy_legs(on: bool) -> void:
	if on == heavy_legs:
		return
	heavy_legs = on
	if on:
		_apply_heavy()
	else:
		walk_speed /= 0.88
		jump_velocity /= 0.9

func _apply_heavy() -> void:
	walk_speed *= 0.88
	jump_velocity *= 0.9

# Rasa lompat ramah (dipakai di parkour): gravitasi lebih ringan di puncak saat tombol ditahan,
# kecepatan jatuh dibatasi, coyote time & jump buffer lebih panjang.
var apex_gravity_scale: float = 1.0
var apex_window: float = 70.0
var max_fall_speed: float = 100000.0
var _air_top_y: float = 0.0
var _knock_timer: float = 0.0

func set_feel(coyote: float, buffer: float, apex_scale: float, max_fall: float) -> void:
	coyote_time_max = coyote
	jump_buffer_max = buffer
	apex_gravity_scale = apex_scale
	max_fall_speed = max_fall

## Dipakai saat teleport (respawn) supaya tidak dihitung jatuh.
func reset_air() -> void:
	_air_top_y = global_position.y
	fall_speed_peak = 0.0

## Terpental (kena trauma): kontrol dikunci sebentar, tetap kena gravitasi.
func knockback(v: Vector2, lock: float = 0.3) -> void:
	velocity = v
	_knock_timer = lock

func _gravity_step(delta: float) -> void:
	var g := gravity
	if apex_gravity_scale < 1.0 and Input.is_action_pressed("jump") and absf(velocity.y) < apex_window:
		g *= apex_gravity_scale
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)

func face_left(left: bool) -> void:
	if anim_sprite:
		anim_sprite.flip_h = left
	elif sprite:
		sprite.flip_h = left

func _kill_y() -> float:
	var room = RoomManager.current_room_node
	if is_instance_valid(room) and "kill_y" in room:
		return float(room.kill_y)
	return 300.0

func _physics_process(delta: float) -> void:
	# Jatuh ke kehampaan: kembali ke titik respawn ruangan.
	if global_position.y > _kill_y():
		RoomManager.respawn_player()
		return
		
	if not is_movement_enabled:
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		_track_air()
		_update_contact_shadow()
		return

	if _knock_timer > 0.0:
		_knock_timer -= delta
		_gravity_step(delta)
		move_and_slide()
		_track_air()
		_update_contact_shadow()
		return

	# Gravity
	if not is_on_floor():
		_gravity_step(delta)
		coyote_timer -= delta
		fall_speed_peak = max(fall_speed_peak, velocity.y)
	else:
		coyote_timer = coyote_time_max

	# Lompat lebih pendek kalau tombol dilepas cepat
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= JUMP_CUT

	# Denyut cahaya jam
	if jam_light and jam_light.visible:
		jam_pulse += delta
		jam_light.energy = 0.55 + sin(jam_pulse * 3.0) * 0.12

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
		_squash(Vector2(0.82, 1.2))
		_puff(6)

	# Landing sound
	if not was_on_floor and is_on_floor():
		if cached_am:
			cached_am.play_sfx("land")
		var hard: float = clamp(fall_speed_peak / 400.0, 0.3, 1.0)
		_squash(Vector2(1.0 + 0.25 * hard, 1.0 - 0.22 * hard), 0.2)
		_puff(int(6 + 8 * hard))
		fall_speed_peak = 0.0
	was_on_floor = is_on_floor()

	# Horizontal movement
	var dir = Input.get_axis("move_left", "move_right")
	if dir != 0.0:
		var accel := ACCEL_GROUND if is_on_floor() else ACCEL_AIR
		velocity.x = move_toward(velocity.x, dir * walk_speed, accel * delta)
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
				_puff(3)
		else:
			if velocity.y < 0:
				_play_anim("jump")
			else:
				_play_anim("fall")
	else:
		velocity.x = move_toward(velocity.x, 0.0, (DECEL_GROUND if is_on_floor() else ACCEL_AIR) * delta)
		footstep_timer = 0.2
		if is_on_floor():
			_play_anim("idle")
		else:
			if velocity.y < 0:
				_play_anim("jump")
			else:
				_play_anim("fall")

	move_and_slide()
	_track_air()
	_update_contact_shadow()

var _was_floor_track := true

func _track_air() -> void:
	if is_on_floor():
		if not _was_floor_track:
			landed.emit(global_position.y - _air_top_y)
		_air_top_y = global_position.y
		_was_floor_track = true
	else:
		_air_top_y = minf(_air_top_y, global_position.y)
		_was_floor_track = false
