extends RefCounted


func _map(m) -> MapScreen:
	return m._overlay if is_instance_valid(m._overlay) and m._overlay is MapScreen else null


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "C:/temp"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://curtain_map_save.json")
	save.data.settings["theme"] = "puppet"
	save.data.settings["curtain_map"] = true
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	await t.create_timer(1.0).timeout
	m.show_map()  # (no keepsake: straight to the map)
	var guard := 0
	while _map(m) == null and guard < 600:
		await t.process_frame
		guard += 1
	await t.create_timer(4.5).timeout
	t.root.get_texture().get_image().save_png(dir + "/curtain_1_start.png")
	# three moves forward (to the side twice, then straight up)
	m.run.move_to(0, 0)
	for k in 3:
		var o: Vector2i = m.run.options()[0 if k < 2 else 1]
		m.run.move_to(o.y, o.x)
	m.run.turns += 8  # (and the Curtain a little way down, to see it)
	_map(m).queue_free()
	m._overlay = null
	m.show_map()
	await t.create_timer(4.5).timeout
	t.root.get_texture().get_image().save_png(dir + "/curtain_2_moves.png")
	_map(m)._scroll_to = _map(m)._scroll_max() * 0.45  # (up to the middle: the widest rows)
	await t.create_timer(1.5).timeout
	t.root.get_texture().get_image().save_png(dir + "/curtain_3_top.png")
	print("curtain from level ", m.run.curtain_from(), " at row ", m.run.row, " options ", m.run.options())
	t.quit()
