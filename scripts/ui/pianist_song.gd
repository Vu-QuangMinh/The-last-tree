class_name PianistSong
extends Node
## The Pianist's piece, in real time: it starts when the fight does and plays through every turn and animation. When
## it ends, `ended` fires (he slams the keys: The End). The notes (data/pianist_notes.json, from the same MIDI as the
## audio: tools/render_pianist.py) tell his hand and foot where to be: the hand on the highest note sounding, the foot
## on the lowest.

signal ended

const NOTES_PATH := "res://data/pianist_notes.json"
const LOW := 33  # the lowest and highest pitch of his keyboard (MIDI numbers): the hand's range
const HIGH := 96

var song := "turkish_march"
var length := 1.0
var _notes: Array = []  # [start, pitch, duration], by start
var _player: AudioStreamPlayer
var _started := false
var _done := false
var _cursor := 0  # (the first note that may still be sounding: the search starts there)


static func make(p_song: String) -> PianistSong:
	var s := PianistSong.new()
	s.song = p_song
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NOTES_PATH))
	var d: Dictionary = all.get(p_song, all.get("turkish_march", {}))
	s.length = float(d.get("length", 1.0))
	s._notes = d.get("notes", [])
	return s


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE  # (the game's pause menu stops the music, and the clock with it)
	_player = AudioStreamPlayer.new()
	_player.stream = load("res://assets/Global/Music/Pianist/%s.wav" % song)
	var au := get_node_or_null("/root/Audio")  # (the Audio autoload; absent in a test script)
	if au != null:
		_player.volume_db = linear_to_db(maxf(0.0001, au._music_gain()))
	add_child(_player)
	_player.finished.connect(_on_finished)


func play() -> void:
	if _started:
		return
	_started = true
	_player.play()


func playing() -> bool:
	return _started and not _done and not _player.stream_paused


## He stops to turn the page (the clock stops too), and plays on from there.
func pause() -> void:
	if _started and not _done:
		_player.stream_paused = true


func resume() -> void:
	if _started and not _done:
		_player.stream_paused = false


## Seconds into the piece (the audio's own clock: hit-stops and slow motion don't bend it).
func time() -> float:
	if not _started:
		return 0.0
	if _done:
		return length
	if _player.stream_paused:
		return _player.get_playback_position()
	return _player.get_playback_position() + AudioServer.get_time_since_last_mix()


func left() -> float:
	return maxf(0.0, length - time())


## [highest pitch sounding, lowest pitch sounding] at time t (the last ones struck when nothing sounds right now);
## [-1, -1] before the first note.
func hands_at(t: float) -> Array:
	while _cursor < _notes.size() and float(_notes[_cursor][0]) + float(_notes[_cursor][2]) < t - 2.0:
		_cursor += 1
	var hi := -1
	var lo := -1
	var last_hi := -1
	var last_lo := -1
	var last_start := -1.0
	for i in range(_cursor, _notes.size()):
		var n: Array = _notes[i]
		var st := float(n[0])
		if st > t:
			break
		var p := int(n[1])
		if st + float(n[2]) >= t:
			hi = maxi(hi, p)
			lo = p if lo < 0 else mini(lo, p)
		if st >= last_start:
			if st > last_start:
				last_hi = p
				last_lo = p
			else:
				last_hi = maxi(last_hi, p)
				last_lo = mini(last_lo, p)
			last_start = st
	return [hi if hi >= 0 else last_hi, lo if lo >= 0 else last_lo]


func _on_finished() -> void:
	if _done:
		return
	_done = true
	ended.emit()
