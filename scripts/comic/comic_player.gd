class_name ComicPlayer
extends Node3D

# Motion comic 2.5D berbasis data (data/comic.json).
# Panel webtoon ditaruh sebagai bidang di ruang 3D di atas halaman kertas gelap,
# kamera bergerak antar panel sehingga ada kedalaman (parallax) tanpa aset 3D.
# Dipakai untuk opening (13 panel webtoon + bubble prosedural) dan ending (2 panel + kredit).
#
# Data per halaman:  camera_dist, enter (turn | cut | fade | black), black_hold
# Data per panel:    image, rect, from, enter_sec, effects, sfx, hold, cam, grade,
#                    balloons[] (lihat ComicBalloon), sfx_text[] (draft), glows[]

const COMIC_DATA_PATH := "res://data/comic.json"
const BalloonScript := preload("res://scripts/comic/comic_balloon.gd")
const BALLOON_PX_PER_UNIT := 240.0
const TYPE_CHARS_PER_SEC := 38.0
const SKIP_HOLD_SEC := 3.0
const PANEL_ENTER_SEC := 0.35
const BALLOON_DELAY_SEC := 0.25

# Ukuran teks di layar (px pada 1080p) dan kecepatan ketik per gaya bubble.
const STYLE_SCREEN_PX := {"speech": 30.0, "hollow": 29.0, "cold": 30.0, "shout": 50.0, "shout_cry": 44.0, "sfx": 64.0}
const STYLE_TYPE_SPEED := {"speech": 36.0, "hollow": 22.0, "cold": 25.0, "shout": 70.0, "shout_cry": 48.0}
const SPEAKER_PITCH := {"kakak": 0.84, "adik": 1.16}
const GRADE_DEFAULT := {"tint": "#ffffff", "tint_amount": 0.0, "saturation": 1.0, "contrast": 1.0, "brightness": 1.0}

@export var comic_id: String = "opening"

var data: Dictionary = {}
var page_defs: Array = []
var pages: Array[Dictionary] = []
var panels: Array[Dictionary] = []
var current_step: int = -1
var current_page: int = -1
var busy: bool = false
var finished: bool = false
var typing_label: RichTextLabel = null
var typing_total: int = 0
var typing_progress: float = 0.0
var typing_speed: float = TYPE_CHARS_PER_SEC
var typing_pitch: float = 1.0
var blip_counter: int = 0
var balloons_playing: bool = false
var fast_forward: bool = false
var esc_hold: float = 0.0
var shot_mode: bool = false

# Kamera
var cam_rig: Node3D
var camera: Camera3D
var cam_tween: Tween
var cam_roll: float = 0.0
var trauma: float = 0.0
var tremble_node: Node3D = null
var time_acc: float = 0.0

# UI 2D
var ui: CanvasLayer
var flash_rect: ColorRect
var dark_rect: ColorRect
var fade_rect: ColorRect
var wipe_rect: TextureRect
var hint_label: Label
var skip_ring: Control
var outro_root: Control
var grade_mat: ShaderMaterial
var speed_mat: ShaderMaterial
var grade_tween: Tween

var paper_material: ShaderMaterial
var glow_shader: Shader
var dust: CPUParticles3D

func _ready() -> void:
	name = "Opening" if comic_id == "opening" else "Ending"
	data = _load_comic_data().get(comic_id, {})
	page_defs = data.get("pages", [])
	glow_shader = load("res://shaders/soft_glow.gdshader") as Shader
	_build_environment()
	_build_camera()
	_build_paper()
	_build_particles()
	_build_post()
	_build_ui()
	_build_pages()
	_start_audio()
	if _check_screenshot_mode():
		return
	if bool(data.get("start_black", false)):
		fade_rect.color.a = 1.0
	await get_tree().create_timer(float(data.get("start_delay", 0.5))).timeout
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
	if page_defs.size() > 0:
		first_dist = float(page_defs[0].get("camera_dist", 17.0))
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
	dust = CPUParticles3D.new()
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

func _build_post() -> void:
	# Layer 5: color grade layar penuh. Layer 6: speed lines (di atas grade, di bawah UI).
	var grade_layer := CanvasLayer.new()
	grade_layer.name = "Grade"
	grade_layer.layer = 5
	add_child(grade_layer)
	var gr := ColorRect.new()
	gr.set_anchors_preset(Control.PRESET_FULL_RECT)
	gr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_mat = ShaderMaterial.new()
	grade_mat.shader = load("res://shaders/comic_grade.gdshader") as Shader
	gr.material = grade_mat
	grade_layer.add_child(gr)

	var speed_layer := CanvasLayer.new()
	speed_layer.name = "SpeedLines"
	speed_layer.layer = 6
	add_child(speed_layer)
	var sr := ColorRect.new()
	sr.set_anchors_preset(Control.PRESET_FULL_RECT)
	sr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed_mat = ShaderMaterial.new()
	speed_mat.shader = load("res://shaders/speedlines.gdshader") as Shader
	speed_mat.set_shader_parameter("alpha", 0.0)
	sr.material = speed_mat
	speed_layer.add_child(sr)

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

	# Transisi antar halaman (fade/black) dan wipe penutup.
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fade_rect)

	var wg := Gradient.new()
	wg.set_color(0, Color(0, 0, 0, 0))
	wg.set_offset(1, 0.08)
	wg.set_color(1, Color(0, 0, 0, 1))
	var wt := GradientTexture2D.new()
	wt.gradient = wg
	wt.width = 1024
	wt.height = 4
	wipe_rect = TextureRect.new()
	wipe_rect.texture = wt
	wipe_rect.stretch_mode = TextureRect.STRETCH_SCALE
	wipe_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wipe_rect.position = Vector2(1940, 0)
	wipe_rect.size = Vector2(2200, 1080)
	ui.add_child(wipe_rect)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash_rect)

	hint_label = Label.new()
	hint_label.text = "Klik / Enter  lanjut" if comic_id == "ending" else "Klik / Enter  lanjut     Tahan Esc  lewati"
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
	for pi in range(page_defs.size()):
		var pdef: Dictionary = page_defs[pi]
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
			var p := _build_panel(pdef_panel, inner, page)
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

func _build_panel(def: Dictionary, parent: Node3D, page: Dictionary) -> Dictionary:
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
		"balloons": [],
		"sfx_texts": [],
		"spot_glows": []
	}
	# Ukuran font dihitung dari jarak kamera supaya teks selalu sama besar di layar.
	var cam: Dictionary = def.get("cam", {})
	var cam_dist := float(page["dist"]) * float(cam.get("dist", 0.97))
	var balloon_defs: Array = def.get("balloons", [])
	if def.has("balloon"):
		balloon_defs = [def["balloon"]] + balloon_defs
	for b in balloon_defs:
		p["balloons"].append(_build_balloon(p, b, anim, cam_dist))
	for s in def.get("sfx_text", []):
		var sd: Dictionary = (s as Dictionary).duplicate()
		sd["style"] = "sfx"
		p["sfx_texts"].append(_build_balloon(p, sd, anim, cam_dist))
	for g in def.get("glows", []):
		p["spot_glows"].append(_build_spot_glow(p, g, anim))
	return p

func _screen_px_per_unit(dist: float) -> float:
	return 1080.0 / (2.0 * dist * tan(deg_to_rad(camera.fov * 0.5)))

func _build_balloon(p: Dictionary, b: Dictionary, anim: Node3D, cam_dist: float) -> Dictionary:
	var style := String(b.get("style", "speech"))
	var screen_px := float(b.get("screen_px", STYLE_SCREEN_PX.get(style, 30.0)))
	var fpx := int(round(screen_px * BALLOON_PX_PER_UNIT / _screen_px_per_unit(cam_dist)))
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.disable_3d = true
	if RenderingServer.get_current_rendering_method() != "gl_compatibility":
		vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(vp)
	var node: ComicBalloon = BalloonScript.new()
	vp.add_child(node)
	var info: Dictionary = node.build(b, Vector2(p["w"], p["h"]), BALLOON_PX_PER_UNIT, fpx)
	vp.size = info["vp_size"]

	var spr := Sprite3D.new()
	spr.texture = vp.get_texture()
	spr.pixel_size = 1.0 / BALLOON_PX_PER_UNIT
	spr.shaded = false
	spr.transparent = true
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var cu: Vector2 = info["center_units"]
	spr.position = Vector3(cu.x, cu.y, 0.05)
	spr.rotation.z = deg_to_rad(float(b.get("rot", 0.0)))
	spr.render_priority = 3
	spr.modulate.a = 0.0
	anim.add_child(spr)
	return {"def": b, "vp": vp, "node": node, "label": node.label, "sprite": spr, "base_pos": spr.position, "base_rot": spr.rotation.z, "shown": false}

func _build_spot_glow(p: Dictionary, g: Dictionary, anim: Node3D) -> Dictionary:
	var uv: Array = g.get("uv", [0.5, 0.5])
	var sz: Array = g.get("size", [0.2, 0.1])
	var mesh := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(float(sz[0]) * p["w"], float(sz[1]) * p["h"])
	mesh.mesh = q
	var col := Color.html(String(g.get("color", "#ffb35a")))
	var base := float(g.get("intensity", 1.0))
	var m := _make_glow_material(Color(col, 0.0), 0.95, base, false)
	m.render_priority = 2
	mesh.material_override = m
	mesh.position = Vector3((float(uv[0]) - 0.5) * p["w"], -(float(uv[1]) - 0.5) * p["h"], 0.04)
	anim.add_child(mesh)
	return {"mat": m, "color": col, "base": base, "pulse": bool(g.get("pulse", true))}

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

func _sfx(sfx_name: String, pitch: float = 1.0, db: float = 0.0) -> void:
	if shot_mode:
		return
	var am := _audio()
	if am and am.has_method("play_sfx"):
		am.play_sfx(sfx_name, pitch, db)

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
			_finish(true)
	elif esc_hold > 0.0:
		esc_hold = 0.0
		skip_ring.visible = false

func _next() -> void:
	if finished:
		return
	# Klik saat bubble masih berjalan: tampilkan semua teks panel ini sekaligus.
	if typing_label != null or balloons_playing:
		fast_forward = true
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
	fast_forward = false
	var page_idx: int = p["page"]
	var page_enter := "turn"
	var new_page := page_idx != current_page
	if new_page:
		page_enter = String(page_defs[page_idx].get("enter", "turn"))
		if current_page >= 0:
			await _leave_page(current_page, page_idx, page_enter)
		current_page = page_idx
		_set_page_active(page_idx, true)
		if finished:
			return
	_stop_tremble()
	_set_speedlines(0.0, 0.25)

	var def: Dictionary = p["def"]
	var effects: Array = def.get("effects", [])
	var from := String(def.get("from", "left"))
	var enter_sec := float(def.get("enter_sec", PANEL_ENTER_SEC))
	var snap_cam := new_page and page_enter in ["cut", "fade", "black"]
	_camera_for_panel(p, snap_cam)
	_apply_grade(def.get("grade", GRADE_DEFAULT), 0.0 if snap_cam else 0.9)

	var anim: Node3D = p["anim"]
	var holder: Node3D = p["holder"]
	holder.visible = true
	_set_panel_alpha(0.0, p)

	if effects.has("silence"):
		_fade_ambience(-40.0, 1.2)

	if fade_rect.color.a > 0.01:
		var fade_dur: float = 0.0 if page_enter == "black" else maxf(enter_sec, 0.5)
		if fade_dur <= 0.0:
			fade_rect.color.a = 0.0
		else:
			create_tween().tween_property(fade_rect, "color:a", 0.0, fade_dur).set_trans(Tween.TRANS_SINE)

	var t := create_tween().set_parallel(true)
	match from:
		"impact":
			anim.position = Vector3(0, 0, 1.2)
			anim.scale = Vector3.ONE * 1.15
			anim.rotation = Vector3(0, 0, deg_to_rad(-2.5))
			t.tween_property(anim, "position", Vector3.ZERO, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			t.tween_property(anim, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
			t.tween_property(anim, "rotation", Vector3.ZERO, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_method(_set_panel_alpha.bind(p), 0.0, 1.0, 0.1)
		"fade":
			anim.position = Vector3.ZERO
			anim.rotation = Vector3.ZERO
			anim.scale = Vector3.ONE * 1.025
			t.tween_property(anim, "scale", Vector3.ONE, enter_sec * 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
			t.tween_method(_set_panel_alpha.bind(p), 0.0, 1.0, enter_sec)
		"hard_cut":
			anim.position = Vector3.ZERO
			anim.rotation = Vector3.ZERO
			anim.scale = Vector3.ONE
			_set_panel_alpha(1.0, p)
			t.tween_interval(0.01)
		"whip":
			anim.position = Vector3(-3.2, 0, 0)
			anim.rotation = Vector3.ZERO
			anim.scale = Vector3.ONE
			t.tween_property(anim, "position", Vector3.ZERO, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			t.tween_method(_set_panel_alpha.bind(p), 0.0, 1.0, 0.08)
			grade_mat.set_shader_parameter("blur_x", 70.0)
			t.tween_method(func(v: float) -> void: grade_mat.set_shader_parameter("blur_x", v), 70.0, 0.0, 0.32)
		"snap_right", "snap_left":
			var sx := 1.0 if from == "snap_right" else -1.0
			anim.position = Vector3(0.9 * sx, 0, 0.3)
			anim.rotation = Vector3.ZERO
			anim.scale = Vector3.ONE
			t.tween_property(anim, "position", Vector3.ZERO, 0.16).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			t.tween_method(_set_panel_alpha.bind(p), 0.0, 1.0, 0.1)
		_:
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
			t.tween_property(anim, "position", Vector3.ZERO, enter_sec).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(anim, "rotation", Vector3.ZERO, enter_sec + 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_method(_set_panel_alpha.bind(p), 0.0, 1.0, enter_sec * 0.8)
	if def.has("sfx") and from != "impact":
		_sfx(String(def["sfx"]))
	await t.finished
	if def.has("sfx") and from == "impact":
		_sfx(String(def["sfx"]))
	_apply_effects(p, effects)
	_start_spot_glows(p)
	_play_sfx_texts(p, step)
	busy = false

	await _play_balloons(p, step)

	if bool(data.get("auto_advance", false)):
		var hold := float(def.get("hold", 3.0))
		await get_tree().create_timer(hold).timeout
		while typing_label != null or balloons_playing:
			await get_tree().process_frame
		if current_step == step and not busy and not finished:
			_next()

# ---------------------------------------------------------------- halaman

func _set_page_active(page_idx: int, active: bool) -> void:
	var mode := SubViewport.UPDATE_ALWAYS if active else SubViewport.UPDATE_DISABLED
	for pid in pages[page_idx]["panel_ids"]:
		var p: Dictionary = panels[pid]
		for b in p["balloons"] + p["sfx_texts"]:
			(b["vp"] as SubViewport).render_target_update_mode = mode

func _hide_page(page_idx: int) -> void:
	var page: Dictionary = pages[page_idx]
	for pid in page["panel_ids"]:
		_set_panel_alpha(0.0, panels[pid])
	(page["root"] as Node3D).visible = false
	_set_page_active(page_idx, false)

func _leave_page(old_idx: int, new_idx: int, mode: String) -> void:
	match mode:
		"cut":
			_hide_page(old_idx)
		"fade":
			await create_tween().tween_property(fade_rect, "color:a", 1.0, 0.45).set_trans(Tween.TRANS_SINE).finished
			_hide_page(old_idx)
			await get_tree().create_timer(0.15).timeout
		"black":
			# Hitam total + hening sesaat sebelum ledakan.
			await create_tween().tween_property(fade_rect, "color:a", 1.0, 0.18).finished
			_hide_page(old_idx)
			_fade_ambience(-40.0, 0.3)
			await get_tree().create_timer(float(page_defs[new_idx].get("black_hold", 0.7))).timeout
		_:
			await _turn_page(old_idx, new_idx)

func _turn_page(page_idx: int, next_idx: int) -> void:
	# Halaman lama dibalik ke kiri seperti buku, lalu menghilang.
	var page: Dictionary = pages[page_idx]
	var root: Node3D = page["root"]
	_sfx("select")
	var t := create_tween().set_parallel(true)
	t.tween_property(root, "rotation:y", deg_to_rad(-100), 0.75).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for pid in page["panel_ids"]:
		t.tween_method(_set_panel_alpha.bind(panels[pid]), 1.0, 0.0, 0.6).set_delay(0.15)
	var next_page: Dictionary = pages[next_idx]
	_move_camera(next_page["center"], float(next_page["dist"]) + 1.5, 0.9)
	await t.finished
	root.visible = false
	_set_page_active(page_idx, false)

# ---------------------------------------------------------------- efek

func _apply_effects(p: Dictionary, effects: Array) -> void:
	var anim: Node3D = p["anim"]
	var step := current_step
	for e in effects:
		match String(e):
			"flash":
				flash_rect.color.a = 0.95
				create_tween().tween_property(flash_rect, "color:a", 0.0, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			"flash_soft":
				flash_rect.color.a = 0.45
				create_tween().tween_property(flash_rect, "color:a", 0.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			"shake_hard":
				trauma = 1.0
			"shake_soft":
				trauma = max(trauma, 0.5)
			"tremble":
				tremble_node = anim
			"heartbeat":
				_heartbeat_loop(step, 4, 0.9, 0.18, 1.0)
			"heartbeat_fast":
				_heartbeat_loop(step, 6, 0.5, 0.12, 1.25)
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
			"tick_soft":
				_tick_soft_loop(p["page"])
			"chromatic":
				_chromatic(9.0, 0.5)
			"chromatic_soft":
				_chromatic(4.0, 0.9)
			"speedlines":
				_set_speedlines(0.85, 0.12)
			"footsteps":
				_footsteps(step, 3, 0.4)
			"ambience_low":
				_fade_ambience(-26.0, 2.0)
			"ambience_back":
				_fade_ambience(-14.0, 2.5)
			"dust_slow":
				if dust:
					dust.speed_scale = 0.35

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
	for b in p["balloons"] + p["sfx_texts"]:
		(b["sprite"] as Sprite3D).modulate.a = a if b["shown"] else 0.0
	for g in p["spot_glows"]:
		(g["mat"] as ShaderMaterial).set_shader_parameter("tint", Color(g["color"], a))

func _kenburns(p: Dictionary) -> void:
	# Zoom pelan ke dalam panel.
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

func _start_spot_glows(p: Dictionary) -> void:
	# Cahaya kecil yang bergetar pelan (mis. cahaya dari celah pintu kamar Adik).
	for g in p["spot_glows"]:
		var m: ShaderMaterial = g["mat"]
		var base: float = g["base"]
		if not g["pulse"]:
			continue
		var t := create_tween().set_loops()
		t.bind_node(self)
		t.tween_method(func(v: float) -> void: m.set_shader_parameter("intensity", v), base, base * 0.55, 1.7).set_trans(Tween.TRANS_SINE)
		t.tween_method(func(v: float) -> void: m.set_shader_parameter("intensity", v), base * 0.55, base, 1.3).set_trans(Tween.TRANS_SINE)

func _heartbeat_loop(idx: int, beats: int, interval: float, strength: float, pitch: float) -> void:
	# Satu klip detak; layar berdenyut mengikuti ritmenya.
	_sfx("heartbeat", pitch)
	for i in range(beats):
		if current_step != idx or finished:
			return
		trauma = max(trauma, strength)
		await get_tree().create_timer(interval).timeout

func _tick_loop() -> void:
	for i in range(6):
		_sfx("tick")
		await get_tree().create_timer(1.0).timeout

func _tick_soft_loop(page_idx: int) -> void:
	# Detak jam samar selama satu halaman: firasat jam kalung.
	while current_page == page_idx and not finished and not shot_mode:
		_sfx("tick", 0.9, -10.0)
		await get_tree().create_timer(2.0).timeout

func _footsteps(idx: int, count: int, interval: float) -> void:
	for i in range(count):
		if current_step != idx or finished:
			return
		_sfx("footstep", 1.0, -float(i) * 3.0)
		await get_tree().create_timer(interval).timeout

func _chromatic(amount: float, dur: float) -> void:
	grade_mat.set_shader_parameter("chroma", amount)
	create_tween().tween_method(func(v: float) -> void: grade_mat.set_shader_parameter("chroma", v), amount, 0.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _set_speedlines(target: float, dur: float) -> void:
	var cur := float(speed_mat.get_shader_parameter("alpha"))
	if is_equal_approx(cur, target):
		return
	if dur <= 0.0:
		speed_mat.set_shader_parameter("alpha", target)
		return
	create_tween().tween_method(func(v: float) -> void: speed_mat.set_shader_parameter("alpha", v), cur, target, dur)

func _apply_grade(g: Dictionary, dur: float) -> void:
	if grade_tween and grade_tween.is_valid():
		grade_tween.kill()
	var target := GRADE_DEFAULT.duplicate()
	target.merge(g, true)
	var tint_to := Color.html(String(target["tint"]))
	if dur <= 0.0:
		grade_mat.set_shader_parameter("tint", tint_to)
		for k in ["tint_amount", "saturation", "contrast", "brightness"]:
			grade_mat.set_shader_parameter(k, float(target[k]))
		return
	grade_tween = create_tween().set_parallel(true)
	var tint_from: Color = grade_mat.get_shader_parameter("tint")
	grade_tween.tween_method(func(c: Color) -> void: grade_mat.set_shader_parameter("tint", c), tint_from, tint_to, dur)
	for k in ["tint_amount", "saturation", "contrast", "brightness"]:
		var key: String = k
		var from_v := float(grade_mat.get_shader_parameter(key))
		grade_tween.tween_method(func(v: float) -> void: grade_mat.set_shader_parameter(key, v), from_v, float(target[key]), dur).set_trans(Tween.TRANS_SINE)

func _stop_tremble() -> void:
	if tremble_node:
		tremble_node.position = Vector3.ZERO
	tremble_node = null

# ---------------------------------------------------------------- bubble

func _play_balloons(p: Dictionary, step: int) -> void:
	var list: Array = p["balloons"]
	if list.is_empty():
		return
	balloons_playing = true
	for b in list:
		if current_step != step or finished:
			break
		var delay := float(b["def"].get("delay", BALLOON_DELAY_SEC))
		if not fast_forward and delay > 0.0:
			await get_tree().create_timer(delay).timeout
		if current_step != step or finished:
			break
		_pop_balloon(b, not fast_forward)
		var label: RichTextLabel = b["label"]
		if fast_forward:
			label.visible_characters = -1
			continue
		var style := String(b["def"].get("style", "speech"))
		var speaker := String(b["def"].get("speaker", ""))
		_start_typing(label, float(STYLE_TYPE_SPEED.get(style, TYPE_CHARS_PER_SEC)), float(SPEAKER_PITCH.get(speaker, 1.0)), style.begins_with("shout"))
		while typing_label == label:
			await get_tree().process_frame
	# Pastikan semua bubble panel ini tampil (kalau dilewati dengan klik).
	if current_step == step:
		for b in list:
			if not b["shown"]:
				_pop_balloon(b, false)
			(b["label"] as RichTextLabel).visible_characters = -1
	balloons_playing = false

func _pop_balloon(b: Dictionary, animated: bool) -> void:
	b["shown"] = true
	var spr: Sprite3D = b["sprite"]
	var base_pos: Vector3 = b["base_pos"]
	var base_rot: float = b["base_rot"]
	var style := String(b["def"].get("style", "speech"))
	if not animated:
		spr.modulate.a = 1.0
		spr.scale = Vector3.ONE
		spr.position = base_pos
		spr.rotation.z = base_rot
		return
	var t := create_tween().set_parallel(true)
	match style:
		"shout", "shout_cry":
			spr.scale = Vector3.ONE * (1.7 if style == "shout" else 1.35)
			spr.modulate.a = 1.0
			t.tween_property(spr, "scale", Vector3.ONE, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			trauma = max(trauma, 0.45 if style == "shout" else 0.25)
			_sfx("impact", 1.15 if style == "shout" else 1.3, -4.0)
		"hollow":
			spr.scale = Vector3.ONE * 0.96
			t.tween_property(spr, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
			t.tween_property(spr, "scale", Vector3.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		"cold":
			spr.position = base_pos + Vector3(-0.18, 0, 0)
			t.tween_property(spr, "position", base_pos, 0.4).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			t.tween_property(spr, "modulate:a", 1.0, 0.35)
		"sfx":
			spr.scale = Vector3.ONE * 2.1
			spr.rotation.z = base_rot - deg_to_rad(10)
			t.tween_property(spr, "scale", Vector3.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(spr, "rotation:z", base_rot, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(spr, "modulate:a", 1.0, 0.08)
		_:
			spr.scale = Vector3.ONE * 0.55
			t.tween_property(spr, "scale", Vector3.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(spr, "modulate:a", 1.0, 0.14)

func _play_sfx_texts(p: Dictionary, step: int) -> void:
	# Tulisan efek suara (draft): muncul sendiri-sendiri, tidak menahan alur bubble.
	for s in p["sfx_texts"]:
		_show_sfx_text(s, step)

func _show_sfx_text(s: Dictionary, step: int) -> void:
	var def: Dictionary = s["def"]
	var delay := float(def.get("delay", 0.0))
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	if current_step != step or finished:
		return
	(s["label"] as RichTextLabel).visible_characters = -1
	_pop_balloon(s, true)
	if def.has("sound"):
		_sfx(String(def["sound"]), float(def.get("sound_pitch", 1.0)), float(def.get("sound_db", 0.0)))

# ---------------------------------------------------------------- kamera

func _move_camera(target: Vector3, dist: float, dur: float) -> void:
	if cam_tween and cam_tween.is_valid():
		cam_tween.kill()
	cam_tween = create_tween()
	cam_tween.tween_property(cam_rig, "position", Vector3(target.x, target.y, dist), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _panel_global_center(p: Dictionary) -> Vector3:
	var holder: Node3D = p["holder"]
	var page: Dictionary = pages[p["page"]]
	var root: Node3D = page["root"]
	var inner: Node3D = page["inner"]
	return root.position + inner.position + holder.position

func _panel_uv_world(p: Dictionary, uv: Array) -> Vector3:
	return _panel_global_center(p) + Vector3((float(uv[0]) - 0.5) * float(p["w"]), -(float(uv[1]) - 0.5) * float(p["h"]), 0)

# Titik awal & akhir kamera untuk satu panel.
# cam: focus (0..1 tarik ke panel), dist (kali jarak halaman), to [u,v], follow, zoom, roll (derajat), dur.
func _camera_plan(p: Dictionary) -> Dictionary:
	var page: Dictionary = pages[p["page"]]
	var cam: Dictionary = p["def"].get("cam", {})
	var pc: Vector3 = page["center"]
	var start_xy := pc.lerp(_panel_global_center(p), float(cam.get("focus", 0.18)))
	if cam.has("at"):
		start_xy = start_xy.lerp(_panel_uv_world(p, cam["at"]), float(cam.get("at_follow", 0.5)))
	var dist := float(page["dist"]) * float(cam.get("dist", 0.97))
	var start := Vector3(start_xy.x, start_xy.y, dist)
	var end := start
	if cam.has("to"):
		var w := _panel_uv_world(p, cam["to"])
		var f := float(cam.get("follow", 0.5))
		end.x = lerp(start.x, w.x, f)
		end.y = lerp(start.y, w.y, f)
	end.z = dist * float(cam.get("zoom", 1.0))
	return {"start": start, "end": end, "roll": deg_to_rad(float(cam.get("roll", 0.0))), "dur": float(cam.get("dur", 6.0))}

func _camera_for_panel(p: Dictionary, snap: bool) -> void:
	var plan := _camera_plan(p)
	if cam_tween and cam_tween.is_valid():
		cam_tween.kill()
	cam_tween = create_tween()
	if snap:
		cam_rig.position = plan["start"]
		cam_roll = 0.0
	else:
		cam_tween.tween_property(cam_rig, "position", plan["start"], 1.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cam_tween.parallel().tween_property(self, "cam_roll", 0.0, 1.0)
	var start: Vector3 = plan["start"]
	var end: Vector3 = plan["end"]
	if not start.is_equal_approx(end) or not is_zero_approx(float(plan["roll"])):
		cam_tween.tween_property(cam_rig, "position", end, plan["dur"]).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		cam_tween.parallel().tween_property(self, "cam_roll", plan["roll"], plan["dur"]).set_trans(Tween.TRANS_SINE)

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
	camera.rotation = rot + Vector3(0, 0, cam_roll + randf_range(-1, 1) * s * 0.03)
	if tremble_node:
		tremble_node.position = Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.025

# ---------------------------------------------------------------- teks

func _start_typing(label: RichTextLabel, speed: float = TYPE_CHARS_PER_SEC, pitch: float = 1.0, silent: bool = false) -> void:
	typing_label = label
	typing_total = label.get_total_character_count()
	typing_progress = 0.0
	typing_speed = speed
	typing_pitch = -1.0 if silent else pitch
	blip_counter = 0
	label.visible_characters = 0

func _update_typing(delta: float) -> void:
	if typing_label == null:
		return
	typing_progress += delta * typing_speed
	var n := int(typing_progress)
	if n != typing_label.visible_characters:
		typing_label.visible_characters = n
		blip_counter += 1
		if blip_counter % 3 == 0 and typing_pitch > 0.0:
			_sfx("text_blip", typing_pitch)
	if n >= typing_total:
		_finish_typing()

func _finish_typing() -> void:
	if typing_label:
		typing_label.visible_characters = -1
	typing_label = null

# ---------------------------------------------------------------- selesai

func _finish(skipped: bool = false) -> void:
	if finished:
		return
	finished = true
	_stop_tremble()
	_finish_typing()
	skip_ring.visible = false
	create_tween().tween_property(hint_label, "modulate:a", 0.0, 0.3)
	if data.has("outro"):
		await _play_outro(data["outro"])
		return
	var closing := String(data.get("closing", "fade"))
	if closing == "wipe" and not skipped:
		# Pintu depan tertutup: layar tersapu gelap dari kanan, lalu detak jam di kegelapan.
		_fade_ambience(-40.0, 1.6)
		var t := create_tween()
		t.tween_property(wipe_rect, "position:x", -260.0, 1.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await t.finished
		await get_tree().create_timer(0.8).timeout
		for i in range(int(data.get("closing_ticks", 3))):
			_sfx("tick", 0.8, -2.0)
			await get_tree().create_timer(1.0).timeout
		await get_tree().create_timer(0.4).timeout
	else:
		var t := create_tween()
		t.tween_property(fade_rect, "color:a", 1.0, 0.7)
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
	var at := "end"
	for arg in args:
		if String(arg).begins_with("--shot="):
			shot_name = String(arg).trim_prefix("--shot=")
		elif String(arg).begins_with("--step="):
			step = int(String(arg).trim_prefix("--step="))
		elif String(arg).begins_with("--cam="):
			at = String(arg).trim_prefix("--cam=")
	if shot_name == "" or not shot_name.contains(comic_id):
		return false
	shot_mode = true
	_shot(shot_name, step, at)
	return true

func _shot(shot_name: String, step: int, at: String) -> void:
	step = clamp(step, 0, panels.size())
	if step >= panels.size() and data.has("outro"):
		for p in panels:
			_show_panel_instant(p)
		current_step = panels.size() - 1
		_play_outro(data.get("outro", {}), true)
	else:
		step = mini(step, panels.size() - 1)
		var p: Dictionary = panels[step]
		for i in range(panels.size()):
			if i != step and panels[i]["page"] != p["page"]:
				(pages[panels[i]["page"]]["root"] as Node3D).visible = false
		for i in range(step + 1):
			var q: Dictionary = panels[i]
			if q["page"] == p["page"]:
				_show_panel_instant(q)
		current_step = step
		current_page = p["page"]
		_set_page_active(current_page, true)
		var plan := _camera_plan(p)
		cam_rig.position = plan["start"] if at == "start" else plan["end"]
		cam_roll = 0.0 if at == "start" else float(plan["roll"])
		var def: Dictionary = p["def"]
		_apply_grade(def.get("grade", GRADE_DEFAULT), 0.0)
		_apply_effects(p, def.get("effects", []))
		grade_mat.set_shader_parameter("chroma", 0.0)
		trauma = 0.0
		_stop_tremble()
	await get_tree().create_timer(1.6).timeout
	trauma = 0.0
	if not DirAccess.dir_exists_absolute("res://tests/screenshots"):
		DirAccess.make_dir_recursive_absolute("res://tests/screenshots")
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tests/screenshots/%s.png" % shot_name)
	print("Screenshot captured: res://tests/screenshots/%s.png" % shot_name)
	get_tree().quit(0)

func _show_panel_instant(p: Dictionary) -> void:
	(p["holder"] as Node3D).visible = true
	for b in p["balloons"] + p["sfx_texts"]:
		b["shown"] = true
		(b["label"] as RichTextLabel).visible_characters = -1
	_set_panel_alpha(1.0, p)
