extends RefCounted


func run(t: SceneTree) -> void:
	var root := t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://invoker_flow.json")
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["invoker"])
	var fs := FightScreen.new()
	fs.setup(r, f)
	root.add_child(fs)
	await t.create_timer(5.0).timeout
	for b in fs.find_children("*", "Button", true, false):
		if b.text == "Engage!":
			b.pressed.emit()
	await t.create_timer(4.0).timeout
	var e: EnemyState = f.enemies[0]
	print("PUPPET TEX ", fs._views[e].creature.puppet_tex() != null)
	# a new set
	for sp in e.conjured:
		sp.spent = true
	f._plan(e)
	for k in 5:
		await t.create_timer(0.15).timeout
		root.get_texture().get_image().save_png("%s/summon_%d.png" % [out, k])
	await t.create_timer(2.0).timeout
	# phase 2
	e.elements.clear()
	f._check_end()
	for k in 14:
		await t.create_timer(0.2).timeout
		root.get_texture().get_image().save_png("%s/reform_%02d.png" % [out, k])
	print("PHASE ", e.phase, " visible ", fs._views[e].creature.visible)
