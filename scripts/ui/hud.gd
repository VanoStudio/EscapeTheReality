extends CanvasLayer

@export var watch_icon: TextureRect
@export var stability_bar: ProgressBar
@export var stability_label: Label
@export var timer_label: Label
@export var scrap_label: Label
@export var tint_rect: ColorRect

var pulse_time: float = 0.0

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _get_room_manager() -> Node:
	return get_node_or_null("/root/RoomManager")

func _get_asset_registry() -> Node:
	return get_node_or_null("/root/AssetRegistry")

func _ready() -> void:
	layer = 10
	var gs = _get_game_state()
	if gs:
		gs.stability_changed.connect(_on_stability_changed)
		gs.tier_changed.connect(_on_tier_changed)
		gs.loop_triggered.connect(_on_loop_triggered)
	var rm = _get_room_manager()
	if rm:
		rm.room_changed.connect(_on_room_changed)
		
	update_hud()

func _process(delta: float) -> void:
	var gs = _get_game_state()
	if gs == null:
		return
	var tier = gs.get_tier()
	if tier == 2 and watch_icon: # 2 is Tier.HAMPIR_MELEDAK
		pulse_time += delta * 6.0
		var s = 1.0 + sin(pulse_time) * 0.08
		watch_icon.scale = Vector2(s, s)
	elif watch_icon:
		watch_icon.scale = Vector2.ONE
		pulse_time = 0.0

func update_hud() -> void:
	var gs = _get_game_state()
	if gs == null:
		return
	var rm = _get_room_manager()
	if rm and not rm.is_fantasy_world():
		if stability_bar: stability_bar.visible = false
		if stability_label: stability_label.visible = false
		if watch_icon: watch_icon.visible = false
		if scrap_label: scrap_label.visible = false
		return
	else:
		if stability_bar: stability_bar.visible = true
		if stability_label: stability_label.visible = true
		if watch_icon: watch_icon.visible = true
		
	var stab = gs.stability
	var tier = gs.get_tier()
	
	if stability_bar:
		var bar_tween = create_tween()
		bar_tween.tween_property(stability_bar, "value", float(stab), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if stability_label:
		stability_label.text = str(stab) + "%"
		
	_update_watch_texture(tier)
	_update_tier_colors(tier)
	_update_tint_effect(tier)
	
	if watch_icon:
		var watch_tween = create_tween()
		watch_tween.tween_property(watch_icon, "scale", Vector2(1.18, 1.18), 0.12)
		watch_tween.tween_property(watch_icon, "scale", Vector2.ONE, 0.15)
	
	if scrap_label:
		if rm and rm.current_room_id == "F4":
			scrap_label.visible = true
			scrap_label.text = "Sobekan Foto: %d/3" % gs.photo_scraps
		else:
			scrap_label.visible = false

func _update_tier_colors(tier: int) -> void:
	if stability_bar:
		var fill_style = stability_bar.get_theme_stylebox("fill")
		if fill_style and fill_style is StyleBoxFlat:
			var flat = fill_style.duplicate() as StyleBoxFlat
			match tier:
				0: # TENANG
					flat.bg_color = Color(0.2, 0.75, 0.7, 1.0)
				1: # KESEL
					flat.bg_color = Color(0.92, 0.55, 0.2, 1.0)
				2: # HAMPIR_MELEDAK
					flat.bg_color = Color(0.85, 0.22, 0.22, 1.0)
			stability_bar.add_theme_stylebox_override("fill", flat)

func _update_watch_texture(tier: int) -> void:
	var ar = _get_asset_registry()
	if watch_icon == null or ar == null:
		return
	match tier:
		0: # TENANG
			watch_icon.texture = ar.get_texture(ar.WATCHES["teal"])
		1: # KESEL
			watch_icon.texture = ar.get_texture(ar.WATCHES["orange"])
		2: # HAMPIR_MELEDAK
			watch_icon.texture = ar.get_texture(ar.WATCHES["red"])

func _update_tint_effect(tier: int) -> void:
	if tint_rect == null or tint_rect.material == null:
		return
	var mat = tint_rect.material as ShaderMaterial
	if mat == null:
		return
		
	match tier:
		0: # TENANG
			mat.set_shader_parameter("tint_amount", 0.0)
			mat.set_shader_parameter("vignette_intensity", 0.0)
			mat.set_shader_parameter("shake_power", 0.0)
		1: # KESEL
			mat.set_shader_parameter("tint_amount", 0.15)
			mat.set_shader_parameter("tint_color", Color(1.0, 0.45, 0.0, 1.0))
			mat.set_shader_parameter("vignette_intensity", 0.0)
			mat.set_shader_parameter("shake_power", 0.0)
		2: # HAMPIR_MELEDAK
			mat.set_shader_parameter("tint_amount", 0.30)
			mat.set_shader_parameter("tint_color", Color(0.9, 0.1, 0.1, 1.0))
			mat.set_shader_parameter("vignette_intensity", 1.0)
			mat.set_shader_parameter("shake_power", 1.5)

func _on_stability_changed(_new_value: int, _delta: int) -> void:
	update_hud()

func _on_tier_changed(_new_tier: int) -> void:
	update_hud()

func _on_room_changed(_room_id: String) -> void:
	update_hud()

func _on_loop_triggered() -> void:
	update_hud()

func set_timer_display(remaining: float, is_active: bool) -> void:
	if timer_label:
		timer_label.visible = is_active
		if is_active:
			timer_label.text = "%02d:%02d" % [int(remaining / 60.0), int(remaining) % 60]
