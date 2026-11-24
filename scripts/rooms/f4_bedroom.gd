class_name F4Bedroom
extends LayeredRoom

@export var frame_sprite: Sprite2D
@export var scrap_nodes: Array[Node2D] = []

var is_player_at_frame: bool = false
var hint_sprite: Sprite2D = null

func _ready() -> void:
	super._ready()
	_setup_scraps()
	_setup_frame_hint()

func _setup_scraps() -> void:
	for i in range(1, 4):
		var scrap_path = "Scrap" + str(i)
		if has_node(scrap_path):
			var scrap_node = get_node(scrap_path) as Area2D
			if scrap_node and not scrap_node.body_entered.is_connected(_on_scrap_picked):
				scrap_node.body_entered.connect(_on_scrap_picked.bind(i, scrap_node))
				
	if has_node("PhotoFrame"):
		var frame = get_node("PhotoFrame") as Area2D
		if frame:
			if not frame.body_entered.is_connected(_on_frame_entered):
				frame.body_entered.connect(_on_frame_entered)
			if not frame.body_exited.is_connected(_on_frame_exited):
				frame.body_exited.connect(_on_frame_exited)

func _setup_frame_hint() -> void:
	if has_node("PhotoFrame"):
		var frame = get_node("PhotoFrame")
		hint_sprite = Sprite2D.new()
		hint_sprite.name = "InteractHint"
		hint_sprite.visible = false
		hint_sprite.position = Vector2(0, -28)
		hint_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var ar = get_node_or_null("/root/AssetRegistry")
		if ar:
			var tex = ar.get_texture(ar.PROPS.get("interact_hint", ""))
			if tex:
				hint_sprite.texture = tex
		frame.add_child(hint_sprite)

func _unhandled_input(event: InputEvent) -> void:
	if is_player_at_frame and event.is_action_pressed("interact"):
		_interact_with_frame()
		get_viewport().set_input_as_handled()

func _on_scrap_picked(body: Node2D, scrap_index: int, scrap_node: Area2D) -> void:
	if body.is_in_group("player"):
		GameState.add_photo_scrap()
		var am = get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx("pickup")
		scrap_node.queue_free()
		# Tampilkan kalimat ingatan di Dialog
		if has_node("/root/DialogManager"):
			var dm = get_node("/root/DialogManager")
			if dm.has_method("show_memory_line"):
				dm.show_memory_line("f4_scrap_" + str(scrap_index))

func _on_frame_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_at_frame = true
		if hint_sprite:
			hint_sprite.visible = true

func _on_frame_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_at_frame = false
		if hint_sprite:
			hint_sprite.visible = false

func _interact_with_frame() -> void:
	if GameState.photo_scraps >= 3:
		RoomManager.photo_puzzle_solved = true
		if frame_sprite and AssetRegistry:
			frame_sprite.texture = AssetRegistry.get_texture(AssetRegistry.SCRAPS["photo_completed"])
		var am = get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx("select")
		if hint_sprite:
			hint_sprite.visible = false
	else:
		if has_node("/root/DialogManager"):
			var dm = get_node("/root/DialogManager")
			if dm.has_method("show_shadow_dialog"):
				dm.show_shadow_dialog("Masih ada yang hilang.")

func _on_exit_right_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if RoomManager.photo_puzzle_solved:
		RoomManager.change_room(next_room_id, true)
	else:
		if has_node("/root/DialogManager"):
			var dm = get_node("/root/DialogManager")
			if dm.has_method("show_shadow_dialog"):
				dm.show_shadow_dialog("Pintu masih terkunci. Selesaikan foto masa kecil kalian dulu.")
