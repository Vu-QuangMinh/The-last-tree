extends Node
## Plays one-shot SFX (<theme>/SFX/<name>.wav, else Global/SFX/<name>.wav, under res://assets/) and looping music picked per category from
## res://assets/Global/Music/<category>/*.{wav,ogg,mp3}. Call Audio.play("sfx_name") from anywhere;
## missing files just warn once and stay silent.

const GLOBAL_SFX_DIR := "res://assets/Global/SFX/"
const MUSIC_DIR := "res://assets/Global/Music/"
## Every place that has music: [id, label, group, where it plays, fallback]. A slot is the folder assets/Global/Music/<id>/; a slot with no track there plays its fallback's
## (the older folders fight / boss / map / menu are the fallbacks, so the game is never silent). Settings > Music Edit lists them by group.
const MUSIC_SLOTS := [
	["menu", "Main menu", "Menus", "The title screen.", ""],
	["map", "Map", "Menus", "The map between rooms.", ""],
	["fight_1", "Fight, Act 1", "Fights", "An ordinary fight in Act 1.", "fight"],
	["elite_1", "Mini boss, Act 1", "Fights", "An elite fight (a mini boss) in Act 1.", "fight_1"],
	["boss_1", "Boss, Act 1", "Fights", "A boss fight in Act 1.", "boss"],
	["fight_2", "Fight, Act 2", "Fights", "An ordinary fight in Act 2.", "fight"],
	["elite_2", "Mini boss, Act 2", "Fights", "An elite fight (a mini boss) in Act 2.", "fight_2"],
	["boss_2", "Boss, Act 2", "Fights", "A boss fight in Act 2.", "boss"],
	["fight_3", "Fight, Act 3", "Fights", "An ordinary fight in Act 3.", "fight"],
	["elite_3", "Mini boss, Act 3", "Fights", "An elite fight (a mini boss) in Act 3.", "fight_3"],
	["boss_3", "Boss, Act 3", "Fights", "A boss fight in Act 3.", "boss"],
	["ev_default", "Event: a fork in the path", "Events", "The ordinary \"?\" events: Lost Sprite, A Note to Yourself, The Mystery Shed, The Recycler.", ""],
	["ev_spooky", "Event: whispers", "Events", "Eerie events: The Whispering Well, A Cursed Shrine, The Mushroom Ring, The Wax Witch, The Mausoleum.", ""],
	["ev_comic", "Event: cheeky sideshow", "Events", "Comic events: A Travelling Bard, The Flying Turtle, Something Is Falling, The Farmer's Farm, They See Me Rolling, The Bear Comes Back, The Hollow Stump.", ""],
	["ev_rest", "Event: rest", "Events", "Quiet events: An Abandoned Camp, Climate Change.", ""],
	["ev_danger", "Event: danger", "Events", "Tense events: Far from Any Road, The Overgrown Vine, The Ruined Watchtower, The Broken Bridge.", ""],
	["ev_water", "Event: Fisher's Fish", "Events", "Fisher's Fish, under the water (Act 2).", ""],
	["ev_stones", "Event: Skipping Stones", "Events", "Skipping Stones (Act 2).", ""],
	["ev_church", "Event: Church of Aole", "Events", "The Church of Aole.", ""],
	["fight", "Fight (older, any act)", "Older folders", "Used by a fight slot that has no track of its own.", ""],
	["boss", "Boss (older, any act)", "Older folders", "Used by a boss slot that has no track of its own.", ""],
]
## Which event plays which slot (events not listed here play no music of their own: the map's goes on).
const EVENT_MUSIC := {
	"lost_sprite": "ev_default", "note_to_self": "ev_default", "mystery_shack": "ev_default", "recycler": "ev_default",
	"well": "ev_spooky", "cursed_shrine": "ev_spooky", "mushroom_ring": "ev_spooky", "wax_witch": "ev_spooky", "mausoleum": "ev_spooky",
	"bard": "ev_comic", "flying_turtle": "ev_comic", "turtle_falls": "ev_comic", "farmer_farm": "ev_comic", "rolling_bear": "ev_comic", "bear_revenge": "ev_comic", "hollow_stump": "ev_comic",
	"lost_camp": "ev_rest", "shrinking_pond": "ev_rest",
	"cactus_maze": "ev_danger", "overgrown_vine": "ev_danger", "watchtower": "ev_danger", "broken_bridge": "ev_danger",
	"elemental_fishing": "ev_water", "skipping_stones": "ev_stones", "church_of_aole": "ev_church",
}
var MUSIC_CATEGORIES: Array = MUSIC_SLOTS.map(func(r): return r[0])
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
## Sounds of the same name that are still playing (name -> [end time in ms, ...]): a volley (Elemental Fury's six hits) must not pile up into a wall of noise.
var _active := {}
const STACK_STEP_DB := 2.5  # each copy of the same sound already playing makes the next one this much quieter
const STACK_MAX_DB := 10.0  # ... down to this much
const STACK_MAX := 5  # the sixth copy of one sound at once is not played at all
var _music: AudioStreamPlayer
var _music_category := ""
var music_theme := "suno_nov03"  # the theme whose tracks the slots play (Music Edit's Theme)
var _fade_token := 0  # a new music (or a stop) cancels a fade-out in progress
var _after_token := 0  # ... and a music waiting for a sound to end
var _last_track := {}  # slot -> the track it played last (the next random pick avoids it)
var _preview: AudioStreamPlayer
var _preview_path := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# A tool or test script (godot -s tools/x.gd / --script) must never be heard: the user is working while it runs.
	var args := OS.get_cmdline_args()
	if "-s" in args or "--script" in args:
		AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)
	sfx_level = SaveManager.setting("sfx_volume", 1.0)
	music_level = SaveManager.setting("music_volume", 0.7)
	overall_level = SaveManager.setting("overall_volume", 1.0)
	music_theme = String(SaveManager.setting("music_edit_theme", music_theme))
	_add_master_limiter()
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
		_music.stream_paused = false
		preview_changed.emit(""))


## A limiter on the Master bus (once): whatever piles up, nothing goes over the ceiling, so many sounds at once never get too loud.
func _add_master_limiter() -> void:
	var bus := AudioServer.get_bus_index("Master")
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i) is AudioEffectLimiter:
			return
	var lim := AudioEffectLimiter.new()
	lim.ceiling_db = -1.5
	lim.threshold_db = -4.0
	lim.soft_clip_db = 2.0
	AudioServer.add_bus_effect(bus, lim)


## How many dB quieter this copy of `name` must be because copies of it are still playing (-1000 = too many: do not play it). Records it when it plays.
func _stack_gain(p_name: String, length: float) -> float:
	var now := Time.get_ticks_msec()
	var live: Array = (_active.get(p_name, []) as Array).filter(func(t): return t > now)
	if live.size() >= STACK_MAX:
		_active[p_name] = live
		return -1000.0
	live.append(now + int(length * 1000.0))
	_active[p_name] = live
	return -minf(STACK_MAX_DB, STACK_STEP_DB * (live.size() - 1))


static func _db(level: float) -> float:
	return -80.0 if level <= 0.001 else linear_to_db(level)


## Music gain, 0..1: the slider's own value, the fixed headroom ceiling and the Overall slider.
## A listen in Music Edit does not follow the music slider (at 0% you could not pick anything): the game's loudness only.
func _preview_gain() -> float:
	return MUSIC_CEILING * overall_level


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
		_preview.volume_db = _db(_preview_gain())


func set_overall_level(v: float) -> void:
	overall_level = clampf(v, 0.0, 1.0)
	SaveManager.set_setting("overall_volume", overall_level)
	_music.volume_db = _db(_music_gain())
	if _preview_path != "":
		_preview.volume_db = _db(_preview_gain())


var _sfx_index := {}  # SFX folder -> {sound name: path}, for the sounds that sit in sub-folders (Spell Card SFX, Debuff SFX, ...)


## Where the sound `name` is: right in `dir`, else in one of the sub-folders of `dir` (the sounds are sorted into folders by kind; the name alone finds them).
func _sfx_path(dir: String, p_name: String) -> String:
	var flat := dir + p_name + ".wav"
	if ResourceLoader.exists(flat):
		return flat
	if not _sfx_index.has(dir):
		var found := {}
		_scan_sfx(dir, found)
		_sfx_index[dir] = found
	return (_sfx_index[dir] as Dictionary).get(p_name, flat)


func _scan_sfx(dir: String, found: Dictionary) -> void:
	for sub in DirAccess.get_directories_at(dir):
		if sub.begins_with("_"):
			continue  # (_Candidates and the like: not for the game)
		var path := dir + sub + "/"
		for f in DirAccess.get_files_at(path):
			var file := f.trim_suffix(".import").trim_suffix(".remap")  # (an exported game lists the imported files like that)
			if file.ends_with(".wav") and not found.has(file.trim_suffix(".wav")):
				found[file.trim_suffix(".wav")] = path + file
		_scan_sfx(path, found)


func _load(path: String, quiet := false) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	if not ResourceLoader.exists(path):
		if not quiet:
			push_warning("Audio: missing file %s" % path)
		_cache[path] = null
		return null
	var s: AudioStream = load(path)
	_cache[path] = s
	return s


## Load a sound into the cache ahead of time, so its first play does not hitch.
func warm(p_name: String) -> void:
	if _load(_sfx_path(UiSkin.theme_dir() + "SFX/", p_name), true) == null:
		_load(_sfx_path(GLOBAL_SFX_DIR, p_name))


var _voice: AudioStreamPlayer
var _voice_run := 0  # a new line (or a stop) cancels the one being said
var _voice_active := false


## True while a spoken line is still being said (between its clips too).
func voice_busy() -> bool:
	return _voice_active


## A spoken line: the clips (res:// paths that exist) one after the other, with a short breath between them. A new call or stop_voice() cuts the old one off.
func play_voice(paths: Array) -> void:
	stop_voice()
	var clips: Array = paths.filter(func(p): return String(p) != "" and ResourceLoader.exists(String(p)))
	if clips.is_empty():
		return
	if _voice == null:
		_voice = AudioStreamPlayer.new()
		add_child(_voice)
	_voice_run += 1
	var mine := _voice_run
	_voice_active = true
	for p in clips:
		_voice.stream = load(String(p))
		_voice.volume_db = _db(sfx_level * overall_level)
		_voice.play()
		await _voice.finished
		if mine != _voice_run:
			return
		await get_tree().create_timer(0.15).timeout
		if mine != _voice_run:
			return
	_voice_active = false


func stop_voice() -> void:
	_voice_run += 1
	_voice_active = false
	if _voice != null:
		_voice.stop()


## Is there a sound called `name` (in the theme's SFX or the global ones, in any sub-folder)?
func has_sfx(p_name: String) -> bool:
	if _silenced.has(p_name):
		return false
	return _override.has(p_name) or ResourceLoader.exists(_sfx_path(UiSkin.theme_dir() + "SFX/", p_name)) or ResourceLoader.exists(_sfx_path(GLOBAL_SFX_DIR, p_name))


var _override := {}  # sound name -> a stream that plays instead of the file (the SFX Test screen installs a new sample while the game runs)


var _silenced := {}  # sound names that have no sound now, whatever file is still imported (the SFX Test screen chose the game's older sound instead)


func set_override(p_name: String, stream: AudioStream) -> void:
	_override[p_name] = stream
	_silenced.erase(p_name)


func silence(p_name: String) -> void:
	_override.erase(p_name)
	_silenced[p_name] = true


## A .wav (16 bit PCM) read straight from the disk, outside the imported resources (null when it cannot be read).
func wav_from_file(path: String) -> AudioStreamWAV:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var b := f.get_buffer(f.get_length())
	var rate := 44100
	var channels := 1
	var data := PackedByteArray()
	var pos := 12
	while pos + 8 <= b.size():
		var id := b.slice(pos, pos + 4).get_string_from_ascii()
		var size := b.decode_u32(pos + 4)
		if id == "fmt ":
			channels = b.decode_u16(pos + 10)
			rate = b.decode_u32(pos + 12)
		elif id == "data":
			data = b.slice(pos + 8, mini(b.size(), pos + 8 + size))
			break
		pos += 8 + size + (size & 1)
	if data.is_empty():
		return null
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = channels == 2
	w.data = data
	return w


## Sounds that are somebody speaking (or a tune that goes with an event): stop_all_voices() cuts every one of them, whoever started it.
const VOICE_NAMES := ["merchant_greeting", "getout", "recycler_reuse", "recycler_trade", "witch_blood", "well_whisper", "sprite_help_me", "sfx_cactus_whisper", "merry puppets"]


static func is_voice(p_name: String) -> bool:
	return p_name.begins_with("evv_") or p_name.begins_with("mv_") or p_name.begins_with("hm_") or p_name in VOICE_NAMES


## Cut every voice at once: the boss's recorded lines, the events' and the merchant's lines, the greetings. Called when the screen changes.
func stop_all_voices() -> void:
	stop_voice()
	for c in get_children():
		if c is AudioStreamPlayer and c.has_meta("voice"):
			c.stop()
			c.queue_free()


## One-shot SFX. Safe to call for a name that has no file yet (it just stays silent).
## from: start this many seconds into the sound (to skip the silence some recordings begin with).
func play(p_name: String, volume_db := 0.0, pitch := 1.0, from := 0.0, stackable := true) -> void:  # (stackable false: a volley of the same sound, every shot is heard at full level)
	if _silenced.has(p_name):
		return
	if is_voice(p_name):
		play_held(p_name, volume_db, pitch)  # (a voice has a player of its own, so it can be cut)
		return
	var s: AudioStream = _override.get(p_name, null)
	if s == null:
		s = _load(_sfx_path(UiSkin.theme_dir() + "SFX/", p_name), true)  # (the theme's own sound, if it has one)
	if s == null:
		s = _load(_sfx_path(GLOBAL_SFX_DIR, p_name))
	if s == null:
		return
	var stack := _stack_gain(p_name, maxf(0.0, s.get_length() - from) / maxf(0.1, pitch)) if stackable else 0.0
	if stack < -100.0:
		return
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = s
	p.volume_db = _db(sfx_level * overall_level) + volume_db + stack
	p.pitch_scale = pitch
	p.play(from)


## A sound the caller can stop again (see stop_held): it has a player of its own, freed when it ends or is stopped. Returns null when there is no such file.
func play_held(p_name: String, volume_db := 0.0, pitch := 1.0) -> AudioStreamPlayer:
	var s := _load(_sfx_path(UiSkin.theme_dir() + "SFX/", p_name), true)
	if s == null:
		s = _load(_sfx_path(GLOBAL_SFX_DIR, p_name))
	if s == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = _db(sfx_level * overall_level) + volume_db
	p.pitch_scale = pitch
	if is_voice(p_name):
		p.set_meta("voice", true)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## How long a sound file lasts, seconds (0 when there is no such file).
func get_sfx_length(p_name: String) -> float:
	var s := _load(_sfx_path(UiSkin.theme_dir() + "SFX/", p_name), true)
	if s == null:
		s = _load(_sfx_path(GLOBAL_SFX_DIR, p_name))
	return s.get_length() if s != null else 0.0


## Fade a sound from play_held out in `fade` seconds and free it (null / already freed is fine).
func stop_held(p, fade := 0.25) -> void:  # (untyped: a sound that already ended has been freed, and a freed object cannot be passed as a typed argument)
	if p == null or not is_instance_valid(p):
		return
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -60.0, fade)
	tw.tween_callback(p.queue_free)


# ------------------------------------------------------------------ music

## Every track file (with extension) sitting in assets/Global/Music/<category>/, sorted by name.
## An exported game (e.g. the web build) only keeps "<track>.mp3.import" stubs, so those count as the track too.
func list_tracks(category: String) -> Array:
	var out := []
	for f in DirAccess.get_files_at(MUSIC_DIR + category):
		f = f.trim_suffix(".import")
		if (f.ends_with(".wav") or f.ends_with(".ogg") or f.ends_with(".mp3")) and not f in out:
			out.append(f)
	out.sort()
	return out


## Music Edit's themes: [id, label]. A track belongs to a theme by the start of its file name; everything else is "old".
const MUSIC_THEMES := [["suno_nov03", "Suno Nov 03"], ["anysong_nov02", "AnySong Nov 02"], ["old", "Old"]]


static func track_theme(filename: String) -> String:
	if filename.begins_with("Suno Nov 03 "):
		return "suno_nov03"
	if filename.begins_with("AnySong - ") or filename.begins_with("Nov 02 "):
		return "anysong_nov02"
	return "old"


## The tracks of list_tracks(category) that belong to a theme.
func list_tracks_in_theme(category: String, theme: String) -> Array:
	return list_tracks(category).filter(func(f): return track_theme(f) == theme)


## The slot whose tracks really play for `category`: itself, or the first of its fallbacks that has a track ("" when the whole chain is empty).
func resolve_category(category: String) -> String:
	var c := category
	for _i in 4:  # (first a slot with a track of the current theme, then any track)
		if not list_tracks_in_theme(c, music_theme).is_empty():
			return c
		var next := ""
		for r in MUSIC_SLOTS:
			if r[0] == c:
				next = String(r[4])
		if next == "":
			break
		c = next
	c = category
	for _i in 4:
		if not list_tracks(c).is_empty():
			return c
		var next := ""
		for r in MUSIC_SLOTS:
			if r[0] == c:
				next = String(r[4])
		if next == "":
			return ""
		c = next
	return ""


## The slot of a fight: by the act (1 to 3) and the kind ("fight", "elite" or "boss").
func fight_slot(kind: String, act: int) -> String:
	return "%s_%d" % [kind, clampi(act, 1, 3)]


## The slot an event plays ("" when it has none).
func event_slot(event_id: String) -> String:
	return String(EVENT_MUSIC.get(event_id, ""))


## The tracks a slot draws from: the ones of the current theme, or (none of them) every track there.
func playable_tracks(category: String) -> Array:
	var t := list_tracks_in_theme(category, music_theme)
	return t if not t.is_empty() else list_tracks(category)


## The track this slot is pinned to in the current theme ("" = no pin: every time it starts it plays a random track of the theme).
func get_pin(category: String) -> String:
	var pin := String(SaveManager.setting("music_pick_%s_%s" % [music_theme, category], ""))
	return pin if pin in list_tracks_in_theme(category, music_theme) else ""


## The track that plays for a category: its pin, else the one it played last, else the first one.
func get_track(category: String) -> String:
	var avail := playable_tracks(category)
	var pin := get_pin(category)
	if pin != "":
		return pin
	var last: String = _last_track.get(category, "")
	if last in avail:
		return last
	return avail[0] if not avail.is_empty() else ""


## Deletes a track file from the game for good (and its .import). Whatever played it stops; the slot goes on with another track (or its fallback).
func delete_track(category: String, filename: String) -> bool:
	var path := MUSIC_DIR + category + "/" + filename
	if _preview_path == path:
		stop_preview()
	var was_playing := _music_category != "" and _music.playing and resolve_category(_music_category) == category and get_track(category) == filename
	var ok := true
	for p in [path, path + ".import"]:
		if FileAccess.file_exists(p):
			ok = DirAccess.remove_absolute(ProjectSettings.globalize_path(p)) == OK and ok
	_cache.erase(path)
	if get_pin(category) == filename:
		SaveManager.set_setting("music_pick_%s_%s" % [track_theme(filename), category], "")
	if _last_track.get(category, "") == filename:
		_last_track.erase(category)
	if was_playing:
		var cat := _music_category
		_music_category = ""
		_music.stop()
		play_music(cat)
	return ok


## Pins a slot to one track (of the current theme); "" gives it back to random. Switches immediately if that slot is playing now.
func set_track(category: String, filename: String) -> void:
	SaveManager.set_setting("music_pick_%s_%s" % [music_theme, category], filename)
	_restart_if_playing(category)


func _restart_if_playing(category: String) -> void:
	if _music_category != "" and resolve_category(_music_category) == category:
		var cat := _music_category
		_music_category = ""  # force play_music to reload even though the category matches
		play_music(cat)


## Switches to a theme: every slot now plays tracks of it (a pinned one, else a random one each time it starts); what plays now changes at once.
func set_theme(theme: String) -> void:
	music_theme = theme
	SaveManager.set_setting("music_edit_theme", theme)
	if _music_category != "":
		var cat := _music_category
		_music_category = ""
		play_music(cat)


## Loops a track for this category, replacing whatever is playing: the slot's pin, else a random track of the theme (not the one it played last, when it has others).
## Calling it again for the category that's already playing does nothing (so screens can call it on every _ready()).
func play_music(category: String) -> void:
	if _music_category == category and _music.playing:
		return
	_fade_token += 1
	_after_token += 1
	var real := resolve_category(category)  # (an empty slot plays its fallback's track)
	if real == "":
		return
	var pool := playable_tracks(real)
	var track := get_pin(real)
	if track == "":
		var choices := pool.filter(func(f): return f != _last_track.get(real, ""))
		if choices.is_empty():
			choices = pool
		if choices.is_empty():
			return
		track = choices[randi() % choices.size()]
	var s := _load(MUSIC_DIR + real + "/" + track)
	if s == null:
		return
	_last_track[real] = track
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
var _gunshot: AudioStreamWAV


## A gunshot (made in code, once): a sharp crack of noise, a deep thump under it, and a short rattling tail.
func play_gunshot(volume_db := -2.0) -> void:
	if _gunshot == null:
		_gunshot = _make_gunshot()
	var p: AudioStreamPlayer = _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = _gunshot
	p.volume_db = _db(sfx_level) + volume_db
	p.pitch_scale = randf_range(0.95, 1.05)
	p.play()


static func _make_gunshot() -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate * 0.45)
	var data := PackedByteArray()
	data.resize(n * 2)
	var g := RandomNumberGenerator.new()
	g.seed = 7
	var lp := 0.0  # a simple low-pass on the noise, for the tail
	for i in n:
		var t := float(i) / rate
		var noise := g.randf_range(-1.0, 1.0)
		lp += (noise - lp) * 0.18
		var crack := noise * exp(-t * 60.0)  # the sharp crack
		var tail := lp * exp(-t * 9.0) * 0.6  # the rattle as it dies away
		var thump := sin(TAU * (90.0 - 50.0 * t) * t) * exp(-t * 14.0) * 0.9  # the deep body of the shot
		var v := (crack * 0.9 + tail + thump) * minf(1.0, t * 2000.0)
		data.encode_s16(i * 2, int(clampf(v * 0.75, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


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


## The music fades out in `seconds` and stops (a new music or a stop in the meantime cancels the stop).
func fade_out_music(seconds := 0.8) -> void:
	if not _music.playing:
		return
	_fade_token += 1
	var mine := _fade_token
	var tw := create_tween()
	tw.tween_property(_music, "volume_db", -60.0, seconds)
	tw.tween_callback(func():
		if mine == _fade_token:
			_music_category = ""
			_music.stop()
			_music.stream = null)


## Starts a music after `delay` seconds, unless another music (or a stop) came first.
func play_music_after(category: String, delay: float) -> void:
	_after_token += 1
	var mine := _after_token
	await get_tree().create_timer(delay, true).timeout
	if mine == _after_token:
		play_music(category)


## The end of a fight: the music fades away, `sfx` plays, and when it is over `then_music` starts ("" = none).
func result_sting(sfx: String, then_music := "map") -> void:
	fade_out_music()
	play(sfx)
	if then_music != "":
		play_music_after(then_music, get_sfx_length(sfx))


func stop_music() -> void:
	_fade_token += 1
	_after_token += 1
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
	_preview.volume_db = _db(_preview_gain())
	_preview.stream = s
	_music.stream_paused = true  # (the background music waits while a track is listened to)
	_preview.play()
	preview_changed.emit(path)


func stop_preview() -> void:
	if _preview_path == "":
		return
	_preview.stop()
	_preview_path = ""
	_music.stream_paused = false
	preview_changed.emit("")


func current_preview_path() -> String:
	return _preview_path


## Seconds into the track being previewed, and its length (0 when nothing plays).
func preview_position() -> float:
	return _preview.get_playback_position() if _preview_path != "" and _preview.playing else 0.0


func preview_length() -> float:
	return _preview.stream.get_length() if _preview_path != "" and _preview.stream != null else 0.0


## Jump the preview to `seconds`; a track that is not playing (the one picked) starts from there.
func seek_preview(seconds: float) -> void:
	if _preview_path != "" and _preview.playing:
		_preview.seek(seconds)
