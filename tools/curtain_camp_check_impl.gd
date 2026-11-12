extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://curtain_camp_check.json")
	save.data.settings["theme"] = "newui2"
	save.data.settings["curtain_map"] = true
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(1.0).timeout
	var at := Vector2i(-1, -1)
	for f in m.run.map.size():
		for n in m.run.map[f]:
			if n.type == "rest" and at.x < 0:
				at = Vector2i(f, n.col)
	m._on_node(at.y, at.x)
	await t.create_timer(1.5).timeout
	var what: String = m.current.get_class() + " " + str(m.current.get_script().get_global_name() if m.current.get_script() else "")
	var overlay: String = str(m._overlay.get_script().get_global_name()) if is_instance_valid(m._overlay) and m._overlay.get_script() else "-"
	print("campfire tile at ", at, " opens: current=", what, " overlay=", overlay, " node type now=", m.run.map[at.x][at.y].type)
	t.quit()
