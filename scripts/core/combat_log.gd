class_name CombatLog
extends RefCounted
## Combat journal: one text file with every action, status and damage calculation of a fight (what the card says, what the
## maths made of it, what the screen showed), to compare the numbers on screen with the numbers dealt.
## Off unless `enable()` is called (main.gd, a real window only), so tests and tools never write it.
## File: user://combat_log.txt (the previous run's is kept as combat_log_prev.txt). Windows: %APPDATA%\Godot\app_userdata\Behind the Curtain\

const PATH := "user://combat_log.txt"
const PREV := "user://combat_log_prev.txt"

static var on := false
static var _f: FileAccess = null
static var _fights := 0


## `path` other than the default: a test writing its own file, so the player's last log is never overwritten.
static func enable(path := PATH) -> void:
	if on:
		return
	if path == PATH and FileAccess.file_exists(PATH):
		DirAccess.copy_absolute(PATH, PREV)
	_f = FileAccess.open(path, FileAccess.WRITE)
	on = _f != null
	if on:
		_f.store_line("Combat log, started %s. Format: ##### fight, === turn, > your action, ! enemy action, [CHECK] a number that differs from what was shown. [SCREEN] lines are written when the screen plays the events back, so they come after the fight's own maths of that whole step." % Time.get_datetime_string_from_system())
		_f.flush()


static func global_path() -> String:
	return ProjectSettings.globalize_path(PATH)


static func line(s: String) -> void:
	if not on:
		return
	_f.store_line(s)
	_f.flush()


static func fight_number() -> int:
	_fights += 1
	return _fights
