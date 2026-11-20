extends Node

const Tuning = preload("res://scripts/tuning.gd")

enum Tier {
	TENANG = 0,
	KESEL = 1,
	HAMPIR_MELEDAK = 2
}

signal stability_changed(new_value: int, delta: int)
signal tier_changed(new_tier: int)
signal loop_triggered()

var tuning: Tuning

var stability: int = 60
var pendam_count: int = 0
var current_room: String = "R1"
var current_event_id: String = ""
var photo_scraps: int = 0
var visited_bomb_events: Dictionary = {}

func _init() -> void:
	load_tuning()
	reset_state()

func load_tuning() -> void:
	if ResourceLoader.exists("res://data/tuning.tres"):
		tuning = load("res://data/tuning.tres") as Tuning
	if tuning == null:
		tuning = Tuning.new()

func reset_state() -> void:
	if tuning != null:
		stability = tuning.stability_initial
	else:
		stability = 60
	pendam_count = 0
	current_room = "R1"
	current_event_id = ""
	photo_scraps = 0
	visited_bomb_events.clear()

func get_tier() -> int:
	if tuning == null:
		return Tier.TENANG
	if stability >= tuning.tier_tenang_min:
		return Tier.TENANG
	elif stability >= tuning.tier_kesel_min:
		return Tier.KESEL
	else:
		return Tier.HAMPIR_MELEDAK

func apply_choice(type: String) -> Dictionary:
	var delta: int = 0
	var old_tier: int = get_tier()
	
	match type.to_lower():
		"jujur":
			delta = tuning.delta_jujur
			pendam_count = 0
		"pendam":
			delta = tuning.delta_pendam
			pendam_count += 1
		"sindir":
			delta = tuning.delta_sindir
		"ledak":
			delta = tuning.delta_ledak
		_:
			push_error("Unknown choice type: " + type)
			return {"loop": false, "stability": stability, "pendam": pendam_count}
			
	var new_stability: int = stability + delta
	
	if new_stability <= tuning.stability_min:
		# Trigger loop
		stability = tuning.stability_loop_reset
		loop_triggered.emit()
		stability_changed.emit(stability, delta)
		var new_tier: int = get_tier()
		if new_tier != old_tier:
			tier_changed.emit(new_tier)
		return {"loop": true, "stability": stability, "pendam": pendam_count}
	else:
		stability = clampi(new_stability, tuning.stability_min, tuning.stability_max)
		stability_changed.emit(stability, delta)
		var new_tier: int = get_tier()
		if new_tier != old_tier:
			tier_changed.emit(new_tier)
		return {"loop": false, "stability": stability, "pendam": pendam_count}

func enter_event(event_id: String) -> int:
	current_event_id = event_id.to_lower()
	var penalty: int = 0
	
	# Bom pendam hanya dihitung sekali per kejadian, hanya K2 dan K3
	if (current_event_id == "k2" or current_event_id == "k3") and not visited_bomb_events.get(current_event_id, false):
		visited_bomb_events[current_event_id] = true
		penalty = tuning.pendam_bomb_multiplier * pendam_count
		if penalty > 0:
			var old_tier: int = get_tier()
			var new_stability: int = stability - penalty
			if new_stability <= tuning.stability_min:
				stability = tuning.stability_loop_reset
				loop_triggered.emit()
			else:
				stability = clampi(new_stability, tuning.stability_min, tuning.stability_max)
			stability_changed.emit(stability, -penalty)
			var new_tier: int = get_tier()
			if new_tier != old_tier:
				tier_changed.emit(new_tier)
	return penalty

func on_timeout() -> Dictionary:
	# Kehabisan waktu dihitung sebagai Memendam
	return apply_choice("pendam")

func can_advance_k3(type: String) -> bool:
	return type.to_lower() == "jujur"

func add_photo_scrap() -> int:
	photo_scraps = mini(photo_scraps + 1, 3)
	return photo_scraps
