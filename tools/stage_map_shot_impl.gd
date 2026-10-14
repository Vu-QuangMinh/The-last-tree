extends RefCounted


func _shot(t: SceneTree, dir: String, name: String) -> void:
	await t.process_frame
	t.root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var dir: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "C:/temp"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://stage_map_save.json")
	save.data.settings["theme"] = "puppet"
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	m.current.chosen.emit(0)  # the keepsake
	# wait for the map, then follow the drop: the world's y and a room's y every frame
	var guard := 0
	while not (is_instance_valid(m._overlay) and m._overlay is MapScreen and m._overlay._world != null) and guard < 600:
		await t.process_frame
		guard += 1
	var map: MapScreen = m._overlay
	var series := []
	var shots := {0.35: "d1", 0.7: "d2", 1.0: "d3", 1.3: "d4"}
	var t0 := Time.get_ticks_msec()
	var next_shot := 0
	var keys := shots.keys()
	while Time.get_ticks_msec() - t0 < 3600:
		await t.process_frame
		var el := (Time.get_ticks_msec() - t0) / 1000.0
		series.append("%.2f:%.0f" % [el, map._world.position.y])
		if next_shot < keys.size() and el >= keys[next_shot]:
			t.root.get_texture().get_image().save_png("%s/%s.png" % [dir, shots[keys[next_shot]]])
			next_shot += 1
	print("world y: ", " ".join(series.filter(func(s): return int(s.get_slice(":", 0).replace(".", "")) % 5 == 0)))
	await _shot(t, dir, "m1_start")
	for pressed in [true, false]:  # a click: the "You found an artifact" popup of the keepsake goes away
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.position = Vector2(960, 540)
		click.global_position = click.position
		Input.parse_input_event(click)
		await t.create_timer(0.1).timeout
	await t.create_timer(0.6).timeout
	await _shot(t, dir, "m2_after_click")

	for i in 9:  # (wheel up to the boss's rope and knot)
		var w := InputEventMouseButton.new()
		w.button_index = MOUSE_BUTTON_WHEEL_UP
		w.pressed = true
		w.position = Vector2(960, 600)
		w.global_position = w.position
		Input.parse_input_event(w)
		await t.create_timer(0.15).timeout
	await t.create_timer(1.0).timeout
	await _shot(t, dir, "m3_boss")
	for i in 9:
		var w := InputEventMouseButton.new()
		w.button_index = MOUSE_BUTTON_WHEEL_DOWN
		w.pressed = true
		w.position = Vector2(960, 600)
		w.global_position = w.position
		Input.parse_input_event(w)
		await t.create_timer(0.15).timeout
	await t.create_timer(1.0).timeout
	# choose a room: the curtain is drawn shut, the room is made ready behind it, then it opens
	var col: int = m.run.choices()[0]
	map.node_chosen.emit(col)
	await t.create_timer(0.5).timeout
	await _shot(t, dir, "c1_closing")
	await t.create_timer(0.9).timeout
	await _shot(t, dir, "c2_shut")
	await t.create_timer(1.2).timeout
	await _shot(t, dir, "c3_opening")
	await t.create_timer(1.4).timeout
	await _shot(t, dir, "c4_open")
	print("done")
	t.quit()
