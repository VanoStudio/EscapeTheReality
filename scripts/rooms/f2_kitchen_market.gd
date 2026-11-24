class_name F2KitchenMarket
extends BaseRoom

@export var penjual_sprite: Sprite2D
@export var locked_door_indicator: Node2D

var is_k1_finished: bool = false

func _ready() -> void:
	super._ready()
	_setup_penjual()
	var dm = get_node_or_null("/root/DialogManager")
	if dm and not dm.event_finished.is_connected(_on_dialog_event_finished):
		dm.event_finished.connect(_on_dialog_event_finished)

func _setup_penjual() -> void:
	if penjual_sprite == null and has_node("Penjual/Sprite2D"):
		penjual_sprite = $Penjual/Sprite2D

func _on_dialog_event_finished(event_id: String) -> void:
	if event_id == "k1":
		is_k1_finished = true
		if locked_door_indicator:
			locked_door_indicator.visible = false
		var am = get_node_or_null("/root/AudioManager")
		if am and am.has_method("play_sfx"):
			am.play_sfx("pickup")

func _on_exit_right_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if is_k1_finished:
		RoomManager.change_room(next_room_id, true)
	else:
		var dm = get_node_or_null("/root/DialogManager")
		if dm and dm.has_method("show_shadow_dialog"):
			dm.show_shadow_dialog("Kamu butuh makanan untuk melewati tangga berikutnya.")
