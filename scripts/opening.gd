extends Control

@export var panel_nodes: Array[Control] = []
@export var label_nodes: Array[Control] = []
@export var page_1: Control
@export var page_2: Control
@export var skip_hint: Label

var current_step: int = 0
var is_animating: bool = false
var total_steps: int = 6
var esc_hold_time: float = 0.0
var esc_progress_bar: ProgressBar = null

var panel_texts = [
	"", # Panel 1: Gambar wide pembuka
	"[center]Kakak masih mikirin\nsoal itu, kan?\nSemua orang\njuga tahu kok.[/center]", # Panel 2: Balon Adik
	"Kirana menahan getaran di dada...\ntangannya mengepal erat.", # Panel 3: Narasi
	"[center][font_size=64][color=#b91c1c]CUKUP![/color][/font_size]\n[font_size=34][color=#18151f]Itu bukan urusanmu![/color][/font_size][/center]", # Panel 4: Balon jeritan Kirana
	"Adik terdiam, kaget menatap kakaknya.", # Panel 5: Narasi
	"Pintu kamar dibanting.\nKirana kembali sendirian di ruang tamu..." # Panel 6: Narasi
]

func _ready() -> void:
	if skip_hint:
		skip_hint.text = "[Enter / Spasi] Lanjut  |  [Tahan Esc 3 Detik] Lewati"
	_setup_comic_fonts()
	_setup_esc_progress()
	_show_step(0)
	_check_pending_screenshot()

func _setup_comic_fonts() -> void:
	if FileAccess.file_exists("res://assets/processed/fonts/comic_dialog_bold.ttf"):
		var bubble_font = FontFile.new()
		if bubble_font.load_dynamic_font("res://assets/processed/fonts/comic_dialog_bold.ttf") == OK:
			if label_nodes.size() > 1 and label_nodes[1] is Control:
				label_nodes[1].add_theme_font_override("normal_font", bubble_font)
				label_nodes[1].add_theme_font_override("bold_font", bubble_font)
				
	if FileAccess.file_exists("res://assets/processed/fonts/scream.ttf"):
		var scream_font = FontFile.new()
		if scream_font.load_dynamic_font("res://assets/processed/fonts/scream.ttf") == OK:
			if label_nodes.size() > 3 and label_nodes[3] is Control:
				label_nodes[3].add_theme_font_override("normal_font", scream_font)
				label_nodes[3].add_theme_font_override("bold_font", scream_font)
				
	if FileAccess.file_exists("res://assets/processed/fonts/comic_dialog.ttf"):
		var caption_font = FontFile.new()
		if caption_font.load_dynamic_font("res://assets/processed/fonts/comic_dialog.ttf") == OK:
			for idx in [2, 4, 5]:
				if label_nodes.size() > idx and label_nodes[idx] is Label:
					label_nodes[idx].add_theme_font_override("font", caption_font)

func _check_pending_screenshot() -> void:
	var args = Array(OS.get_cmdline_user_args())
	args.append_array(OS.get_cmdline_args())
	var shot_name = ""
	var step_to_show = -1
	for arg in args:
		if arg.begins_with("--shot="):
			shot_name = arg.trim_prefix("--shot=")
		elif arg.begins_with("--step="):
			step_to_show = int(arg.trim_prefix("--step="))
			
	if shot_name != "" and shot_name.contains("opening"):
		if step_to_show >= 0:
			current_step = step_to_show
			_show_step(step_to_show)
		await get_tree().create_timer(1.0).timeout
		var dir = DirAccess.open("res://")
		if not dir.dir_exists("tests/screenshots"):
			dir.make_dir_recursive("tests/screenshots")
		var img = get_viewport().get_texture().get_image()
		img.save_png("res://tests/screenshots/%s.png" % shot_name)
		print("Screenshot captured: res://tests/screenshots/%s.png" % shot_name)
		get_tree().quit(0)

func _setup_esc_progress() -> void:
	esc_progress_bar = ProgressBar.new()
	esc_progress_bar.name = "EscProgressBar"
	esc_progress_bar.visible = false
	esc_progress_bar.min_value = 0.0
	esc_progress_bar.max_value = 100.0
	esc_progress_bar.value = 0.0
	esc_progress_bar.show_percentage = false
	esc_progress_bar.size = Vector2(240, 10)
	esc_progress_bar.position = Vector2(40, 1030)
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
		for i in range(idx):
			if i < panel_nodes.size() and panel_nodes[i]:
				panel_nodes[i].visible = true
				panel_nodes[i].modulate.a = 1.0
			if i < label_nodes.size() and label_nodes[i]:
				label_nodes[i].visible = true
				label_nodes[i].modulate.a = 1.0
				if label_nodes[i] is Label:
					label_nodes[i].visible_ratio = 1.0
	else:
		if page_1: page_1.visible = false
		if page_2: page_2.visible = true
		for i in range(3, idx):
			if i < panel_nodes.size() and panel_nodes[i]:
				panel_nodes[i].visible = true
				panel_nodes[i].modulate.a = 1.0
			if i < label_nodes.size() and label_nodes[i]:
				label_nodes[i].visible = true
				label_nodes[i].modulate.a = 1.0
				if label_nodes[i] is Label:
					label_nodes[i].visible_ratio = 1.0
		
	if idx < panel_nodes.size() and panel_nodes[idx]:
		var p = panel_nodes[idx]
		p.visible = true
		p.modulate.a = 0.0
		
		# Animasi slide & bounce 0.35s ala Robbery Bob
		var tween = create_tween()
		var orig_y = p.position.y
		p.position.y += 25.0
		tween.tween_property(p, "modulate:a", 1.0, 0.35)
		tween.parallel().tween_property(p, "position:y", orig_y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		
		# Efek audio dramatis
		var am = get_node_or_null("/root/AudioManager")
		if idx == 2 and am: # Panel 3: Heartbeat
			am.play_sfx("heartbeat")
		elif idx == 3: # Panel 4: Bentakan & impact
			if am: am.play_sfx("impact")
			_shake_screen()
		elif idx == 5 and am: # Panel 6: Pintu dibanting
			am.play_sfx("door_slam")
			
		await tween.finished
		
	# Tampilkan teks jika ada
	if idx < label_nodes.size() and label_nodes[idx]:
		var l = label_nodes[idx]
		l.visible = true
		if l is Label:
			l.text = panel_texts[idx]
			l.visible_ratio = 0.0
			var text_tween = create_tween()
			text_tween.tween_property(l, "visible_ratio", 1.0, 0.4)
			await text_tween.finished
		elif l is RichTextLabel:
			l.text = panel_texts[idx]
			l.visible_ratio = 1.0
			l.modulate.a = 0.0
			var text_tween = create_tween()
			text_tween.tween_property(l, "modulate:a", 1.0, 0.3)
			await text_tween.finished
			
	is_animating = false

func _shake_screen() -> void:
	var tween = create_tween()
	var orig_pos = position
	for i in range(5):
		var offset = Vector2(randf_range(-14, 14), randf_range(-14, 14))
		tween.tween_property(self, "position", orig_pos + offset, 0.03)
	tween.tween_property(self, "position", orig_pos, 0.03)

func _skip_to_gameplay() -> void:
	set_process_unhandled_input(false)
	var rm = get_node_or_null("/root/RoomManager")
	if rm and rm.has_method("change_room"):
		rm.change_room("R1", true)
	else:
		get_tree().change_scene_to_file("res://scenes/rooms/R1.tscn")
