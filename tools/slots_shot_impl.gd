extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://slots_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var pool := ["fire_ball", "water_wall", "tailwind", "frost_nova", "thieving_wind", "undercurrent", "spray", "glacial_spike"]
	for n in range(1, 9):
		var run := RunState.new()
		run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
		run.loadout = pool.slice(0, n).filter(func(id): return gd.db.get_spell(id) != null)
		var f := run.make_fight(["greenseer", "rolling_bear"])
		var fs := FightScreen.new()
		fs.setup(run, f)
		root.add_child(fs)
		await t.create_timer(5.0).timeout
		root.get_viewport().get_texture().get_image().save_png(out + "/slots_%d.png" % n)
		print("n=%d loadout %s" % [n, run.loadout])
		fs.queue_free()
		await t.create_timer(0.5).timeout
