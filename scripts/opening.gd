extends Control

@export var panel_nodes: Array[TextureRect] = []
@export var label_nodes: Array[Label] = []
@export var page_1: Control
@export var page_2: Control
@export var skip_hint: Label

var current_step: int = 0
var is_animating: bool = false
var total_steps: int = 6
var esc_hold_time: float = 0.0
var esc_progress_bar: ProgressBar = null

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
		skip_hint.text = "[Enter / Spasi] Lanjut  |  [Tahan Esc 3 Detik] Lewati"
	_setup_esc_progress()
	_show_step(0)

func _setup_esc_progress() -> void:
	esc_progress_bar = ProgressBar.new()
	esc_progress_bar.name = "EscProgressBar"
	esc_progress_bar.visible = false
	esc_progress_bar.min_value = 0.0
	esc_progress_bar.max_value = 100.0
	esc_progress_bar.value = 0.0
	esc_progress_bar.show_percentage = false
	esc_progress_bar.size = Vector2(160, 8)
	esc_progress_bar.position = Vector2(30, 250)
	add_child(esc_progress_bar)

func _process(delta: float) -> void:
	if Input.is_action_pressed("pause") or Input.is_key_pressed(KEY_ESCAPE):
		esc_hold_time += delta
		if esc_progress_bar:
			esc_progress_bar.visible = true
			esc_progress_bar.value = (esc_hold_time / 3.0) * 100.0
		if esc_hold_time >= 3.0:
			set_process(false)
			_skip_to_gameplay()
	else:
		esc_hold_time = 0.0
		if esc_progress_bar:
			esc_progress_bar.visible = false
			esc_progress_bar.value = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		if not is_animating:
			_advance_step()
		get_viewport().set_input_as_handled()

func _advance_step() -> void:
	var am = get_node_or_null("/root/AudioManager")
	if am:
		am.play_sfx("select")
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
		
		# Audio per momen dramatis komik
		var am = get_node_or_null("/root/AudioManager")
		if idx == 2 and am: # Panel 3: Matanya berkaca-kaca, detak jantung
			am.play_sfx("heartbeat")
		elif idx == 3: # Panel 4: Bentakan, hentakan impact & shake
			if am: am.play_sfx("impact")
			_shake_screen()
		elif idx == 5 and am: # Panel 6: Pintu dibanting
			am.play_sfx("door_slam")
			
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
