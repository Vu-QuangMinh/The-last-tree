extends Node
## Plays one-shot SFX and looping music by name: res://assets/sfx/<name>.wav.
## Call Audio.play("sfx_name") from anywhere; missing files just warn once and stay silent.

const DIR := "res://assets/sfx/"
const POOL_SIZE := 12

## 0..1 (linear, like a slider). Persisted in SaveManager's settings.
var sfx_level := 1.0
var music_level := 1.0

var _cache := {}  # name -> AudioStream (or null if missing)
var _pool: Array = []  # AudioStreamPlayer, round-robin so overlapping sounds don't cut each other off
var _pool_i := 0
var _music: AudioStreamPlayer
var _music_name := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sfx_level = SaveManager.setting("sfx_volume", 1.0)
	music_level = SaveManager.setting("music_volume", 1.0)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.finished.connect(func(): if _music.stream: _music.play())


static func _db(level: float) -> float:
	return -80.0 if level <= 0.001 else linear_to_db(level)


func set_sfx_level(v: float) -> void:
	sfx_level = clampf(v, 0.0, 1.0)
	SaveManager.set_setting("sfx_volume", sfx_level)


func set_music_level(v: float) -> void:
	music_level = clampf(v, 0.0, 1.0)
	SaveManager.set_setting("music_volume", music_level)
	_music.volume_db = _db(music_level)


func _stream(name: String) -> AudioStream:
	if _cache.has(name):
		return _cache[name]
	var path := DIR + name + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("Audio: missing sound '%s' (%s)" % [name, path])
		_cache[name] = null
		return null
	var s: AudioStream = load(path)
	_cache[name] = s
	return s


## One-shot SFX. Safe to call for a name that has no file yet (it just stays silent).
func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s := _stream(name)
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = s
	p.volume_db = _db(sfx_level) + volume_db
	p.pitch_scale = pitch
	p.play()


## Loops a music track, replacing whatever is playing now. Calling it again with the same
## track that's already playing does nothing (so screens can call it freely on every _ready()).
func play_music(name: String) -> void:
	if _music_name == name and _music.playing:
		return
	var s := _stream(name)
	if s == null:
		return
	_music_name = name
	_music.stream = s
	_music.volume_db = _db(music_level)
	_music.play()


func stop_music() -> void:
	_music_name = ""
	_music.stop()
	_music.stream = null
