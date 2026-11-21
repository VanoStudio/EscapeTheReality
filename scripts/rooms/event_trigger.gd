class_name EventTrigger
extends Area2D

@export var event_name: String = ""
@export var trigger_once: bool = true
var triggered: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if trigger_once and triggered:
		return
	triggered = true
	
	if has_node("/root/DialogManager"):
		var dm = get_node("/root/DialogManager")
		match event_name:
			"prolog":
				dm.play_prolog()
			"k1":
				dm.play_k1()
			"k3":
				dm.start_k3_round(1)
