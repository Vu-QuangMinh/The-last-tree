class_name EnemyRopes
extends RefCounted
## The ropes the Puppet Stage hangs its enemies on, placed by hand in the rope mode (F5 in a Room Test fight / elite / boss room, see RopeEditor).
## One list of rivets per enemy id; a rivet is a point on the enemy's picture, as a fraction of the picture's square (0..1, from the top left),
## so it stays on the same spot of the puppet however the puppet rocks or moves. Stored in data/enemy_ropes.json.

## (a test can point this somewhere else, so it never touches the real file)
static var file := "res://data/enemy_ropes.json"

static var _data := {}
static var _loaded := false


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	_data = {}
	if not FileAccess.file_exists(file):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(file))
	if parsed is Dictionary:
		for id in parsed:
			var pts: Array = []
			for p in parsed[id]:
				if p is Array and p.size() >= 2:
					pts.append(Vector2(float(p[0]), float(p[1])))
			if not pts.is_empty():
				_data[id] = pts


## The rivets of an enemy (a copy: change it and hand it back with set_points).
static func points(id: String) -> Array:
	_load()
	return _data.get(id, []).duplicate()


static func set_points(id: String, pts: Array) -> void:
	_load()
	if pts.is_empty():
		_data.erase(id)
	else:
		_data[id] = pts.duplicate()
	_save()


static func _save() -> void:
	var out := {}
	var ids: Array = _data.keys()
	ids.sort()
	for id in ids:
		out[id] = _data[id].map(func(p: Vector2): return [snappedf(p.x, 0.0001), snappedf(p.y, 0.0001)])
	if FileAccess.file_exists(file):  # (the file as it was a moment ago is kept beside it: a slip of the hand or of a tool must never lose the ropes)
		DirAccess.copy_absolute(ProjectSettings.globalize_path(file), ProjectSettings.globalize_path(file.get_basename() + ".bak.json"))
	var f := FileAccess.open(file, FileAccess.WRITE)
	if f == null:
		push_warning("EnemyRopes: could not write " + file)
		return
	f.store_string(JSON.stringify(out, "\t") + "\n")
