extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://rows_check.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["veiled_eyes"])
	var fs := FightScreen.new()
	fs.setup(r, f)
	fs.stage_flow = true
	root.add_child(fs)
	await t.create_timer(3.0).timeout
	var v: EnemyView = fs._views.values()[0]
	var report := func(tag: String):
		var ys := {}
		for ic in v._hp_row.get_children():
			ys[snappedf(ic.position.y, 1.0)] = true
		print("ROWS ", tag, " phase ", f.enemies[0].phase, " n=", v._hp_row.get_child_count(), " distinct y=", ys.size(), " px=", v._px, " layout=", v._px_layout, " row size=", v._hp_row.size, " max_n=", v._max_n, " holder_w=", v._holder.size.x, " minh=", v._hp_row.custom_minimum_size.y)
	report.call("normal")
	v.pick_mode = true
	v.refresh({})
	await t.create_timer(0.3).timeout
	report.call("pick")
	v.pick_mode = false
	v.refresh({})
	await t.create_timer(0.3).timeout
	report.call("normal again")
	f.enemies[0].reset_hp(String(f.enemies[0].def.hp2))
	f.enemies[0].phase = 2
	v.refresh({})
	await t.create_timer(0.3).timeout
	report.call("phase 2")
	v.pick_mode = true
	v.refresh({})
	await t.create_timer(0.3).timeout
	report.call("phase 2 pick")
	t.quit()
