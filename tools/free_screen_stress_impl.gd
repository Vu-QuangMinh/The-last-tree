extends RefCounted

const DELAYS := [0.05, 0.4, 0.9, 1.6, 2.4, 3.5, 5.0]


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://free_stress_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	for ids in [["bug_hunter"], ["bug_hunter", "mob_torch"]]:
		for d in DELAYS:
			var rs := RunState.new()
			rs.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
			var f := rs.make_fight(ids)
			var fs := FightScreen.new()
			fs.test_mode = true
			fs.setup(rs, f)
			root.add_child(fs)
			await t.create_timer(3.0).timeout  # (the screen has come up)
			fs._h_input._on_end_turn()  # (pass the turn: the enemies act, effects start)
			await t.create_timer(d).timeout
			fs.queue_free()
			print("freed after ", d, " s  (", ids, ")")
			await t.create_timer(6.0).timeout  # (anything that wakes up now would touch the dead screen)
	print("stress done")
	t.quit()
