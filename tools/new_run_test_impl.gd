extends RefCounted


func _shot(t: SceneTree, name: String) -> void:
	if OS.get_environment("NR_NOSHOT") != "":
		return
	await t.process_frame
	t.root.get_texture().get_image().save_png("C:/temp/nr_%s.png" % name)


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://new_run_save.json")
	save.data.settings["theme"] = "puppet"
	var mon := FrameMon.new()
	t.process_frame.connect(mon.tick)
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()  # make a run to be saved
	await t.create_timer(3.5).timeout
	m._overlay.chosen.emit(0)
	await t.create_timer(4.6).timeout
	m.run = null
	m.show_menu()
	await t.create_timer(0.8).timeout
	print("has run: ", save.has_run(), " current: ", m.current)
	m._new_run()
	await t.create_timer(0.5).timeout
	await _shot(t, "1_popup")
	print("popup is child of menu: ", m.current is MenuScreen, " children: ", m.current.get_child_count())
	var pop: MessageScreen = m.current.get_child(m.current.get_child_count() - 1)
	pop.pressed.emit(1)  # Back
	await t.create_timer(0.3).timeout
	print("after Back: menu ", m.current is MenuScreen, " popup valid ", is_instance_valid(pop) and not pop.is_queued_for_deletion())
	m._new_run()
	await t.create_timer(0.3).timeout
	pop = m.current.get_child(m.current.get_child_count() - 1)
	print("confirm at ", (Time.get_ticks_msec() - mon.t0) / 1000.0)
	pop.pressed.emit(0)  # Start a new run
	await t.create_timer(1.2).timeout
	await _shot(t, "2_closing")
	await t.create_timer(2.2).timeout
	await _shot(t, "3_keepsakes")
	print("overlay: ", m._overlay, " shut: ", m.current.get_stage().curtains.is_shut())
	m._overlay.chosen.emit(0)
	await t.create_timer(1.0).timeout
	await _shot(t, "4_map_dropping")
	await t.create_timer(3.0).timeout
	await _shot(t, "5_map")
	print("map: ", m._overlay)
	save.clear_run()
	print("slow frames (>40 ms): ", mon.slow)
	m.queue_free()
	t.quit()


class FrameMon:
	var last := 0
	var t0 := Time.get_ticks_msec()
	var slow: Array = []
	var on := false

	func tick() -> void:
		var n := Time.get_ticks_msec()
		if last > 0 and n - last > 40:
			slow.append("%d@%.1fs" % [n - last, (n - t0) / 1000.0])
		last = n
