extends RefCounted
## The Invoker through real turns: your Release takes his last Essence (phase 2), his quiet turn, then his chanting turns.
## Prints every speech bubble seen and whether he burst and reformed.

var seen := {}


func run(t: SceneTree) -> void:
	var root := t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://invoker_real.json")
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
	var done := [false]
	(func():
		for turn in 4:
			f.player.hp = 999
			if turn == 0:
				e.elements = ["F"]
				e.armor = [false]
				e.lit = [false]
				e.painted = [false]
				e.parts = [""]
				f.player.stock.clear()
				f.player.add_element("F")
			print("TURN %d phase=%d spent=%s" % [turn, e.phase, str(e.conjured.map(func(s): return s.get("spent", false)))])
			await f.cast_chant([0] if not f.player.stock.is_empty() else [])
			await f.finish_turn()
		done[0] = true).call()
	var k := 0
	var shards := 0
	var t_reform := -1
	var shots := 0
	while not done[0] and k < 400:
		await t.create_timer(0.1).timeout
		for n in fs.find_children("*", "Label", true, false):
			if n.get_parent() is PanelContainer and n.get_parent().get_parent() == fs._fx and n.text != "" and not seen.has(n.text):
				seen[n.text] = true
				print("SAYS: ", n.text, "  (reform running: ", fs._reforming.size() > 0, ")")
		for c in fs.get_children():
			if c is PuppetShatter and c._reform and not c.has_meta("seen"):
				c.set_meta("seen", true)
				shards += 1
				print("REFORM started, pieces=", c._pieces.size())
				t_reform = Time.get_ticks_msec()
		if t_reform > 0 and fs._reforming.is_empty():
			print("REFORM took %.1f s" % ((Time.get_ticks_msec() - t_reform) / 1000.0))
			t_reform = -1
		if t_reform > 0 and shots < 30 and k % 3 == 0:
			root.get_texture().get_image().get_region(Rect2i(500, 150, 600, 450)).save_png("%s/rf_%02d.png" % [out, shots])
			shots += 1
		k += 1
	print("END phase=%d creature_visible=%s reforms=%d" % [e.phase, fs._views[e].creature.visible, shards])
