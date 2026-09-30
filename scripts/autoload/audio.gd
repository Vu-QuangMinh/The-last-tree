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


## The note each element sings when the chant is read (C, E, G: they always sound good together).
const NOTE_HZ := {"W": 523.25, "F": 659.25, "A": 783.99, "?": 1046.5}
var _notes := {}  # el -> generated AudioStreamWAV


## A soft plucked tone for an element (made in code, once), played like any other sound effect.
func play_note(el: String, volume_db := -4.0) -> void:
	if not _notes.has(el):
		_notes[el] = _pluck(NOTE_HZ.get(el, 440.0))
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = _notes[el]
	p.volume_db = _db(sfx_level) + volume_db
	p.pitch_scale = 1.0
	p.play()


## A bell-like pluck: a sine with a couple of quickly fading overtones and a soft decay.
static func _pluck(freq: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.55)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var env := exp(-t * 6.0) * minf(1.0, t * 300.0)
		var v := sin(TAU * freq * t) * 0.6 + sin(TAU * freq * 2.0 * t) * 0.25 * exp(-t * 9.0) + sin(TAU * freq * 3.0 * t) * 0.12 * exp(-t * 14.0)
		data.encode_s16(i * 2, int(clampf(v * env * 0.55, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func stop_music() -> void:
	_music_name = ""
	_music.stop()
	_music.stream = null
