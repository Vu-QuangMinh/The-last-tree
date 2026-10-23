extends RefCounted
func run(t: SceneTree) -> void:
	t.create_timer(60.0).timeout.connect(t.quit)
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://act_sign_check.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := run.make_fight(["ashling"])
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	var rest: float = PuppetTopHud.ACT_SIGN.position.y
	print("t0: visible ", fs._act_sign.visible, " y ", fs._act_sign.position.y, " (rest ", rest, ")")
	await t.create_timer(2.0).timeout
	print("t2: visible ", fs._act_sign.visible, " y ", fs._act_sign.position.y, " text ", fs._info.text.replace("\n", "|"))
	await t.create_timer(9.5).timeout
	print("t11.5: visible ", fs._act_sign.visible, " y ", fs._act_sign.position.y)
	t.quit()
