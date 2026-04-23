extends Node

const SOUND_DIR = "res://data/extracted_sounds/"

var _weapon_player: AudioStreamPlayer   # kanał broni - restartuje przy każdym strzale
var _impact_player: AudioStreamPlayer   # kanał trafień/eksplozji - niezależny
var _cache: Dictionary = {}      # sound_id -> AudioStream or null
var _path_map: Dictionary = {}   # sound_id -> file path

func _ready():
	_weapon_player = AudioStreamPlayer.new()
	add_child(_weapon_player)
	_impact_player = AudioStreamPlayer.new()
	add_child(_impact_player)
	_scan_sounds()

func _scan_sounds():
	var dir = DirAccess.open(SOUND_DIR)
	if not dir:
		push_error("SoundManager: nie można otworzyć ", SOUND_DIR)
		return
	dir.list_dir_begin()
	var name = dir.get_next()
	while name != "":
		if name.ends_with(".wav"):
			var id = name.left(3).to_int()
			if id > 0:
				_path_map[id] = SOUND_DIR + name
		name = dir.get_next()
	dir.list_dir_end()

func play_weapon_sound(sound_id: int) -> void:
	_play_on(_weapon_player, sound_id)

func play_sound(sound_id: int) -> void:
	_play_on(_impact_player, sound_id)

func _play_on(player: AudioStreamPlayer, sound_id: int) -> void:
	if sound_id <= 0:
		return
	if not _cache.has(sound_id):
		_cache[sound_id] = _load_stream(sound_id)
	var stream = _cache[sound_id]
	if stream == null:
		return
	player.stream = stream
	player.play()

func _load_stream(sound_id: int) -> AudioStream:
	var path = _path_map.get(sound_id, "")
	if path == "":
		push_warning("SoundManager: brak pliku dla sound_id=", sound_id)
		return null
	return load(path) as AudioStream
