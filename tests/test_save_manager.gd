extends TestCase
## SaveManager: old saves keep the Seedlings only, current saves round-trip.

const PATH := "user://test_save_manager.json"
const SCRIPT_PATH := "res://scripts/autoload/save_manager.gd"


func _write(d: Variant) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string(d if d is String else JSON.stringify(d))
	f.close()


func _load() -> Node:
	var s: Node = load(SCRIPT_PATH).new()
	s.path = PATH
	s.load_game()
	return s


func _cleanup() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func test_old_version_keeps_only_seedlings() -> void:
	_write({"version": 1, "seeds": 42, "spells": ["x"]})
	var s := _load()
	assert_eq(int(s.data.seedlings), 42, "version 1 'seeds' becomes seedlings")
	assert_true((s.data.spells as Array).is_empty(), "unlocks reset")
	s.free()
	_cleanup()


func test_version_2_also_resets_unlocks() -> void:
	_write({"version": 2, "seedlings": 7, "spells": ["fire_ball"]})
	var s := _load()
	assert_eq(int(s.data.seedlings), 7, "seedlings kept")
	assert_true((s.data.spells as Array).is_empty(), "spells reset")
	s.free()
	_cleanup()


func test_current_version_round_trips() -> void:
	var s: Node = load(SCRIPT_PATH).new()
	s.use_test_file(PATH)
	s.set_setting("theme", "hud2")
	s.data.seedlings = 99
	s.save_game()
	var t := _load()
	assert_eq(int(t.data.seedlings), 99, "seedlings survive")
	assert_eq(str(t.setting("theme", "")), "hud2", "settings survive")
	s.free()
	t.free()
	_cleanup()


func test_non_object_file_gives_defaults() -> void:
	_write("[1, 2, 3]")
	var s := _load()
	assert_eq(int(s.data.version), 3, "default data")
	assert_eq(int(s.data.seedlings), 0, "no seedlings")
	s.free()
	_cleanup()
