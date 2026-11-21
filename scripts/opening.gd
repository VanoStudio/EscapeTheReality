extends Control

@export var panel_nodes: Array[TextureRect] = []
@export var label_nodes: Array[Label] = []
@export var page_1: Control
@export var page_2: Control
@export var skip_hint: Label

var current_step: int = 0
var is_animating: bool = false
var total_steps: int = 6

var panel_texts = [
	"", # Panel 1: Tidak ada balon
	"Adik: \"Kakak masih mikirin soal itu, kan? Semua orang juga tahu kok.\"",
	"Kirana: (Tangannya mengepal, menahan getaran di dada...)",
	"Kirana: \"CUKUP! Itu bukan urusanmu!\"",
	"Adik terdiam, kaget menatap kakaknya.",
	"Pintu kamar dibanting. Kirana kembali sendirian di ruang tamu..."
]

func _ready() -> void:
	if skip_hint:
		skip_hint.text = "[Enter / Spasi] Lanjut  |  [Esc] Lewati"
	_show_step(0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		_skip_to_gameplay()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		if not is_animating:
			_advance_step()
		get_viewport().set_input_as_handled()

func _advance_step() -> void:
	current_step += 1
	if current_step >= total_steps:
		_skip_to_gameplay()
	else:
		_show_step(current_step)

func _show_step(idx: int) -> void:
	is_animating = true
	
	# Halaman 1 vs Halaman 2
	if idx < 3:
		if page_1: page_1.visible = true
		if page_2: page_2.visible = false
	else:
		if page_1: page_1.visible = false
		if page_2: page_2.visible = true
		
	if idx < panel_nodes.size() and panel_nodes[idx]:
		var p = panel_nodes[idx]
		p.visible = true
		p.modulate.a = 0.0
		
		# Animasi slide & bounce 0.35s
		var tween = create_tween()
		p.position.y += 20.0
		tween.tween_property(p, "modulate:a", 1.0, 0.35)
		tween.parallel().tween_property(p, "position:y", p.position.y - 20.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# Khusus Panel 4: Hentakan, kilat putih & shake
		if idx == 3:
			_shake_screen()
			
		await tween.finished
		
	# Tampilkan teks jika ada
	if idx < label_nodes.size() and label_nodes[idx]:
		var l = label_nodes[idx]
		l.visible = true
		l.text = panel_texts[idx]
		l.visible_ratio = 0.0
		var text_tween = create_tween()
		text_tween.tween_property(l, "visible_ratio", 1.0, 0.5)
		await text_tween.finished
		
	is_animating = false

func _shake_screen() -> void:
	var tween = create_tween()
	var orig_pos = position
	for i in range(4):
		var offset = Vector2(randf_range(-12, 12), randf_range(-12, 12))
		tween.tween_property(self, "position", orig_pos + offset, 0.04)
	tween.tween_property(self, "position", orig_pos, 0.04)

func _skip_to_gameplay() -> void:
	set_process_unhandled_input(false)
	var rm = get_node_or_null("/root/RoomManager")
	if rm and rm.has_method("change_room"):
		rm.change_room("R1", true)
	else:
		get_tree().change_scene_to_file("res://scenes/rooms/R1.tscn")
