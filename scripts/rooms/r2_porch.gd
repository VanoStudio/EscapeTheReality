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
		var s = 1.0 + sin(watch_pulse) * 0.15
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
			
	# Efek cahaya jam menyedot Kirana (White flash + shake + impact sound)
	var am = get_node_or_null("/root/AudioManager")
	if am and am.has_method("play_sfx"):
		am.play_sfx("impact")
		
	var tween = create_tween()
	tween.tween_property(flash_overlay, "color:a", 1.0, 0.6)
	if RoomManager.current_player:
		tween.parallel().tween_property(RoomManager.current_player, "position:y", RoomManager.current_player.position.y - 15.0, 0.6)
	await tween.finished
	
	# Selesai menyedot, langsung pindah ke F1
	RoomManager.change_room("F1", true)
