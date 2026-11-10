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
	# three moves (up, up, sideways): the Curtain has swallowed the first row
	m.run.move_to(2, 0)
	m.run.move_to(MapGen.hex_up(0, 2, MapGen.C_COLS)[0], 1)
	m.run.move_to(m.run.col - 1, 1)
	_map(m).queue_free()
	m._overlay = null
	m.show_map()
	await t.create_timer(4.5).timeout
	t.root.get_texture().get_image().save_png(dir + "/curtain_2_moves.png")
	print("rows eaten ", m.run.curtain_rows(), " at row ", m.run.row, " options ", m.run.options())
	t.quit()
