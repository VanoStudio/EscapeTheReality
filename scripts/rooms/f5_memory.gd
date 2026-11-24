class_name F5Memory
extends LayeredRoom

@export var bayangan_node: Node2D
@export var bayangan_sprite: Sprite2D

func _ready() -> void:
	super._ready()
	_setup_bayangan()
	var dm = get_node_or_null("/root/DialogManager")
	if dm and not dm.event_finished.is_connected(_on_dialog_event_finished):
		dm.event_finished.connect(_on_dialog_event_finished)

func _setup_bayangan() -> void:
	if bayangan_node == null and has_node("Bayangan"):
		bayangan_node = $Bayangan
	if bayangan_sprite == null and has_node("Bayangan/Sprite2D"):
		bayangan_sprite = $Bayangan/Sprite2D
	if bayangan_sprite and ResourceLoader.exists("res://shaders/shadow_character.gdshader"):
		var shader = load("res://shaders/shadow_character.gdshader") as Shader
		var mat = ShaderMaterial.new()
		mat.shader = shader
		bayangan_sprite.material = mat

func _on_dialog_event_finished(event_id: String) -> void:
	if event_id == "k3":
		# Bayangan menyatu ke tubuh Kirana
		if bayangan_node and RoomManager.current_player:
			var tween = create_tween()
			tween.tween_property(bayangan_node, "global_position", RoomManager.current_player.global_position, 0.8)
			tween.parallel().tween_property(bayangan_node, "modulate:a", 0.0, 0.8)
