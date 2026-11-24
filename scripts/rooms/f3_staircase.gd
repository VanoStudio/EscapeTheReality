class_name F3Staircase
extends LayeredRoom

@export var k2_trigger_zone: Area2D
var k2_round: int = 1
var is_k2_active: bool = false
var loop_count: int = 0

func _ready() -> void:
	super._ready()
	if k2_trigger_zone == null and has_node("K2Trigger"):
		k2_trigger_zone = $K2Trigger
	if k2_trigger_zone:
		k2_trigger_zone.body_entered.connect(_on_k2_trigger_entered)

func _on_exit_right_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if RoomManager.k2_finished:
		RoomManager.change_room(next_room_id, true)
	else:
		loop_count += 1
		RoomManager.handle_f3_loop()

func _on_k2_trigger_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or RoomManager.k2_finished or is_k2_active:
		return
	
	# Memicu event K2 ronde 1 atau ronde 2
	is_k2_active = true
	# Mulai dialog K2 via DialogManager jika sudah terpasang
	if has_node("/root/DialogManager"):
		var dm = get_node("/root/DialogManager")
		if dm.has_method("start_k2_round"):
			dm.start_k2_round(k2_round)
