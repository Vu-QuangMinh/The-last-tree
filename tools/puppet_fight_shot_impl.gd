extends RefCounted

func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://puppet_fight.png"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://puppet_shot_save.json")
	save.data.settings["theme"] = OS.get_environment("SHOT_THEME") if OS.get_environment("SHOT_THEME") != "" else "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["greenseer", "yin_yang_clone", "rolling_bear"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(6.0 if OS.get_environment("SHOT_THEME") == "" else 3.0).timeout
	if OS.get_environment("SHOT_THEME") != "":
		_shot(root, out)
		t.quit()
		return
	_shot(root, out)
	# a spell's Essence for next turn: card -> pipe -> box
	var ev := {"drawn": ["A", "F"], "eff": {"temp": false}}
	fs._stash_flight(ev, Vector2(900, 700))
	for k in 3:
		await t.create_timer(0.45).timeout
		_shot(root, out.replace(".png", "_stash%d.png" % k))
	await t.create_timer(2.0).timeout
	# end the turn: the globe's balls fall into the box and everything rolls out into the bag
	fs._on_end_turn()
	await t.create_timer(7.6).timeout
	for k in 24:
		await t.create_timer(0.22).timeout
		_shot(root, out.replace(".png", "_turn%02d.png" % k))
	t.quit()


func _shot(root: Window, path: String) -> void:
	root.get_texture().get_image().save_png(path)

