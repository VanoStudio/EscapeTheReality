extends Node

# AudioManager: Mengatur audio detak jam dinamis, ambience, musik, dan SFX

var bgm_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var clock_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var tick_timer: float = 0.0
var tick_interval: float = 1.0 # Tenang = 1.0s, Kesal = 0.6s, Hampir Meledak = 0.35s
var is_clock_active: bool = true

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

func _setup_players() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "BGM"
	bgm_player.volume_db = -10.0
	add_child(bgm_player)
	
	ambience_player = AudioStreamPlayer.new()
	ambience_player.name = "Ambience"
	ambience_player.volume_db = -12.0
	add_child(ambience_player)
	
	clock_player = AudioStreamPlayer.new()
	clock_player.name = "ClockTick"
	clock_player.volume_db = -6.0
	add_child(clock_player)
	
	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SFX"
	sfx_player.volume_db = -4.0
	add_child(sfx_player)

func _process(delta: float) -> void:
	if not is_clock_active:
		return
		
	# Detak jam berulang
	tick_timer += delta
	if tick_timer >= tick_interval:
		tick_timer = 0.0
		play_tick()

func play_tick() -> void:
	# Cek apakah ada file audio detak jam
	if ResourceLoader.exists("res://assets/audio/sfx/tick.wav"):
		clock_player.stream = load("res://assets/audio/sfx/tick.wav")
		clock_player.play()
	else:
		# Procedural tick
		_play_synthetic_beep(800.0, 0.03, clock_player)

func play_sfx(sfx_name: String) -> void:
	var path = "res://assets/audio/sfx/%s.wav" % sfx_name
	if ResourceLoader.exists(path):
		sfx_player.stream = load(path)
		sfx_player.play()
	else:
		match sfx_name:
			"jump":
				_play_synthetic_beep(450.0, 0.08, sfx_player)
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
	# Ganti ambience berdasarkan rumah asli vs fantasi
	if room_id.begins_with("R"):
		# Rumah asli: ambience tenang
		ambience_player.pitch_scale = 1.0
	else:
		# Dunia fantasi: ambience bernada rendah dan bergema
		ambience_player.pitch_scale = 0.8
