class_name RoomFX
extends Node2D

# Suasana 2.5D per ruangan (data/room_fx.json):
# - CanvasModulate (cahaya sekitar) + PointLight2D di lampu/jendela yang ada di gambar
# - Debu cahaya di depan layar dan pecahan lantai siluet di foreground
# - Kamera "bersandar" sedikit ke arah pemain; background dan foreground digeser
#   dengan rasio berbeda sehingga terasa ada kedalaman (parallax), kamera tetap
#   praktis diam sesuai GDD (maksimal beberapa piksel).

const FX_PATH := "res://data/room_fx.json"
const LEAN_MAX := Vector2(7.0, 3.0)
const BG_PARALLAX := 0.3
const FG_PARALLAX := -0.9
const ROOM_CENTER := Vector2(240, 135)

static var _cache: Dictionary = {}
static var _light_tex: Texture2D = null
static var _dot_tex: Texture2D = null

var room: Node2D
var cfg: Dictionary = {}
var lights: Array[Dictionary] = []
var foreground: Node2D
var shards: Array[Dictionary] = []
var lean := Vector2.ZERO
var t := 0.0
var bg_base_pos := ROOM_CENTER

static func load_config(room_id: String) -> Dictionary:
	if _cache.is_empty() and FileAccess.file_exists(FX_PATH):
		var parsed = JSON.parse_string(FileAccess.open(FX_PATH, FileAccess.READ).get_as_text())
		if parsed is Dictionary:
			_cache = parsed
	return _cache.get(room_id, {})

static func radial_texture(size: int, hard: float) -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_offset(0, 0.0)
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(hard, Color(1, 1, 1, 0.55))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = size
	tex.height = size
	return tex

static func light_texture() -> Texture2D:
	if _light_tex == null:
		_light_tex = radial_texture(256, 0.35)
	return _light_tex

static func dot_texture() -> Texture2D:
	if _dot_tex == null:
		_dot_tex = radial_texture(32, 0.4)
	return _dot_tex

func setup(room_node: Node2D, room_id: String) -> void:
	room = room_node
	name = "RoomFX"
	cfg = load_config(room_id)
	if cfg.is_empty():
		return
	var bg: Node2D = room.get_node_or_null("Background")
	if bg:
		bg_base_pos = bg.position
	_build_ambient()
	_build_lights()
	foreground = Node2D.new()
	foreground.name = "Foreground"
	foreground.z_index = 30
	room.add_child.call_deferred(foreground)
	_build_motes()
	_build_floor_fade()
	if bool(cfg.get("shards", false)):
		_build_shards()

func _col(a: Array, alpha: float = 1.0) -> Color:
	return Color(float(a[0]), float(a[1]), float(a[2]), float(a[3]) if a.size() > 3 else alpha)

func _build_ambient() -> void:
	var cm := CanvasModulate.new()
	cm.color = _col(cfg.get("ambient", [1, 1, 1]))
	add_child(cm)

func _build_lights() -> void:
	for l in cfg.get("lights", []):
		var pl := PointLight2D.new()
		pl.texture = light_texture()
		var p: Array = l["pos"]
		pl.position = Vector2(float(p[0]), float(p[1]))
		pl.color = _col(l.get("color", [1, 1, 1]))
		pl.energy = float(l.get("energy", 1.0))
		pl.texture_scale = float(l.get("radius", 100)) * 2.0 / 256.0
		pl.blend_mode = Light2D.BLEND_MODE_ADD
		add_child(pl)
		lights.append({"node": pl, "energy": pl.energy, "flicker": float(l.get("flicker", 0.0)), "seed": randf() * 10.0})

func _build_floor_fade() -> void:
	# Lantai di depan garis jalan diredupkan bertahap: mata fokus ke jalur karakter,
	# lantai perspektif yang lebar tidak lagi terasa kosong / "melayang".
	var strength := float(cfg.get("floor_fade", 0.0))
	if strength <= 0.0 or not cfg.has("walk_y"):
		return
	var top := float(cfg["walk_y"]) + 3.0
	var g := Gradient.new()
	g.set_color(0, Color(0.03, 0.02, 0.06, 0.0))
	g.set_color(1, Color(0.03, 0.02, 0.06, strength))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 64
	var spr := Sprite2D.new()
	spr.name = "FloorFade"
	spr.texture = gt
	spr.centered = false
	spr.position = Vector2(-30, top)
	spr.scale = Vector2(540.0 / 8.0, (290.0 - top) / 64.0)
	spr.z_index = 20
	var mat := CanvasItemMaterial.new()
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	spr.material = mat
	add_child(spr)

func _build_motes() -> void:
	var m: Dictionary = cfg.get("motes", {})
	if m.is_empty():
		return
	var frozen := bool(m.get("frozen", false))
	var p := CPUParticles2D.new()
	p.name = "Motes"
	p.texture = dot_texture()
	p.amount = int(m.get("amount", 16))
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(260, 150)
	p.position = ROOM_CENTER
	p.direction = Vector2(0.4, -1)
	p.spread = 60.0
	p.gravity = Vector2(0, -1.5 if not frozen else 0.0)
	p.initial_velocity_min = 1.0 if frozen else 3.0
	p.initial_velocity_max = 2.0 if frozen else 9.0
	p.scale_amount_min = 0.15
	p.scale_amount_max = 0.5
	p.color = _col(m.get("color", [1, 1, 1, 0.4]))
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1, 1, 1, 0))
	ramp.add_point(0.3, Color(1, 1, 1, 1))
	ramp.add_point(0.7, Color(1, 1, 1, 1))
	ramp.set_color(ramp.get_point_count() - 1, Color(1, 1, 1, 0))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	p.material = mat
	foreground.add_child(p)

func _build_shards() -> void:
	# Pecahan lantai siluet melayang di depan kamera (lapisan terdekat).
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(room.name)
	var spots := [
		Vector2(-6, 262), Vector2(38, 276), Vector2(150, 281), Vector2(330, 279),
		Vector2(446, 268), Vector2(492, 250), Vector2(-14, 18), Vector2(470, 8)
	]
	for i in range(spots.size()):
		var poly := Polygon2D.new()
		var size := rng.randf_range(10.0, 26.0) * (1.4 if i >= 6 else 1.0)
		var pts := PackedVector2Array()
		var n := rng.randi_range(4, 6)
		for k in range(n):
			var ang := TAU * float(k) / float(n) + rng.randf_range(-0.35, 0.35)
			var rad := size * rng.randf_range(0.45, 1.0)
			pts.append(Vector2(cos(ang) * rad * 1.6, sin(ang) * rad * 0.7))
		poly.polygon = pts
		poly.color = Color(0.06, 0.04, 0.1, 0.92)
		poly.position = spots[i]
		poly.rotation = rng.randf_range(-0.5, 0.5)
		var mat := CanvasItemMaterial.new()
		mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
		poly.material = mat
		# Garis tepi tipis menangkap cahaya dunia fantasi.
		var rim := Line2D.new()
		var rim_pts := pts.duplicate()
		rim_pts.append(pts[0])
		rim.points = rim_pts
		rim.width = 0.8
		rim.default_color = Color(0.55, 0.75, 1.0, 0.35)
		poly.add_child(rim)
		foreground.add_child(poly)
		shards.append({"node": poly, "base": spots[i], "phase": rng.randf() * TAU, "rot": poly.rotation})

func _process(delta: float) -> void:
	t += delta
	for l in lights:
		if l["flicker"] > 0.0:
			var pl: PointLight2D = l["node"]
			var s: float = l["seed"]
			var f := sin(t * 7.3 + s) * 0.5 + sin(t * 13.1 + s * 2.0) * 0.3 + sin(t * 2.1 + s) * 0.2
			pl.energy = l["energy"] * (1.0 + f * l["flicker"] * 2.0)
	_update_parallax(delta)
	for sh in shards:
		var node: Polygon2D = sh["node"]
		node.position = sh["base"] + Vector2(0, sin(t * 0.6 + sh["phase"]) * 2.0)
		node.rotation = sh["rot"] + sin(t * 0.4 + sh["phase"]) * 0.04

func _update_parallax(delta: float) -> void:
	var rm = get_node_or_null("/root/RoomManager")
	var target := Vector2.ZERO
	if rm and is_instance_valid(rm.current_player):
		var pp: Vector2 = rm.current_player.global_position
		target = Vector2(
			clamp((pp.x - ROOM_CENTER.x) / 240.0, -1.0, 1.0) * LEAN_MAX.x,
			clamp((pp.y - 190.0) / 120.0, -1.0, 1.0) * LEAN_MAX.y)
	lean = lean.lerp(target, 1.0 - exp(-delta * 2.5))
	var cam: Camera2D = room.get_node_or_null("Camera2D")
	if cam:
		cam.position = ROOM_CENTER + lean
	var bg: Node2D = room.get_node_or_null("Background")
	if bg:
		bg.position = bg_base_pos + lean * BG_PARALLAX
	if foreground:
		foreground.position = lean * FG_PARALLAX
