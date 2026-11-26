class_name WorldBubble
extends CanvasLayer

# Bubble bicara di atas kepala karakter yang TIDAK menghentikan permainan
# ("sambil jalan"). Digambar di layar (1080p) supaya teks selalu tajam dan cukup besar,
# tapi ekornya selalu menempel ke kepala karakter di dunia.

signal finished()

const BalloonScript := preload("res://scripts/comic/comic_balloon.gd")
const SCREEN_PX := {"speech": 30, "hollow": 30, "cold": 30, "shout": 46, "shout_cry": 42, "sfx": 54}
const TYPE_CPS := {"speech": 38.0, "hollow": 26.0, "cold": 28.0, "shout": 60.0, "shout_cry": 46.0}
const SPEAKER_PITCH := {"kakak": 0.86, "adik": 1.16, "bayangan": 0.72, "penjual": 0.95}
const MARGIN := 24.0

var anchor: Node2D
var world_offset := Vector2(0, -80)
var balloon: Control
var label: RichTextLabel
var style := "speech"
var speaker := "kakak"
var hold_sec := -1.0
var _typing := true
var _progress := 0.0
var _total := 0
var _blip := 0
var _closing := false
var _tip_local := Vector2.ZERO

## Tampilkan bubble di atas `who`. hold < 0 = otomatis dari panjang teks.
static func say(who: Node2D, text: String, bubble_style: String = "speech", who_speaker: String = "kakak", hold: float = -1.0, offset: Vector2 = Vector2(0, -80)) -> WorldBubble:
	var wb := WorldBubble.new()
	wb.anchor = who
	wb.style = bubble_style
	wb.speaker = who_speaker
	wb.hold_sec = hold
	wb.world_offset = offset
	var host: Node = who.get_tree().current_scene if who.get_tree().current_scene else who
	host.add_child(wb)
	wb._build(text)
	return wb

func _build(text: String) -> void:
	layer = 15
	var fpx: int = SCREEN_PX.get(style, 30)
	balloon = BalloonScript.new()
	balloon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(balloon)
	# Bubble disusun di "panel" maya 2000x1000 px; ekor diarahkan ke bawah.
	var def := {
		"text": text,
		"style": style,
		"uv": [0.3, 0.2, 0.4, 0.2],
		"tail": [0.47, 0.95],
		"max_w": 0.3
	}
	balloon.build(def, Vector2(2000, 1000), 1.0, fpx)
	label = balloon.label
	_tip_local = balloon.tail_tip if balloon.tail_tip != Vector2.INF else Vector2(balloon.size.x * 0.5, balloon.size.y)
	_total = label.get_total_character_count()
	balloon.pivot_offset = _tip_local
	balloon.scale = Vector2(0.5, 0.5)
	balloon.modulate.a = 0.0
	var t := create_tween().set_parallel(true)
	if style.begins_with("shout"):
		balloon.scale = Vector2(1.5, 1.5)
		t.tween_property(balloon, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(balloon, "modulate:a", 1.0, 0.06)
	else:
		t.tween_property(balloon, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(balloon, "modulate:a", 1.0, 0.12)
	_place()

func _place() -> void:
	if not is_instance_valid(anchor) or balloon == null:
		return
	var screen := anchor.get_viewport().get_canvas_transform() * (anchor.global_position + world_offset)
	var pos := screen - _tip_local
	var vs := Vector2(1920, 1080)
	pos.x = clampf(pos.x, MARGIN, vs.x - balloon.size.x - MARGIN)
	pos.y = clampf(pos.y, MARGIN, vs.y - balloon.size.y - MARGIN)
	balloon.position = pos

func _process(delta: float) -> void:
	if not is_instance_valid(anchor):
		_close()
		return
	_place()
	if _typing:
		_progress += delta * float(TYPE_CPS.get(style, 38.0))
		var n := int(_progress)
		if n != label.visible_characters:
			label.visible_characters = n
			_blip += 1
			if _blip % 3 == 0 and not style.begins_with("shout"):
				var am = get_node_or_null("/root/AudioManager")
				if am and am.has_method("play_sfx"):
					am.play_sfx("text_blip", float(SPEAKER_PITCH.get(speaker, 1.0)))
		if n >= _total:
			_typing = false
			label.visible_characters = -1
			var hold := hold_sec if hold_sec >= 0.0 else clampf(1.4 + _total * 0.045, 1.8, 4.5)
			get_tree().create_timer(hold).timeout.connect(_close)

## Selesaikan ketikan sekarang (mis. pemain menekan tombol).
func skip_typing() -> void:
	if _typing:
		_progress = float(_total)

func _close() -> void:
	if _closing:
		return
	_closing = true
	if balloon:
		var t := create_tween()
		t.tween_property(balloon, "modulate:a", 0.0, 0.25)
		await t.finished
	finished.emit()
	queue_free()
