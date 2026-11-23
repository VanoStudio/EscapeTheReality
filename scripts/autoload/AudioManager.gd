extends Node

# AudioManager: Mengatur audio detak jam dinamis, ambience, musik, dan SFX

var bgm_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var clock_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var tick_timer: float = 0.0
var tick_interval: float = 1.0 # Tenang = 1.0s, Kesal = 0.6s, Hampir Meledak = 0.35s
var is_clock_active: bool = true
var sfx_cache: Dictionary = {}

func _get_game_state() -> Node:
	return get_node_or_null("/root/GameState")

func _get_room_manager() -> Node:
	return get_node_or_null("/root/RoomManager")

func _ready() -> void:
	_setup_players()
	var gs = _get_game_state()
	if gs:
		gs.tier_changed.connect(_on_tier_changed)
		gs.loop_triggered.connect(_on_loop_triggered)
	var rm = _get_room_manager()
	if rm:
		rm.room_changed.connect(_on_room_changed)
		_on_room_changed(rm.current_room_id)
	else:
		_on_room_changed("R1")

const AUDIO_EXTS := ["ogg", "mp3", "wav"]
const SFX_POOL_SIZE := 8
const MAX_VARIANTS := 8
# Volume (dB) dan variasi pitch per SFX supaya mix enak dan tidak monoton.
const SFX_MIX := {
	"footstep": {"db": -14.0, "pitch": 0.08},
	"jump": {"db": -10.0, "pitch": 0.06},
	"land": {"db": -9.0, "pitch": 0.06},
	"text_blip": {"db": -20.0, "pitch": 0.12},
	"select": {"db": -8.0, "pitch": 0.0},
	"tick": {"db": -12.0, "pitch": 0.0},
	"pickup": {"db": -6.0, "pitch": 0.0},
	"impact": {"db": -2.0, "pitch": 0.0},
	"door_slam": {"db": -3.0, "pitch": 0.0},
	"heartbeat": {"db": -2.0, "pitch": 0.0},
	"rewind": {"db": -6.0, "pitch": 0.0}
}
const BGM_DB := -12.0
const AMBIENCE_DB := {"night_room": -14.0, "fantasy_drone": -16.0}

var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_pool_idx: int = 0

func _setup_players() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGM"
	bgm_player.volume_db = BGM_DB
	add_child(bgm_player)
	
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "Ambience"
	ambience_player.volume_db = -14.0
	add_child(ambience_player)
	
	clock_player = AudioStreamPlayer.new()
	clock_player.name = "ClockTick"
	clock_player.volume_db = -12.0
	add_child(clock_player)
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFX"
	sfx_player.volume_db = -4.0
	add_child(sfx_player)
	# Pool supaya beberapa SFX bisa bunyi bersamaan (langkah + detak + blip).
	for i in range(SFX_POOL_SIZE):
		var pl := AudioStreamPlayer.new()
		pl.name = "SFX%d" % i
		add_child(pl)
		sfx_pool.append(pl)

func _find_audio(base: String) -> String:
	for ext in AUDIO_EXTS:
		var path := "%s.%s" % [base, ext]
		if ResourceLoader.exists(path):
			return path
	return ""

func get_sfx_stream(sfx_name: String) -> AudioStream:
	if sfx_cache.has(sfx_name):
		return sfx_cache[sfx_name]
	var st: AudioStream = null
	var single := _find_audio("res://assets/audio/sfx/%s" % sfx_name)
	if single != "":
		st = load(single) as AudioStream
	else:
		# Variasi: footstep_1.ogg, footstep_2.ogg, ... -> diacak tiap diputar.
		var rnd := AudioStreamRandomizer.new()
		rnd.random_pitch = 1.0
		for i in range(1, MAX_VARIANTS + 1):
			var vp := _find_audio("res://assets/audio/sfx/%s_%d" % [sfx_name, i])
			if vp == "":
				break
			rnd.add_stream(-1, load(vp) as AudioStream)
		if rnd.streams_count > 0:
			st = rnd
	if st:
		sfx_cache[sfx_name] = st
	return st

func _loop_stream(st: AudioStream) -> AudioStream:
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	elif st is AudioStreamMP3:
		(st as AudioStreamMP3).loop = true
	elif st is AudioStreamWAV:
		(st as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return st

func _crossfade(player: AudioStreamPlayer, st: AudioStream, target_db: float) -> void:
	if player.stream == st and player.playing:
		return
	if player.playing:
		var out := create_tween()
		out.tween_property(player, "volume_db", -40.0, 0.6)
		await out.finished
	player.stream = st
	player.volume_db = -40.0
	player.play()
	create_tween().tween_property(player, "volume_db", target_db, 1.2)

func play_ambience(track_name: String) -> void:
	var path := _find_audio("res://assets/audio/ambience/%s" % track_name)
	if path != "":
		var st := _loop_stream(load(path) as AudioStream)
		_crossfade(ambience_player, st, float(AMBIENCE_DB.get(track_name, -14.0)))

func play_bgm(track_name: String) -> void:
	var path := _find_audio("res://assets/audio/music/%s" % track_name)
	if path != "":
		var st := _loop_stream(load(path) as AudioStream)
		_crossfade(bgm_player, st, BGM_DB)

func play_music(track_name: String) -> void:
	play_bgm(track_name)

func stop_bgm() -> void:
	if bgm_player.playing:
		var t := create_tween()
		t.tween_property(bgm_player, "volume_db", -40.0, 0.8)
		await t.finished
		bgm_player.stop()
		bgm_player.stream = null

func _process(delta: float) -> void:
	if not is_clock_active:
		return
		
	# Detak jam berulang
	tick_timer += delta
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		play_tick()

func play_tick() -> void:
	var st = get_sfx_stream("tick")
	if st:
		clock_player.stream = st
		clock_player.play()
	else:
		_play_synthetic_beep(800.0, 0.03, clock_player)

func play_sfx(sfx_name: String) -> void:
	var st = get_sfx_stream(sfx_name)
	if st:
		var pl: AudioStreamPlayer = sfx_pool[sfx_pool_idx]
		sfx_pool_idx = (sfx_pool_idx + 1) % sfx_pool.size()
		var mix: Dictionary = SFX_MIX.get(sfx_name, {"db": -6.0, "pitch": 0.0})
		pl.stream = st
		pl.volume_db = float(mix["db"])
		var pv := float(mix["pitch"])
		pl.pitch_scale = 1.0 + randf_range(-pv, pv)
		pl.play()
	else:
		match sfx_name:
			"jump":
				_play_synthetic_beep(450.0, 0.08, sfx_player)
			"footstep":
				_play_synthetic_beep(120.0, 0.03, sfx_player)
			"land":
				_play_synthetic_beep(90.0, 0.06, sfx_player)
			"text_blip":
				_play_synthetic_beep(880.0, 0.02, sfx_player)
			"pickup":
				_play_synthetic_beep(900.0, 0.12, sfx_player)
			"select":
				_play_synthetic_beep(600.0, 0.05, sfx_player)
			"impact":
				_play_synthetic_beep(120.0, 0.25, sfx_player)
			"rewind":
				_play_synthetic_beep(300.0, 0.35, sfx_player)
			_:
				_play_synthetic_beep(500.0, 0.05, sfx_player)

func _play_synthetic_beep(frequency: float, duration: float, player: AudioStreamPlayer) -> void:
	var sample_rate = 22050
	var total_samples = int(sample_rate * duration)
	var data = PackedByteArray()
	data.resize(total_samples)
	
	for i in range(total_samples):
		var t = float(i) / float(sample_rate)
		var val = sin(t * frequency * TAU)
		# Decay envelope
		var env = 1.0 - (float(i) / float(total_samples))
		var byte_val = int(clamp((val * env * 0.5 + 0.5) * 255.0, 0.0, 255.0))
		data[i] = byte_val
		
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.data = data
	
	player.stream = wav
	player.play()

func _on_tier_changed(new_tier: int) -> void:
	match new_tier:
		0: # TENANG
			tick_interval = 1.0
			clock_player.pitch_scale = 1.0
		1: # KESEL
			tick_interval = 0.6
			clock_player.pitch_scale = 1.2
		2: # HAMPIR_MELEDAK
			tick_interval = 0.35
			clock_player.pitch_scale = 1.5

func _on_loop_triggered() -> void:
	# Berhenti saat time loop
	is_clock_active = false
	play_sfx("rewind")
	await get_tree().create_timer(1.5).timeout
	is_clock_active = true

func _on_room_changed(room_id: String) -> void:
	if room_id.begins_with("R"):
		# Rumah asli: suasana malam jangkrik & kipas, belum ada detak jam kalung
		is_clock_active = false
		ambience_player.pitch_scale = 1.0
		play_ambience("night_room")
		stop_bgm()
	else:
		# Dunia fantasi: detak jam saku kalung aktif, musik fantasi dan drone bergema
		is_clock_active = true
		ambience_player.pitch_scale = 0.8
		play_ambience("fantasy_drone")
		play_bgm("fantasy_piano")
