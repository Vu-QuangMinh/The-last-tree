extends RefCounted
## Writes {name: md5 of the file UiSkin resolves it to} for every art name, for the theme in ASSET_THEME, to ASSET_OUT (a json).
## Run before and after moving assets around: the two files must be equal (same names -> same pictures).


func _names(dir: String, out: Dictionary) -> void:
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".import") or f.ends_with(".uid"):
			continue
		var ext := f.get_extension().to_lower()
		if ext in ["png", "jpg"]:
			out[f.get_basename()] = true
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with("_") or d == "Source":
			continue
		_names(dir + "/" + d, out)


func run(t: SceneTree) -> void:
	await t.process_frame
	var theme := OS.get_environment("ASSET_THEME")
	var names := {}
	for root in OS.get_environment("ASSET_ROOTS").split(";"):
		_names(root, names)
	var save = t.root.get_node("SaveManager")
	save.use_test_file("user://asset_map_save.json")
	save.data.settings["theme"] = theme
	UiSkin._tex.clear()
	UiSkin._paths.clear()
	var out := {}
	for n in names.keys():
		var p: String = UiSkin.path_of(n)
		out[n] = (FileAccess.get_md5(p) + " " + p) if p != "" else ""
	var f := FileAccess.open(OS.get_environment("ASSET_OUT"), FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t", true))
	f.close()
	print("theme ", theme, ": ", names.size(), " names, ", out.values().filter(func(v): return v != "").size(), " resolved")
	t.quit()
