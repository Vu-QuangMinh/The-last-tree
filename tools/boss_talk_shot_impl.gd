extends RefCounted


func run(t: SceneTree) -> void:
	t.create_timer(90.0).timeout.connect(t.quit)
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var boss := OS.get_environment("BOSS") if OS.get_environment("BOSS") != "" else "handyman"
	var theme := OS.get_environment("SHOT_THEME") if OS.get_environment("SHOT_THEME") != "" else "puppet"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://boss_talk_shot.json")
	save.data.settings["theme"] = theme
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight([boss])
	var fs := FightScreen.new()
	fs.setup(r, f)
	fs.stage_flow = true
	fs.arrive = true
	fs.hold_hud = true
	root.add_child(fs)
	await t.create_timer(8.0).timeout
	var spells: Array = r.loadout.map(func(id): return r.spell(id))
	var book: Array = r.spellbook.map(func(id): return r.spell(id))
	fs.begin_with_spells(spells, book, [])
	await t.create_timer(2.5).timeout
	root.get_texture().get_image().save_png(out + "/talk_%s_%s_1.png" % [boss, theme])
	var waited := 0.0
	while Audio.voice_busy() and waited < 12.0:
		await t.create_timer(0.25).timeout
		waited += 0.25
	var bs: Array = []
	for n in fs.find_children("*", "Button", true, false):
		if n.get_global_rect().size.x > 300.0 and n.get_global_rect().position.y > 500.0:
			bs.append(n)
	print("buttons: ", bs.map(func(b): return b.get_global_rect()))
	for b in bs:
		if b != bs.back() and not b.disabled:
			b.pressed.emit()
			break
	await t.create_timer(1.5).timeout
	root.get_texture().get_image().save_png(out + "/talk_%s_%s_2.png" % [boss, theme])
	for b in fs.find_children("*", "Button", true, false):  # (Engage! is the last button of the talk: the fight's own HUD comes back)
		if b.text == "Engage!":
			b.pressed.emit()
	await t.create_timer(2.0).timeout
	root.get_texture().get_image().save_png(out + "/talk_%s_%s_3.png" % [boss, theme])
	t.quit()
