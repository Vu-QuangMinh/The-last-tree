extends SceneTree
## Loads every script under res://scripts so parse errors surface. Usage: -s tools/check_scripts.gd

func _walk(dir: String, out: Array) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		_walk(dir + "/" + d, out)


func _init() -> void:
	await process_frame
	var files := []
	_walk("res://scripts", files)
	var bad := 0
	for f in files:
		var s = load(f)
		if s == null or not s.can_instantiate():
			bad += 1
			print("BAD ", f)
	print("CHECK: %d scripts, %d failed" % [files.size(), bad])
	quit()
