class_name F1Entrance
extends LayeredRoom

@export var bayangan_sprite: Sprite2D
@export var tutorial_hint: Label

func _ready() -> void:
	super._ready()
	_setup_bayangan()
	_setup_tutorial()
	
	# Connect to dialog manager event finished
	var dm = get_node_or_null("/root/DialogManager")
	if dm and not dm.event_finished.is_connected(_on_dialog_event_finished):
		dm.event_finished.connect(_on_dialog_event_finished)

func _setup_bayangan() -> void:
	if bayangan_sprite == null and has_node("Bayangan"):
		bayangan_sprite = $Bayangan/Sprite2D as Sprite2D
	if bayangan_sprite and ResourceLoader.exists("res://shaders/shadow_character.gdshader"):
		var shader = load("res://shaders/shadow_character.gdshader") as Shader
		var mat = ShaderMaterial.new()
		mat.shader = shader
		bayangan_sprite.material = mat

func _setup_tutorial() -> void:
	if tutorial_hint:
		tutorial_hint.text = "[Spasi / W] Lompat"
		tutorial_hint.modulate.a = 0.0
		tutorial_hint.z_index = 40

func _on_dialog_event_finished(event_id: String) -> void:
	if event_id == "prolog":
		# Munculkan tutorial lompat dengan fade in
		if tutorial_hint:
			var tween = create_tween()
			tween.tween_property(tutorial_hint, "modulate:a", 1.0, 0.5)
			
		# Bayangan berhenti diam dan mulai menemani Kirana.
		if has_node("Bayangan"):
			var b = get_node("Bayangan") as Node2D
			spawn_bayangan_follower(b.global_position)
			var tween_b = create_tween()
			tween_b.tween_property(b, "modulate:a", 0.0, 0.6)
