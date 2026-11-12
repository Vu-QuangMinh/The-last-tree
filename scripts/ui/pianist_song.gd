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
var _hand_notes := [[], []]  # the notes of the right hand (0) and of the left hand (1), by start: [start, pitch] (the 4th number of each note in the json is its hand)
var left_lo := 0  # the lowest and the highest pitch the left hand plays in this piece
var left_hi := 0
var right_lo := 1000  # the same for the right hand
var right_hi := 0


static func make(p_song: String) -> PianistSong:
	var s := PianistSong.new()
	s.song = p_song
	var all: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(NOTES_PATH))
	var d: Dictionary = all.get(p_song, all.get("turkish_march", {}))
	s.length = float(d.get("length", 1.0))
	s._notes = d.get("notes", [])
	s.left_lo = 1000
	for n in s._notes:
		var h: int = int(n[3]) if n.size() > 3 else 0
		s._hand_notes[h].append([float(n[0]), int(n[1])])
		if h == 1:
			s.left_lo = mini(s.left_lo, int(n[1]))
			s.left_hi = maxi(s.left_hi, int(n[1]))
		else:
			s.right_lo = mini(s.right_lo, int(n[1]))
			s.right_hi = maxi(s.right_hi, int(n[1]))
	return s


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE  # (the game's pause menu stops the music, and the clock with it)
	_player = AudioStreamPlayer.new()
	_player.stream = load("res://assets/Global/Music/Pianist/%s.wav" % song)
	var au := get_node_or_null("/root/Audio")  # (the Audio autoload; absent in a test script)
	if au != null:
		_player.bus = au.BUS_MUSIC  # (a sound effect ducks the piece too, like any music)
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


## --- the keyboard of the piano seen from behind (PianistBackRig): 36 white keys, C2 (MIDI 36) to C7 (96) ---
const KEY_LO := 36
const KEY_HI := 96
const WHITE_OF := [0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6]  # the white key a pitch class sits on (or just left of, for a sharp)
const IS_BLACK := [false, true, false, true, false, false, true, false, true, false, true, false]
const WHITE_KEYS := 36.0


## Where a pitch is on the keyboard, 0..1 from the left (the middle of its key: a sharp sits on the line between two white keys).
## A pitch outside the keyboard is folded by octaves into it (a few notes of Fur Elise).
static func key_x(pitch: int) -> float:
	var p := pitch
	while p < KEY_LO:
		p += 12
	while p > KEY_HI:
		p -= 12
	var pc := p % 12
	var w := float((floori((p - 12) / 12.0) - 2) * 7 + WHITE_OF[pc])  # (index of the white key, C2 = 0)
	return (w + (1.0 if IS_BLACK[pc] else 0.5)) / WHITE_KEYS


## What the hand and the foot are playing at time t: {hi, hi_t, lo, lo_t}: the highest and the lowest pitch sounding (the last ones struck
## when nothing sounds right now) and when each was struck. {} before the first note.
func voices_at(t: float) -> Dictionary:
	var h := hands_at(t)  # (also moves the cursor)
	if int(h[0]) < 0:
		return {}
	var hi_t := -1.0
	var lo_t := -1.0
	for i in range(_cursor, _notes.size()):
		var n: Array = _notes[i]
		var st := float(n[0])
		if st > t:
			break
		if int(n[1]) == int(h[0]) and st > hi_t:
			hi_t = st
		if int(n[1]) == int(h[1]) and st > lo_t:
			lo_t = st
	return {"hi": int(h[0]), "hi_t": hi_t, "lo": int(h[1]), "lo_t": lo_t}


## The last note a hand has struck by time t: {p: pitch, t: when it was struck, frame: for the left hand, which of the five leg pictures its pitch calls for}; {} before the first one.
## (Notes struck together: the highest is the last of them.) The leg picture is by where the pitch lies between the lowest and the highest note of the left hand in this piece:
## 0 = the lowest, 4 = the highest.
func first_at(hand: int) -> Dictionary:  # (the same as hand_at at the moment of that hand's first note: where it has to be before the piece starts)
	var ns: Array = _hand_notes[hand]
	if ns.is_empty():
		return {}
	return hand_at(hand, float(ns[0][0]))


func hand_at(hand: int, t: float) -> Dictionary:
	var ns: Array = _hand_notes[hand]
	var lo := 0
	var hi := ns.size() - 1
	var found := -1
	while lo <= hi:  # (binary search: the last note whose start is <= t)
		var mid := (lo + hi) / 2
		if float(ns[mid][0]) <= t:
			found = mid
			lo = mid + 1
		else:
			hi = mid - 1
	if found < 0:
		return {}
	var p: int = int(ns[found][1])
	var fr := 0
	var lt := 0.5  # (the left hand: where the pitch lies between its lowest and highest note, 0..1: the left foot's place along the keys)
	var nt := -1.0  # (when the next note of this hand starts, and where its foot place is: so the foot can already be over the next key)
	var nlt := 0.5
	if hand == 1 and left_hi > left_lo:
		lt = clampf(float(int(ns[found][1]) - left_lo) / float(left_hi - left_lo), 0.0, 1.0)
		if found + 1 < ns.size():
			nt = float(ns[found + 1][0])
			nlt = clampf(float(int(ns[found + 1][1]) - left_lo) / float(left_hi - left_lo), 0.0, 1.0)
	var rt := 0.0  # (the right hand: where the pitch lies between its lowest and its highest note, 0..1: for the 12 pictures of the figure)
	if hand == 1 and left_hi > left_lo:
		fr = clampi(int(float(p - left_lo) / float(left_hi - left_lo) * 5.0), 0, 4)
	elif hand == 0 and right_hi > right_lo:
		rt = clampf(float(p - right_lo) / float(right_hi - right_lo), 0.0, 1.0)
	return {"p": p, "t": float(ns[found][0]), "frame": fr, "rt": rt, "lt": lt, "next_t": nt, "next_lt": nlt}
