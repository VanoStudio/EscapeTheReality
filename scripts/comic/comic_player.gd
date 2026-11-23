class_name ComicPlayer
extends Node3D

# Motion comic 2.5D berbasis data (data/comic.json).
# Panel webtoon ditaruh sebagai bidang di ruang 3D di atas halaman kertas gelap,
# kamera bergerak pelan antar panel sehingga ada kedalaman (parallax) tanpa aset 3D.
# Dipakai untuk opening (6 panel, GDD bagian 3) dan ending (2 panel + kredit).

const COMIC_DATA_PATH := "res://data/comic.json"
const BALLOON_PX_PER_UNIT := 180.0
const TYPE_CHARS_PER_SEC := 38.0
const SKIP_HOLD_SEC := 3.0
const PANEL_ENTER_SEC := 0.35
const BALLOON_DELAY_SEC := 0.2

@export var comic_id: String = "opening"

var data: Dictionary = {}
var pages: Array[Dictionary] = []
var panels: Array[Dictionary] = []
var current_step: int = -1
var current_page: int = -1
var busy: bool = false
var finished: bool = false
var typing_label: RichTextLabel = null
var typing_total: int = 0
var typing_progress: float = 0.0
var blip_counter: int = 0
var esc_hold: float = 0.0
var shot_mode: bool = false

# Kamera
var cam_rig: Node3D
var camera: Camera3D
var trauma: float = 0.0
var tremble_node: Node3D = null
var time_acc: float = 0.0

# UI 2D
var ui: CanvasLayer
var flash_rect: ColorRect
var dark_rect: ColorRect
var hint_label: Label
var skip_ring: Control
var outro_root: Control

var paper_material: ShaderMaterial
var glow_shader: Shader

func _ready() -> void:
	name = "Opening" if comic_id == "opening" else "Ending"
	data = _load_comic_data().get(comic_id, {})
	glow_shader = load("res://shaders/soft_glow.gdshader") as Shader
	_build_environment()
	_build_camera()
	_build_paper()
	_build_particles()
	_build_ui()
	_build_pages()
	_start_audio()
	if _check_screenshot_mode():
		return
	await get_tree().create_timer(0.5).timeout
	_next()

# ---------------------------------------------------------------- data

func _load_comic_data() -> Dictionary:
	if not FileAccess.file_exists(COMIC_DATA_PATH):
		push_error("ComicPlayer: data/comic.json tidak ditemukan")
		return {}
	var f := FileAccess.open(COMIC_DATA_PATH, FileAccess.READ)
	var parsed = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}

# ---------------------------------------------------------------- build

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.025, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

func _build_camera() -> void:
	cam_rig = Node3D.new()
	cam_rig.name = "CameraRig"
	add_child(cam_rig)
	camera = Camera3D.new()
	camera.fov = 38.0
	camera.near = 0.1
	camera.far = 200.0
	cam_rig.add_child(camera)
	camera.make_current()
	var first_dist := 17.0
	var pages_def: Array = data.get("pages", [])
	if pages_def.size() > 0:
		first_dist = float(pages_def[0].get("camera_dist", 17.0))
	cam_rig.position = Vector3(0, 0, first_dist + 2.5)

func _build_paper() -> void:
	var mesh := MeshInstance3D.new()
	mesh.name = "Paper"
	var quad := QuadMesh.new()
	quad.size = Vector2(80, 48)
	mesh.mesh = quad
	paper_material = ShaderMaterial.new()
	paper_material.shader = load("res://shaders/comic_paper.gdshader") as Shader
	if comic_id == "ending":
		paper_material.set_shader_parameter("warm_amount", 0.8)
	mesh.material_override = paper_material
	mesh.position = Vector3(0, 0, -4.0)
	add_child(mesh)

func _make_glow_material(color: Color, softness: float, intensity: float, vertex_color: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = glow_shader
	m.set_shader_parameter("tint", color)
	m.set_shader_parameter("softness", softness)
	m.set_shader_parameter("intensity", intensity)
	m.set_shader_parameter("use_vertex_color", vertex_color)
	return m

func _build_particles() -> void:
	# Debu halus di depan dan belakang halaman: memberi parallax saat kamera bergerak.
	var warm := Color(1.0, 0.82, 0.55) if comic_id == "opening" else Color(1.0, 0.85, 0.6)
	var dust := CPUParticles3D.new()
	dust.name = "Dust"
	dust.amount = 70
	dust.lifetime = 10.0
	dust.preprocess = 10.0
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(16, 10, 5)
	dust.position = Vector3(0, 0, 1.5)
	dust.direction = Vector3(0.3, 1, 0)
	dust.spread = 40.0
	dust.gravity = Vector3(0, 0.02, 0)
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.2
	dust.scale_amount_min = 0.5
	dust.scale_amount_max = 1.4
	var dq := QuadMesh.new()
	dq.size = Vector2(0.09, 0.09)
	dq.material = _make_glow_material(warm, 0.9, 1.2, true)
	dust.mesh = dq
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.25, Color(1, 1, 1, 0.8))
	ramp.add_point(0.75, Color(1, 1, 1, 0.6))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	dust.color_ramp = ramp
	add_child(dust)

	var bokeh := CPUParticles3D.new()
	bokeh.name = "Bokeh"
	bokeh.amount = 14
	bokeh.lifetime = 14.0
	bokeh.preprocess = 14.0
	bokeh.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	bokeh.emission_box_extents = Vector3(22, 13, 0.5)
	bokeh.position = Vector3(0, 0, -3.0)
	bokeh.direction = Vector3(1, 0.2, 0)
	bokeh.gravity = Vector3.ZERO
	bokeh.initial_velocity_min = 0.05
	bokeh.initial_velocity_max = 0.15
	bokeh.scale_amount_min = 0.6
	bokeh.scale_amount_max = 1.6
	var bq := QuadMesh.new()
	bq.size = Vector2(2.4, 2.4)
	bq.material = _make_glow_material(warm * Color(1, 1, 1, 0.22), 0.8, 1.0, true)
	bokeh.mesh = bq
	bokeh.color_ramp = ramp
	add_child(bokeh)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.name = "ComicUI"
	ui.layer = 10
	add_child(ui)

	var vignette := TextureRect.new()
	var grad := Gradient.new()
	grad.set_color(0, Color(0, 0, 0, 0))
	grad.set_offset(0, 0.55)
	grad.set_color(1, Color(0, 0, 0, 0.5))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.05, 1.05)
	gt.width = 512
	gt.height = 288
	vignette.texture = gt
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(vignette)

	dark_rect = ColorRect.new()
	dark_rect.color = Color(0, 0, 0, 0)
	dark_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dark_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dark_rect)

	outro_root = Control.new()
	outro_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	outro_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(outro_root)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash_rect)

	hint_label = Label.new()
	hint_label.text = "Enter / Klik  lanjut" if comic_id == "ending" else "Enter / Klik  lanjut     Tahan Esc  lewati"
	hint_label.add_theme_font_size_override("font_size", 18)
	hint_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.8, 0.55))
	hint_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	hint_label.offset_left = -560
	hint_label.offset_top = -56
	hint_label.offset_right = -36
	hint_label.offset_bottom = -24
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint_label.modulate.a = 0.0
	ui.add_child(hint_label)

	skip_ring = Control.new()
	skip_ring.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_ring.offset_left = -96
	skip_ring.offset_top = -132
	skip_ring.offset_right = -36
	skip_ring.offset_bottom = -72
	skip_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_ring.draw.connect(_draw_skip_ring)
	skip_ring.visible = false
	ui.add_child(skip_ring)

func _draw_skip_ring() -> void:
	var c := skip_ring.size * 0.5
	var r: float = min(c.x, c.y) - 4.0
	skip_ring.draw_arc(c, r, 0, TAU, 48, Color(1, 1, 1, 0.18), 4.0, true)
	var p: float = clamp(esc_hold / SKIP_HOLD_SEC, 0.0, 1.0)
	if p > 0.0:
		skip_ring.draw_arc(c, r, -PI * 0.5, -PI * 0.5 + TAU * p, 48, Color(1, 0.86, 0.6, 0.95), 4.0, true)

func _build_pages() -> void:
	var pages_def: Array = data.get("pages", [])
	for pi in range(pages_def.size()):
		var pdef: Dictionary = pages_def[pi]
		var bounds := Rect2()
		var first := true
		for pdef_panel in pdef.get("panels", []):
			var r: Array = pdef_panel.get("rect", [0, 0, 1, 1])
			var pr := Rect2(float(r[0]) - float(r[2]) * 0.5, float(r[1]) - float(r[3]) * 0.5, float(r[2]), float(r[3]))
			bounds = pr if first else bounds.merge(pr)
			first = false
		# Pivot halaman di tepi kiri supaya bisa "dibalik" seperti halaman buku.
		var root := Node3D.new()
		root.name = "Page%d" % (pi + 1)
		root.position = Vector3(bounds.position.x, 0, 0)
		add_child(root)
		var inner := Node3D.new()
		inner.position = Vector3(-bounds.position.x, 0, 0)
		root.add_child(inner)
		var page := {
			"root": root,
			"inner": inner,
			"center": Vector3(bounds.get_center().x, bounds.get_center().y, 0),
			"dist": float(pdef.get("camera_dist", 17.0)),
			"panel_ids": []
		}
		pages.append(page)
		for pdef_panel in pdef.get("panels", []):
			var p := _build_panel(pdef_panel, inner)
			p["page"] = pi
			page["panel_ids"].append(panels.size())
			panels.append(p)

func _make_flat_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = color
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _build_panel(def: Dictionary, parent: Node3D) -> Dictionary:
	var r: Array = def.get("rect", [0, 0, 1, 1])
	var w := float(r[2])
	var h := float(r[3])
	var holder := Node3D.new()
	holder.position = Vector3(float(r[0]), float(r[1]), 0)
	holder.visible = false
	parent.add_child(holder)
	var anim := Node3D.new()
	anim.name = "Anim"
	holder.add_child(anim)

	var shadow := MeshInstance3D.new()
	var sq := QuadMesh.new()
	sq.size = Vector2(w + 0.5, h + 0.5)
	shadow.mesh = sq
	var shadow_flat := _make_flat_material(Color(0, 0, 0, 0.55))
	shadow_flat.render_priority = -2
	shadow.material_override = shadow_flat
	shadow.position = Vector3(0.22, -0.28, -0.08)
	anim.add_child(shadow)

	var border := MeshInstance3D.new()
	var bq := QuadMesh.new()
	bq.size = Vector2(w + 0.2, h + 0.2)
	border.mesh = bq
	var border_mat := _make_flat_material(Color(0.95, 0.92, 0.84, 1))
	border_mat.render_priority = -1
	border.material_override = border_mat
	border.position = Vector3(0, 0, -0.02)
	anim.add_child(border)

	var glow_mesh: MeshInstance3D = null
	var effects: Array = def.get("effects", [])
	if effects.has("glow_warm") or effects.has("glow_teal"):
		glow_mesh = MeshInstance3D.new()
		var gq := QuadMesh.new()
		gq.size = Vector2(w * 1.9, h * 1.5)
		glow_mesh.mesh = gq
		var gc := Color(1.0, 0.7, 0.35, 0.5) if effects.has("glow_warm") else Color(0.35, 0.95, 0.9, 0.45)
		glow_mesh.material_override = _make_glow_material(gc, 0.85, 0.0, false)
		glow_mesh.position = Vector3(0, 0, -0.3)
		anim.add_child(glow_mesh)

	var art := Sprite3D.new()
	art.name = "Art"
	var tex := load(String(def.get("image", ""))) as Texture2D
	var base_region := Rect2(0, 0, 1, 1)
	if tex:
		art.texture = tex
		var tw := float(tex.get_width())
		var th := float(tex.get_height())
		var target_aspect := w / h
		if tw / th > target_aspect:
			var nw := th * target_aspect
			base_region = Rect2((tw - nw) * 0.5, 0, nw, th)
		else:
			var nh := tw / target_aspect
			base_region = Rect2(0, (th - nh) * 0.5, tw, nh)
		art.region_enabled = true
		art.region_rect = base_region
		art.pixel_size = w / base_region.size.x
	art.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	art.shaded = false
	art.transparent = true
	art.double_sided = false
	art.render_priority = 1
	anim.add_child(art)

	var p := {
		"def": def,
		"holder": holder,
		"anim": anim,
		"art": art,
		"w": w,
		"h": h,
		"base_region": base_region,
		"mats": [shadow_flat, border_mat],
		"mat_alpha": [0.55, 1.0],
		"glow": glow_mesh,
		"balloon_label": null,
		"balloon_sprite": null,
		"balloon_vp": null
	}
	if def.has("balloon"):
		_build_balloon(p, def["balloon"], anim)
	return p

func _build_balloon(p: Dictionary, b: Dictionary, anim: Node3D) -> void:
	var uv: Array = b.get("uv", [0, 0, 1, 1])
	var w: float = p["w"]
	var h: float = p["h"]
	var bw := float(uv[2]) * w
	var bh := float(uv[3]) * h
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(int(bw * BALLOON_PX_PER_UNIT), int(bh * BALLOON_PX_PER_UNIT))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.disable_3d = true
	add_child(vp)

	var center := CenterContainer.new()
	center.size = Vector2(vp.size)
	vp.add_child(center)
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(vp.size.x * 0.96, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font_path := String(b.get("font", ""))
	var size := int(b.get("font_size", 32))
	if font_path != "" and ResourceLoader.exists(font_path):
		var font := load(font_path) as Font
		label.add_theme_font_override("normal_font", font)
		label.add_theme_font_override("bold_font", font)
	label.add_theme_font_size_override("normal_font_size", size)
	label.add_theme_color_override("default_color", Color.html(String(b.get("color", "#1b1720"))))
	label.text = _balloon_bbcode(b)
	label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	label.visible_characters = 0
	center.add_child(label)

	var spr := Sprite3D.new()
	spr.texture = vp.get_texture()
	spr.pixel_size = 1.0 / BALLOON_PX_PER_UNIT
	spr.shaded = false
	spr.transparent = true
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var cx := (float(uv[0]) + float(uv[2]) * 0.5 - 0.5) * w
	var cy := -(float(uv[1]) + float(uv[3]) * 0.5 - 0.5) * h
	spr.position = Vector3(cx, cy, 0.03)
	spr.render_priority = 2
	anim.add_child(spr)
	p["balloon_label"] = label
	p["balloon_sprite"] = spr
	p["balloon_vp"] = vp

func _balloon_bbcode(b: Dictionary) -> String:
	var text := String(b.get("text", ""))
	if String(b.get("style", "normal")) == "shout":
		# Kalimat pertama dibuat besar dan merah, sisanya lebih kecil (teks tidak diubah).
		var idx := text.find("! ")
		if idx > 0:
			var first := text.substr(0, idx + 1)
			var rest := text.substr(idx + 2)
			var accent := String(b.get("accent", "#b3121b"))
			var small := int(int(b.get("font_size", 120)) * 0.5)
			return "[center][color=%s]%s[/color]\n[font_size=%d]%s[/font_size][/center]" % [accent, first, small, rest]
	return "[center]%s[/center]" % text

# ---------------------------------------------------------------- audio

func _audio() -> Node:
	return get_node_or_null("/root/AudioManager")

func _start_audio() -> void:
	var am := _audio()
	if am == null:
		return
	if "is_clock_active" in am:
		am.is_clock_active = false
	if data.has("ambience") and am.has_method("play_ambience"):
		am.play_ambience(String(data["ambience"]))
	elif "ambience_player" in am and am.ambience_player:
		_fade_ambience(-40.0, 1.5)
	if data.has("bgm") and am.has_method("play_bgm"):
		am.play_bgm(String(data["bgm"]))
	elif am.has_method("stop_bgm"):
		am.stop_bgm()

func _sfx(sfx_name: String) -> void:
	var am := _audio()
	if am and am.has_method("play_sfx"):
		am.play_sfx(sfx_name)

func _fade_ambience(target_db: float, dur: float) -> void:
	var am := _audio()
	if am and "ambience_player" in am and am.ambience_player:
		create_tween().tween_property(am.ambience_player, "volume_db", target_db, dur)

# ---------------------------------------------------------------- flow

func _unhandled_input(event: InputEvent) -> void:
	if shot_mode or finished:
		return
	var advance := event.is_action_pressed("interact") or event.is_action_pressed("ui_accept") or event.is_action_pressed("jump")
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance = true
	if advance:
		get_viewport().set_input_as_handled()
		_next()

func _process(delta: float) -> void:
	time_acc += delta
	_update_camera(delta)
	_update_typing(delta)
	_update_skip(delta)

func _update_skip(delta: float) -> void:
	if comic_id != "opening" or shot_mode or finished:
		return
	if Input.is_key_pressed(KEY_ESCAPE) or Input.is_action_pressed("skip"):
		esc_hold += delta
		skip_ring.visible = true
		skip_ring.queue_redraw()
		if esc_hold >= SKIP_HOLD_SEC:
			_finish()
	elif esc_hold > 0.0:
		esc_hold = 0.0
		skip_ring.visible = false

func _next() -> void:
	if finished:
		return
	if typing_label != null:
		_finish_typing()
		return
	if busy:
		return
	if hint_label.modulate.a < 0.01 and comic_id == "opening":
		create_tween().tween_property(hint_label, "modulate:a", 1.0, 0.8)
	current_step += 1
	if current_step >= panels.size():
		_finish()
		return
	var p: Dictionary = panels[current_step]
	_enter_panel(p, current_step)

func _enter_panel(p: Dictionary, step: int) -> void:
	busy = true
	var page_idx: int = p["page"]
	if page_idx != current_page:
		if current_page >= 0:
			await _turn_page(current_page)
		current_page = page_idx
	_stop_tremble()
	_focus_camera(p, 1.0)

	var def: Dictionary = p["def"]
	var effects: Array = def.get("effects", [])
	var from := String(def.get("from", "left"))
	var anim: Node3D = p["anim"]
	var holder: Node3D = p["holder"]
	holder.visible = true
	_set_panel_alpha(0.0, p)

	if effects.has("silence"):
		_fade_ambience(-40.0, 1.2)

	var t := create_tween().set_parallel(true)
	if from == "impact":
		anim.position = Vector3(0, 0, 1.2)
		anim.scale = Vector3.ONE * 1.15
		anim.rotation = Vector3(0, 0, deg_to_rad(-2.5))
		t.tween_property(anim, "position", Vector3.ZERO, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		t.tween_property(anim, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		t.tween_property(anim, "rotation", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_method(_set_panel_alpha.bind(p), 0.0, 1.0, 0.1)
	else:
		var off := Vector3(-1.4, 0, 0.9)
		var rot := Vector3(0, deg_to_rad(16), 0)
		match from:
			"top":
				off = Vector3(0, 1.2, 0.9)
				rot = Vector3(deg_to_rad(-14), 0, 0)
			"right":
				off = Vector3(1.4, 0, 0.9)
				rot = Vector3(0, deg_to_rad(-16), 0)
			"bottom":
				off = Vector3(0, -1.2, 0.9)
				rot = Vector3(deg_to_rad(14), 0, 0)
		anim.position = off
		anim.rotation = rot
		anim.scale = Vector3.ONE
		t.tween_property(anim, "position", Vector3.ZERO, PANEL_ENTER_SEC).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(anim, "rotation", Vector3.ZERO, PANEL_ENTER_SEC + 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_method(_set_panel_alpha.bind(p), 0.0, 1.0, PANEL_ENTER_SEC * 0.8)
	if def.has("sfx") and from == "impact":
		pass
	elif def.has("sfx"):
		_sfx(String(def["sfx"]))
	await t.finished
	if def.has("sfx") and from == "impact":
		_sfx(String(def["sfx"]))
	_apply_effects(p, effects)

	if p["balloon_label"] != null:
		await get_tree().create_timer(BALLOON_DELAY_SEC).timeout
		if current_step == step:
			_start_typing(p["balloon_label"])
	busy = false

	if bool(data.get("auto_advance", false)):
		var hold := float(def.get("hold", 3.0))
		await get_tree().create_timer(hold).timeout
		while typing_label != null:
			await get_tree().process_frame
		if current_step == step and not busy and not finished:
			_next()

func _apply_effects(p: Dictionary, effects: Array) -> void:
	var anim: Node3D = p["anim"]
	for e in effects:
		match String(e):
			"flash":
				flash_rect.color.a = 0.95
				create_tween().tween_property(flash_rect, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			"shake_hard":
				trauma = 1.0
			"shake_soft":
				trauma = max(trauma, 0.5)
			"tremble":
				tremble_node = anim
			"heartbeat":
				_heartbeat_loop(current_step)
			"darken":
				create_tween().tween_property(dark_rect, "color:a", 0.42, 2.4).set_trans(Tween.TRANS_SINE)
				create_tween().tween_method(_set_paper_brightness, 1.0, 0.45, 2.4)
			"undarken":
				create_tween().tween_property(dark_rect, "color:a", 0.18, 0.6)
				_fade_ambience(-10.0, 1.5)
			"kenburns":
				_kenburns(p)
			"glow_warm", "glow_teal":
				_pulse_glow(p)
			"tick":
				_tick_loop()

func _set_paper_brightness(v: float) -> void:
	paper_material.set_shader_parameter("brightness", v)

func _set_panel_alpha(a: float, p: Dictionary) -> void:
	var art: Sprite3D = p["art"]
	art.modulate.a = a
	var mats: Array = p["mats"]
	var base: Array = p["mat_alpha"]
	for i in range(mats.size()):
		var m: StandardMaterial3D = mats[i]
		m.albedo_color.a = float(base[i]) * a
	if p["balloon_sprite"] != null:
		(p["balloon_sprite"] as Sprite3D).modulate.a = a

func _kenburns(p: Dictionary) -> void:
	# Zoom pelan ke dalam panel (GDD panel 1: "zoom pelan ke dalam").
	var art: Sprite3D = p["art"]
	var base: Rect2 = p["base_region"]
	var w: float = p["w"]
	var t := create_tween()
	t.tween_method(func(k: float) -> void:
		var sz := base.size * k
		var pos := base.position + (base.size - sz) * Vector2(0.5, 0.45)
		art.region_rect = Rect2(pos, sz)
		art.pixel_size = w / sz.x
	, 1.0, 0.86, 10.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _pulse_glow(p: Dictionary) -> void:
	var g: MeshInstance3D = p["glow"]
	if g == null:
		return
	var m: ShaderMaterial = g.material_override
	var setter := func(v: float) -> void: m.set_shader_parameter("intensity", v)
	await create_tween().tween_method(setter, 0.0, 1.1, 1.6).finished
	var t := create_tween().set_loops()
	t.tween_method(setter, 1.1, 0.65, 2.2).set_trans(Tween.TRANS_SINE)
	t.tween_method(setter, 0.65, 1.1, 2.2).set_trans(Tween.TRANS_SINE)

func _heartbeat_loop(idx: int) -> void:
	# Satu klip detak (beberapa denyut); layar berdenyut mengikuti ritmenya.
	_sfx("heartbeat")
	for i in range(4):
		if current_step != idx or finished:
			return
		trauma = max(trauma, 0.18)
		await get_tree().create_timer(0.9).timeout

func _tick_loop() -> void:
	for i in range(6):
		_sfx("tick")
		await get_tree().create_timer(1.0).timeout

func _stop_tremble() -> void:
	if tremble_node:
		tremble_node.position = Vector3.ZERO
	tremble_node = null

func _turn_page(page_idx: int) -> void:
	# Halaman lama dibalik ke kiri seperti buku, lalu menghilang.
	var page: Dictionary = pages[page_idx]
	var root: Node3D = page["root"]
	_sfx("select")
	var t := create_tween().set_parallel(true)
	t.tween_property(root, "rotation:y", deg_to_rad(-100), 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for pid in page["panel_ids"]:
		t.tween_method(_set_panel_alpha.bind(panels[pid]), 1.0, 0.0, 0.6).set_delay(0.15)
	var next_page: Dictionary = pages[min(page_idx + 1, pages.size() - 1)]
	_move_camera(next_page["center"], float(next_page["dist"]) + 1.5, 0.9)
	await t.finished
	root.visible = false

# ---------------------------------------------------------------- kamera

func _move_camera(target: Vector3, dist: float, dur: float) -> void:
	var t := create_tween()
	t.tween_property(cam_rig, "position", Vector3(target.x, target.y, dist), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _panel_global_center(p: Dictionary) -> Vector3:
	var holder: Node3D = p["holder"]
	var page: Dictionary = pages[p["page"]]
	var root: Node3D = page["root"]
	var inner: Node3D = page["inner"]
	return root.position + inner.position + holder.position

func _focus_camera(p: Dictionary, dur: float) -> void:
	var page: Dictionary = pages[p["page"]]
	var pc: Vector3 = page["center"]
	var target := pc.lerp(_panel_global_center(p), 0.18)
	_move_camera(target, float(page["dist"]) * 0.97, dur)

func _update_camera(delta: float) -> void:
	if camera == null:
		return
	# Napas kamera pelan + goyang (trauma).
	var drift := Vector3(sin(time_acc * 0.31) * 0.18, sin(time_acc * 0.23 + 1.3) * 0.12, 0)
	var rot := Vector3(sin(time_acc * 0.19) * 0.006, sin(time_acc * 0.27 + 0.7) * 0.008, 0)
	trauma = max(trauma - delta * 1.4, 0.0)
	var s := trauma * trauma
	var shake := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * s * 0.55
	camera.position = drift + shake
	camera.rotation = rot + Vector3(0, 0, randf_range(-1, 1) * s * 0.03)
	if tremble_node:
		tremble_node.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.025

# ---------------------------------------------------------------- teks

func _start_typing(label: RichTextLabel) -> void:
	typing_label = label
	typing_total = label.get_total_character_count()
	typing_progress = 0.0
	blip_counter = 0
	label.visible_characters = 0

func _update_typing(delta: float) -> void:
	if typing_label == null:
		return
	typing_progress += delta * TYPE_CHARS_PER_SEC
	var n := int(typing_progress)
	if n != typing_label.visible_characters:
		typing_label.visible_characters = n
		blip_counter += 1
		if blip_counter % 3 == 0:
			_sfx("text_blip")
	if n >= typing_total:
		_finish_typing()

func _finish_typing() -> void:
	if typing_label:
		typing_label.visible_characters = -1
	typing_label = null

# ---------------------------------------------------------------- selesai

func _finish() -> void:
	if finished:
		return
	finished = true
	_stop_tremble()
	skip_ring.visible = false
	create_tween().tween_property(hint_label, "modulate:a", 0.0, 0.3)
	if data.has("outro"):
		await _play_outro(data["outro"])
		return
	var t := create_tween()
	t.tween_property(dark_rect, "color:a", 1.0, 0.7)
	await t.finished
	_go_next()

func _go_next() -> void:
	var nxt := String(data.get("next", "menu"))
	if nxt.begins_with("room:"):
		var rm = get_node_or_null("/root/RoomManager")
		var room_id := nxt.trim_prefix("room:")
		if rm and rm.has_method("change_room"):
			rm.change_room(room_id, true)
		else:
			get_tree().change_scene_to_file("res://scenes/rooms/%s.tscn" % room_id)
	else:
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	l.add_theme_constant_override("shadow_offset_y", 3)
	var fpath := "res://assets/processed/fonts/comic_dialog_bold.ttf"
	if ResourceLoader.exists(fpath):
		l.add_theme_font_override("font", load(fpath) as Font)
	return l

func _play_outro(outro: Dictionary, instant: bool = false) -> void:
	# Ending: halaman meredup, titik hari menyala, teks penutup, "Bersambung", kredit.
	var dim := create_tween().set_parallel(true)
	dim.tween_property(dark_rect, "color:a", 0.8, 0.1 if instant else 1.8)
	_move_camera(Vector3(0, 0, 0), 22.0, 0.1 if instant else 3.0)
	if not instant:
		await dim.finished

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 28)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	outro_root.add_child(box)

	var dots := HBoxContainer.new()
	dots.alignment = BoxContainer.ALIGNMENT_CENTER
	dots.add_theme_constant_override("separation", 34)
	box.add_child(dots)
	var dot_nodes: Array[Panel] = []
	for i in range(int(outro.get("dots", 3))):
		var d := Panel.new()
		d.custom_minimum_size = Vector2(26, 26)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.25, 0.27, 0.3, 0.9)
		sb.set_corner_radius_all(13)
		sb.border_color = Color(0.85, 0.72, 0.45, 0.7)
		sb.set_border_width_all(2)
		d.add_theme_stylebox_override("panel", sb)
		dots.add_child(d)
		dot_nodes.append(d)

	var line_labels: Array[Label] = []
	for line in outro.get("lines", []):
		var l := _make_label(String(line), 40, Color(0.97, 0.93, 0.86))
		l.custom_minimum_size = Vector2(1300, 0)
		l.visible_ratio = 0.0
		box.add_child(l)
		line_labels.append(l)

	var title := _make_label(String(outro.get("title", "")), 64, Color(1.0, 0.8, 0.45))
	title.modulate.a = 0.0
	box.add_child(title)

	# Titik pertama menyala (GDD ending panel 2).
	if not instant:
		await get_tree().create_timer(0.6).timeout
	for i in range(int(outro.get("dots_lit", 1))):
		var sb: StyleBoxFlat = dot_nodes[i].get_theme_stylebox("panel").duplicate()
		sb.bg_color = Color(0.4, 1.0, 0.92)
		sb.shadow_color = Color(0.4, 1.0, 0.92, 0.7)
		sb.shadow_size = 14
		dot_nodes[i].add_theme_stylebox_override("panel", sb)
		dot_nodes[i].pivot_offset = Vector2(13, 13)
		if not instant:
			_sfx("tick")
			dot_nodes[i].scale = Vector2(1.8, 1.8)
			create_tween().tween_property(dot_nodes[i], "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			await get_tree().create_timer(0.9).timeout

	for l in line_labels:
		if instant:
			l.visible_ratio = 1.0
		else:
			var dur := float(l.text.length()) / TYPE_CHARS_PER_SEC * 1.4
			await create_tween().tween_property(l, "visible_ratio", 1.0, dur).finished
			await get_tree().create_timer(1.2).timeout
	if instant:
		title.modulate.a = 1.0
	else:
		await create_tween().tween_property(title, "modulate:a", 1.0, 1.4).finished
		await get_tree().create_timer(2.0).timeout
		await create_tween().tween_property(box, "modulate:a", 0.0, 1.2).finished
		box.queue_free()
		await _roll_credits(outro.get("credits", []))
		var prompt := _make_label("Tekan Enter", 22, Color(0.9, 0.86, 0.78, 0.75))
		prompt.modulate.a = 0.0
		prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		prompt.offset_top = -90
		prompt.offset_left = -200
		prompt.offset_right = 200
		outro_root.add_child(prompt)
		create_tween().tween_property(prompt, "modulate:a", 1.0, 0.8)
		while true:
			await get_tree().process_frame
			if Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("ui_accept"):
				break
		_go_next()

func _roll_credits(credits: Array) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 46)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	col.size = Vector2(1400, 10)
	col.position = Vector2(260, 1120)
	outro_root.add_child(col)
	for c in credits:
		var pair: Array = c
		var block := VBoxContainer.new()
		block.add_theme_constant_override("separation", 6)
		var role := _make_label(String(pair[0]), 22, Color(0.85, 0.75, 0.55))
		role.custom_minimum_size = Vector2(1400, 0)
		block.add_child(role)
		if pair.size() > 1:
			var who := _make_label(String(pair[1]), 34, Color(0.97, 0.94, 0.88))
			who.custom_minimum_size = Vector2(1400, 0)
			block.add_child(who)
		col.add_child(block)
	await get_tree().process_frame
	# Kredit naik dari bawah layar lalu berhenti di tengah.
	var end_y: float = 540.0 - col.size.y * 0.5
	var speed := 80.0
	var t := create_tween()
	t.tween_property(col, "position:y", end_y, (1120.0 - end_y) / speed).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await t.finished
	await get_tree().create_timer(1.0).timeout

# ---------------------------------------------------------------- screenshot CLI

func _check_screenshot_mode() -> bool:
	var args := Array(OS.get_cmdline_user_args())
	args.append_array(OS.get_cmdline_args())
	var shot_name := ""
	var step := -1
	for arg in args:
		if String(arg).begins_with("--shot="):
			shot_name = String(arg).trim_prefix("--shot=")
		elif String(arg).begins_with("--step="):
			step = int(String(arg).trim_prefix("--step="))
	if shot_name == "" or not shot_name.contains(comic_id):
		return false
	shot_mode = true
	_shot(shot_name, step)
	return true

func _shot(shot_name: String, step: int) -> void:
	step = clamp(step, 0, panels.size())
	if step >= panels.size():
		for p in panels:
			_show_panel_instant(p)
		current_step = panels.size() - 1
		_play_outro(data.get("outro", {}), true)
	else:
		var p: Dictionary = panels[step]
		for i in range(step + 1):
			var q: Dictionary = panels[i]
			if q["page"] == p["page"]:
				_show_panel_instant(q)
		current_step = step
		current_page = p["page"]
		var page: Dictionary = pages[p["page"]]
		var target: Vector3 = (page["center"] as Vector3).lerp(_panel_global_center(p), 0.18)
		cam_rig.position = Vector3(target.x, target.y, float(page["dist"]) * 0.97)
		_apply_effects(p, (p["def"] as Dictionary).get("effects", []))
	await get_tree().create_timer(1.6).timeout
	if not DirAccess.dir_exists_absolute("res://tests/screenshots"):
		DirAccess.make_dir_recursive_absolute("res://tests/screenshots")
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tests/screenshots/%s.png" % shot_name)
	print("Screenshot captured: res://tests/screenshots/%s.png" % shot_name)
	get_tree().quit(0)

func _show_panel_instant(p: Dictionary) -> void:
	(p["holder"] as Node3D).visible = true
	_set_panel_alpha(1.0, p)
	if p["balloon_label"] != null:
		(p["balloon_label"] as RichTextLabel).visible_characters = -1
