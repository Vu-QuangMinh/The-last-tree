extends RefCounted


func _shot(t: SceneTree, out: String, name: String) -> void:
	await t.process_frame
	t.root.get_texture().get_image().save_png("%s/shopstage_%s.png" % [out, name])


func run(t: SceneTree) -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "C:/temp"
	t.create_timer(170.0).timeout.connect(t.quit)
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://shop_stage_save.json")
	save.data.settings["theme"] = "puppet"
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	for _i in 60:
		await t.create_timer(0.25).timeout
		if m._overlay != null:
			break
	m._overlay.chosen.emit(0)
	await t.create_timer(4.6).timeout
	m.run.amber = 300
	var col: int = m.run.choices()[0]
	m.run.map[m.run.row + 1][col].type = "shop"
	m._overlay.node_chosen.emit(col)  # (the real flow: the map is pulled up, the drapes open, then the room)
	await t.create_timer(3.2).timeout
	for i in 40:
		await t.create_timer(0.5).timeout
		await _shot(t, out, "%02d" % i)
	t.quit()
