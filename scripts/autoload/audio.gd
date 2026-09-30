extends Node
## Plays one-shot SFX (res://assets/sfx/<name>.wav) and looping music picked per category from
## res://assets/music/<category>/*.{wav,ogg,mp3}. Call Audio.play("sfx_name") from anywhere;
## missing files just warn once and stay silent.

const SFX_DIR := "res://assets/sfx/"
const MUSIC_DIR := "res://assets/music/"
const MUSIC_CATEGORIES := ["menu", "map", "fight", "boss"]
const POOL_SIZE := 12
## The Music slider only ever reaches this much of a track's own volume (headroom, since
## music files tend to be mixed hot); the slider itself still reads 0-100%.
const MUSIC_CEILING := 0.5

## 0..1 (linear, like a slider). Persisted in SaveManager's settings.
var sfx_level := 1.0
var music_level := 0.7
var overall_level := 1.0

## Emitted whenever the preview player starts or stops; carries the resource path now
## previewing, or "" when nothing is. Settings rows listen to keep their Play button in sync.
signal preview_changed(path: String)

var _cache := {}  # resource path -> AudioStream (or null if missing)
var _pool: Array = []  # AudioStreamPlayer, round-robin so overlapping sounds don't cut each other off
var _pool_i := 0
var _music: AudioStreamPlayer
var _music_category := ""
var _music_track := {}  # category -> chosen filename (with extension)
var _preview: AudioStreamPlayer
var _preview_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	sfx_level = SaveManager.setting("sfx_volume", 1.0)
	music_level = SaveManager.setting("music_volume", 0.7)
	overall_level = SaveManager.setting("overall_volume", 1.0)
	for cat in MUSIC_CATEGORIES:
		_music_track[cat] = SaveManager.setting("music_track_%s" % cat, "")
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	_music = AudioStreamPlayer.new()
	add_child(_music)
	_music.finished.connect(func(): if _music.stream: _music.play())
	_preview = AudioStreamPlayer.new()
	add_child(_preview)
	_preview.finished.connect(func():
		_preview_path = ""
		preview_changed.emit(""))


static func _db(level: float) -> float:
	return -80.0 if level <= 0.001 else linear_to_db(level)


## Music gain, 0..1: the slider's own value, the fixed headroom ceiling and the Overall slider.
func _music_gain() -> float:
	return music_level * MUSIC_CEILING * overall_level


func set_sfx_level(v: float) -> void:
	sfx_level = clampf(v, 0.0, 1.0)
	SaveManager.set_setting("sfx_volume", sfx_level)


func set_music_level(v: float) -> void:
	music_level = clampf(v, 0.0, 1.0)
	SaveManager.set_setting("music_volume", music_level)
	_music.volume_db = _db(_music_gain())
	if _preview_path != "":
		_preview.volume_db = _db(_music_gain())


func set_overall_level(v: float) -> void:
	overall_level = clampf(v, 0.0, 1.0)
	SaveManager.set_setting("overall_volume", overall_level)
	_music.volume_db = _db(_music_gain())
	if _preview_path != "":
		_preview.volume_db = _db(_music_gain())


func _load(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		push_warning("Audio: missing file %s" % path)
		_cache[path] = null
		return null
	var s: AudioStream = load(path)
	_cache[path] = s
	return s


## One-shot SFX. Safe to call for a name that has no file yet (it just stays silent).
func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s := _load(SFX_DIR + name + ".wav")
	if s == null:
		return
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = s
	p.volume_db = _db(sfx_level * overall_level) + volume_db
	p.pitch_scale = pitch
	p.play()


# ------------------------------------------------------------------ music

## Every track file (with extension) sitting in assets/music/<category>/, sorted by name.
func list_tracks(category: String) -> Array:
	var out := []
	var dir := DirAccess.open(MUSIC_DIR + category)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and not f.ends_with(".import") and (f.ends_with(".wav") or f.ends_with(".ogg") or f.ends_with(".mp3")):
			out.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	out.sort()
	return out


## The chosen track for a category: falls back to the first file found if nothing was
## picked yet, or the pick no longer exists on disk.
func get_track(category: String) -> String:
	var chosen: String = _music_track.get(category, "")
	var avail := list_tracks(category)
	if chosen in avail:
		return chosen
	return avail[0] if not avail.is_empty() else ""


## Picks which file plays for a category. Switches immediately if that category is playing now.
func set_track(category: String, filename: String) -> void:
	_music_track[category] = filename
	SaveManager.set_setting("music_track_%s" % category, filename)
	if _music_category == category:
		_music_category = ""  # force play_music to reload even though the category matches
		play_music(category)


## Loops the chosen track for this category, replacing whatever is playing. Calling it again
## for the category that's already playing does nothing (so screens can call it on every _ready()).
func play_music(category: String) -> void:
	var track := get_track(category)
	if track == "":
		return
	if _music_category == category and _music.playing:
		return
	var s := _load(MUSIC_DIR + category + "/" + track)
	if s == null:
		return
	_music_category = category
	_music.stream = s
	_music.volume_db = _db(_music_gain())
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
	_music_category = ""
	_music.stop()
	_music.stream = null


## For the Settings screen's "listen" buttons. Calling it again on the track already
## previewing stops it (a toggle); calling it on a different one switches straight to it.
func preview_track(category: String, filename: String) -> void:
	var path := MUSIC_DIR + category + "/" + filename
	if _preview_path == path and _preview.playing:
		stop_preview()
		return
	var s := _load(path)
	if s == null:
		return
	_preview.stop()
	_preview_path = path
	_preview.volume_db = _db(_music_gain())
	_preview.stream = s
	_preview.play()
	preview_changed.emit(path)


func stop_preview() -> void:
	if _preview_path == "":
		return
	_preview.stop()
	_preview_path = ""
	preview_changed.emit("")


func current_preview_path() -> String:
	return _preview_path
