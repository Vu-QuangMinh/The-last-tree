extends RefCounted


func _shot(t: SceneTree, name: String) -> void:
	await t.process_frame
	t.root.get_texture().get_image().save_png("C:/temp/sp_%s.png" % name)


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://side_panels_save.json")
	save.data.settings["theme"] = "puppet"
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(3.5).timeout
	var run = m.run
	for id in ["wind_chime", "bandolier"]:
		run.gain_artifact(id)
	run.gain_bottle("fire_flask")
	run.gain_bottle("water_flask")
	run.gain_bottle("fire_flask")
	m._overlay.chosen.emit(0)
	await t.create_timer(5.0).timeout
	m._overlay.node_chosen.emit(run.choices()[0])
	await t.create_timer(3.0).timeout
	await _shot(t, "1_map_corner")
	m._overlay.confirmed.emit()
	await t.create_timer(1.5).timeout
	await _shot(t, "2_moving")
	await t.create_timer(8.0).timeout
	await _shot(t, "3_fight")
	var fs = m.current
	for e in fs.fight.enemies:
		e.elements.clear()
	fs.fight.over = true
	fs.fight.won = true
	fs._finish()
	await t.create_timer(6.0).timeout
	await _shot(t, "4_after")
	t.quit()
