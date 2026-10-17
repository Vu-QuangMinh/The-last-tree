extends RefCounted
func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://aa_save.json")
	save.data.settings["theme"] = "puppet"
	EnemyRopes.file = "user://aa_ropes.json"
	EnemyRopes.set_points("yeti", [Vector2(0.5, 0.2)])
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["yeti"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(8.0).timeout
	root.get_texture().get_image().save_png(out)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(EnemyRopes.file))
	t.quit()
