extends RefCounted


func _buttons(fs: FightScreen) -> Array:
	var out: Array = []
	for n in fs.find_children("*", "Button", true, false):
		if n.get_global_rect().size.x > 1000.0:  # (the talk's options and Engage!)
			out.append(n)
	return out


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "C:/temp/shots"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://talk_voice_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var r := RunState.new()
	r.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var f := r.make_fight(["handyman"])
	var fs := FightScreen.new()
	fs.setup(r, f)
	fs.stage_flow = true
	fs.arrive = true
	fs.hold_hud = true
	root.add_child(fs)
	await t.create_timer(8.0).timeout
	print("before Begin: talking ", fs._talking, " voice ", Audio.voice_busy(), " pending ", fs._talk_pending)
	var spells: Array = r.loadout.map(func(id): return r.spell(id))
	var book: Array = r.spellbook.map(func(id): return r.spell(id))
	fs.begin_with_spells(spells, book, [])
	for k in 10:
		await t.create_timer(0.7).timeout
		var bs := _buttons(fs)
		print("t+%.1f talking %s voice %s buttons %s" % [0.7 * (k + 1), fs._talking, Audio.voice_busy(), bs.map(func(b): return b.disabled)])
		if k == 3:
			root.get_texture().get_image().save_png(out + "/talk_1.png")
	# wait for the first line to end, then answer at once and check that the answer is cut off by the next click
	var waited := 0.0
	while Audio.voice_busy() and waited < 12.0:
		await t.create_timer(0.25).timeout
		waited += 0.25
	var bs := _buttons(fs)
	print("after the first line (%.1f s): buttons disabled %s" % [waited, bs.map(func(b): return b.disabled)])
	for b in bs:
		if b != bs.back():
			b.pressed.emit()  # (the first option)
			break
	await t.create_timer(0.8).timeout
	print("answer: voice ", Audio.voice_busy())
	var bs2 := _buttons(fs)
	print("buttons right away: disabled ", bs2.map(func(b): return b.disabled))
	t.quit()
