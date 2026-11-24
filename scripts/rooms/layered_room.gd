class_name LayeredRoom
extends BaseRoom
## Ruangan 2.5D generik (opsi A): 4 lapisan parallax dari assets/processed/rooms/<id>_layers/.
## Lapisan: 01_back, 02_mid, 03_floor, 04_fore (.png). Faktor parallax 0.2/0.5/1.0/1.2.
## Urutan z: back < mid < floor (Kirana di sini) < fore.
## Fallback: kalau ada PNG yang hilang -> Background 1 lapis (bg_<id>.png) dari BaseRoom, tanpa error.
## Skrip ruangan lain cukup `extends LayeredRoom` dan tetap memanggil super._ready().

const LAYER_FILES := ["01_back.png", "02_mid.png", "03_floor.png", "04_fore.png"]
const LAYER_ALT_FILES := ["", "", "03_floor_stairs.png", ""]
const LAYER_FACTORS := [0.2, 0.5, 1.0, 1.2]
const ROOM_SIZE := Vector2(480, 270)
const VIEW_SIZE := Vector2(1920.0, 1080.0)
const CAM_FOLLOW := 4.0
## Skala Kirana standar = 0.35 pada zoom 4 (tinggi layar 1.4). Zoom lain dikompensasi otomatis.
const KIRANA_BASE_SCALE := 0.35

## Zoom kamera. 5 = 1080p / 5 = 216 tinggi pandang, sehingga kamera bisa scroll & parallax terlihat.
@export var cam_zoom: float = 5.0
@export var layers_enabled: bool = true

var _kirana: Node2D
var _view_half := Vector2.ZERO
var _layers: Array[Parallax2D] = []
var layers_active: bool = false

func _ready() -> void:
	super._ready()
	_kirana = get_node_or_null("Kirana") as Node2D
	_apply_kirana_scale()
	if layers_enabled:
		_build_layers()
	_build_extras()
	_snap_camera()
	if layers_active:
		_align_layers.call_deferred()

## Hook untuk turunan (cahaya, debu, dsb.).
func _build_extras() -> void:
	pass

func _layers_dir() -> String:
	return "res://assets/processed/rooms/%s_layers/" % room_id.to_lower()

func _apply_kirana_scale() -> void:
	if _kirana == null:
		return
	var spr := _kirana.get_node_or_null("AnimatedSprite2D") as CanvasItem
	if spr:
		var s: float = KIRANA_BASE_SCALE * 4.0 / cam_zoom
		spr.scale = Vector2(s, s)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

# --- kamera ----------------------------------------------------------------

func _setup_camera() -> void:
	super._setup_camera()
	camera.zoom = Vector2(cam_zoom, cam_zoom)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(ROOM_SIZE.x)
	camera.limit_bottom = int(ROOM_SIZE.y)
	camera.position_smoothing_enabled = false
	_view_half = VIEW_SIZE / cam_zoom * 0.5

func _setup_background() -> void:
	super._setup_background()
	if background_sprite:
		background_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _camera_target() -> Vector2:
	var p := ROOM_SIZE * 0.5
	if _kirana:
		p = _kirana.global_position
	return Vector2(
		clampf(p.x, _view_half.x, ROOM_SIZE.x - _view_half.x),
		clampf(p.y, _view_half.y, ROOM_SIZE.y - _view_half.y))

func _snap_camera() -> void:
	if camera:
		camera.position = _camera_target()

func _process(delta: float) -> void:
	if camera == null:
		return
	camera.position = camera.position.lerp(_camera_target(), 1.0 - exp(-CAM_FOLLOW * delta))

# --- lapisan ---------------------------------------------------------------

func _find_layer_textures() -> Array[Texture2D]:
	var out: Array[Texture2D] = []
	var dir := _layers_dir()
	for i in LAYER_FILES.size():
		var tex: Texture2D = null
		var names: Array[String] = [LAYER_FILES[i]]
		if LAYER_ALT_FILES[i] != "":
			names.append(LAYER_ALT_FILES[i])
		for n in names:
			var path: String = dir + n
			if ResourceLoader.exists(path):
				tex = load(path) as Texture2D
				if tex:
					break
		if tex == null:
			return [] as Array[Texture2D]
		out.append(tex)
	return out

func _build_layers() -> void:
	var texs := _find_layer_textures()
	if texs.size() != LAYER_FACTORS.size():
		return  # fallback: Background 1 lapis tetap tampil
	if background_sprite:
		background_sprite.visible = false
	layers_active = true
	for i in LAYER_FACTORS.size():
		var p := Parallax2D.new()
		p.name = "ParallaxLayer%d" % i
		p.scroll_scale = Vector2(LAYER_FACTORS[i], 1.0)
		p.z_index = -10 + i if i < 3 else 5  # lapis depan di atas Kirana
		add_child(p)
		_layers.append(p)
		var s := Sprite2D.new()
		s.name = "Art"
		s.texture = texs[i]
		var k := ROOM_SIZE.y / float(texs[i].get_height())
		s.scale = Vector2(k, k)
		s.position = ROOM_SIZE * 0.5
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		p.add_child(s)
	# urutan anak: layer 0 paling belakang
	for i in range(_layers.size() - 1, -1, -1):
		move_child(_layers[i], 0)

func _align_layers() -> void:
	# Parallax2D menggeser anak relatif ke posisi kamera; kompensasi supaya
	# tampilan awal = penempatan natural.
	await get_tree().process_frame
	await get_tree().process_frame
	for p in _layers:
		if p.get_child_count() == 0:
			continue
		var art := p.get_child(0) as Node2D
		var natural := ROOM_SIZE * 0.5
		art.position += natural - art.global_position
