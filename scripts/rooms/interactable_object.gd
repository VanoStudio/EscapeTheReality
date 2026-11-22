class_name InteractableObject
extends Area2D

signal interacted()

@export var prompt_text: String = "E"
@export var memory_key: String = ""
@export var shadow_dialog_text: String = ""
@export var trigger_once: bool = false
@export var auto_interact: bool = false

var is_player_in_range: bool = false
var has_interacted: bool = false
var hint_sprite: Sprite2D = null
var interaction_cooldown: float = 0.0
var bob_time: float = 0.0

func _process(delta: float) -> void:
	if interaction_cooldown > 0.0:
		interaction_cooldown -= delta
	if is_player_in_range and hint_sprite and hint_sprite.visible:
		bob_time += delta * 5.0
		hint_sprite.position.y = -26.0 + sin(bob_time) * 2.5

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_setup_hint()

func _setup_hint() -> void:
	hint_sprite = Sprite2D.new()
	hint_sprite.name = "InteractHint"
	hint_sprite.visible = false
	hint_sprite.position = Vector2(0, -25)
	hint_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var ar = get_node_or_null("/root/AssetRegistry")
	if ar:
		var tex = ar.get_texture(ar.PROPS.get("interact_hint", ""))
		if tex:
			hint_sprite.texture = tex
	add_child(hint_sprite)

func _unhandled_input(event: InputEvent) -> void:
	if not is_player_in_range or (trigger_once and has_interacted):
		return
	if interaction_cooldown > 0.0:
		return
	var dm = get_node_or_null("/root/DialogManager")
	if dm and dm.has_method("is_dialog_active") and dm.is_dialog_active():
		return
	if event.is_action_pressed("interact"):
		trigger_interaction()
		get_viewport().set_input_as_handled()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = true
		if trigger_once and has_interacted:
			return
		if auto_interact:
			trigger_interaction()
		elif hint_sprite:
			hint_sprite.visible = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		is_player_in_range = false
		if hint_sprite:
			hint_sprite.visible = false

func trigger_interaction() -> void:
	if trigger_once and has_interacted:
		return
	has_interacted = true
	interaction_cooldown = 0.5
	if hint_sprite:
		hint_sprite.visible = false
		
	var dm = get_node_or_null("/root/DialogManager")
	if memory_key != "" and dm:
		dm.show_memory_line(memory_key)
	elif shadow_dialog_text != "" and dm:
		dm.show_shadow_dialog(shadow_dialog_text)
		
	interacted.emit()
