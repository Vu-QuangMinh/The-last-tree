extends RefCounted
## Quit a boss fight to the menu and Continue, three times: how many hands does the Handyman have each time?


func _count(m, tag: String) -> void:
	var fs = m.current
	if fs is FightScreen:
		var hv := 0
		if fs._hm_stage != null and is_instance_valid(fs._hm_stage):
			for c in fs._hm_stage.get_children():
				if c is EnemyView:
					hv += 1
		var rows := 0
		for c in fs._enemy_row.get_children():
			rows += 1
		print("%s: enemies %s | views %d | stage views %d | enemy_row children %d | screens in tree %d" % [tag, fs.fight.enemies.map(func(e): return e.id), fs._views.size(), hv, rows, fs.get_tree().get_nodes_in_group("fight_screen").size()])
	else:
		print("%s: current is %s" % [tag, m.current])


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://boss_reenter_save.json")
	save.data.settings["theme"] = "puppet"
	var m = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	for k in 40:
		if m._overlay != null:
			break
		await t.create_timer(0.25).timeout
	m._overlay.chosen.emit(0)
	await t.create_timer(4.6).timeout
	m.run.encounter = ["handyman"]
	m.run.encounter_extra = [[]]
	m._show_loadout(["handyman"])
	await t.create_timer(3.5).timeout
	m._overlay.confirmed.emit()
	await t.create_timer(9.0).timeout
	_count(m, "first entry")
	print("--- Test mode (Fight! / quit to the test screen)")
	m._test_state = {"enemies": ["handyman"]}
	for k in 3:
		m.open_test_mode()
		await t.create_timer(1.5).timeout
		m.current.fight_requested.emit(m.current.state.enemies.duplicate(), m.current.state.spells.duplicate())
		await t.create_timer(7.0).timeout
		_count(m, "test fight %d" % (k + 1))
	print("--- Continue (a hand has fallen before each quit)")
	for k in 3:
		var fl = m.current.fight
		for e in fl.enemies.filter(func(x): return not x.knocked and x.has_passive("hand")).slice(0, 1):
			e.elements.clear()
			fl._cleanup()
		await t.create_timer(2.0).timeout
		_count(m, "before quit %d" % (k + 1))
		m.show_menu()
		await t.create_timer(1.5).timeout
		m.continue_run()
		await t.create_timer(3.5).timeout
		if m._overlay != null and m._overlay.has_signal("confirmed"):
			m._overlay.confirmed.emit()
		await t.create_timer(9.0).timeout
		_count(m, "re-entry %d" % (k + 1))
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0] + "/re_%d.png" % (k + 1))
	t.quit()
