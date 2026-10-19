extends RefCounted
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://burn_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["yin_yang_beast", "rolling_bear", "giant_slime"])
	var fs := FightScreen.new()
	fs.setup(r, f)
	fs.stage_flow = true
	root.add_child(fs)
	await t.create_timer(3.0).timeout
	var fr: Vector2 = fs._stage.floor_range()
	print("floor ", fr)
	for step in 8:
		for e in f.enemies:
			if step >= 1:
				e.burn = 2 + step
				e.weak_turns = 1
		fs._refresh_all()
		await t.create_timer(0.6).timeout
		var lines: Array = []
		for e in fs._views:
			var v: EnemyView = fs._views[e]
			lines.append("%s feet %.0f name %.0f" % [e.id, v.creature.global_position.y + v.creature.size.y, v._name.global_position.y])
		print("step ", step, " lift ", snappedf(fs._extra_lift, 0.1), " row y ", snappedf(fs._enemy_row.position.y, 0.1), " | ", " | ".join(lines))
	root.get_texture().get_image().save_png("C:/temp/burn.png")
	t.quit()
