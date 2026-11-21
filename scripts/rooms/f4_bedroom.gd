class_name F4Bedroom
extends BaseRoom

@export var frame_sprite: Sprite2D
@export var scrap_nodes: Array[Node2D] = []

func _ready() -> void:
	super._ready()
	_setup_scraps()

func _setup_scraps() -> void:
	for i in range(1, 4):
		var scrap_path = "Scrap" + str(i)
		if has_node(scrap_path):
			var scrap_node = get_node(scrap_path) as Area2D
			if scrap_node and not scrap_node.body_entered.is_connected(_on_scrap_picked):
				scrap_node.body_entered.connect(_on_scrap_picked.bind(i, scrap_node))
				
	if has_node("PhotoFrame"):
		var frame = get_node("PhotoFrame") as Area2D
		if frame and not frame.body_entered.is_connected(_on_frame_interact_zone):
			frame.body_entered.connect(_on_frame_interact_zone)

func _on_scrap_picked(body: Node2D, scrap_index: int, scrap_node: Area2D) -> void:
	if body.is_in_group("player"):
		GameState.add_photo_scrap()
		scrap_node.queue_free()
		# Tampilkan kalimat ingatan di HUD/Dialog
		if has_node("/root/DialogManager"):
			var dm = get_node("/root/DialogManager")
			if dm.has_method("show_memory_line"):
				dm.show_memory_line("f4_scrap_" + str(scrap_index))

func _on_frame_interact_zone(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	# Interaksi dengan bingkai foto
	if GameState.photo_scraps >= 3:
		RoomManager.photo_puzzle_solved = true
		if frame_sprite and AssetRegistry:
			frame_sprite.texture = AssetRegistry.get_texture(AssetRegistry.SCRAPS["photo_completed"])
	else:
		# Boks dialog penuh Bayangan: "Masih ada yang hilang."
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
