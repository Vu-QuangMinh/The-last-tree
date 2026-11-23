extends RefCounted


func _shot(t: SceneTree, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	t.root.get_texture().get_image().save_png(out + "/bl_%s.png" % name)


func _burst(t: SceneTree, out: String, tag: String, n: int, gap: float) -> void:
	for k in n:
		await t.create_timer(gap).timeout
		await _shot(t, out, "%s_%02d" % [tag, k])


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://boost_shot.json")
	save.data.settings["theme"] = "puppet"
	var rs := RunState.new()
	rs.setup(root.get_node("GameData").db, [], [], 7)
	rs.loadout = ["spark", "splash", "water_gun", "stream", "knivels_innocence"]
	rs.spellbook = rs.loadout.duplicate()
	var f := rs.make_fight(["iceling"]) as MarbleBridge
	f.m.hand.clear()
	for spec in ["F:sword", "F", "W:shield", "W:heart", "W", "W", "F"]:
		f.m._uid += 1
		f.m.hand.append({"c": spec.get_slice(":", 0), "sym": spec.get_slice(":", 1) if spec.contains(":") else "", "src": -1, "uid": f.m._uid, "frozen": false, "hidden": false})
	# next turn's draw, carved too (the reels show it)
	var nd: Array = f.m.draw_pile
	var syms := ["skull", "coin", "ghost"]
	for k in mini(3, nd.size()):
		f.m.mrun.bag[int(nd[nd.size() - 1 - k])].sym = syms[k]
	f._b_sync()
	var fs := FightScreen.new()
	fs.setup(rs, f)
	root.add_child(fs)
	var real_anim: Callable = f.anim
	var n_lines := [0]
	f.anim = func(ev: Dictionary) -> void:
		if String(ev.type) == "boost_line":
			n_lines[0] += 1
			print("BL line %d: %s -> %s (%s)" % [n_lines[0], ev.src, ev.get("dsts", []), ev.col])
			var tag := "line_%02d" % n_lines[0]
			for pair in [["a", 0.25], ["b", 0.47], ["c", 0.56], ["d", 0.66], ["e", 0.8], ["f", 1.1]]:
				var suffix: String = pair[0]
				t.create_timer(float(pair[1])).timeout.connect(func(): _shot(t, out, tag + suffix))
		await real_anim.call(ev)
	await t.create_timer(7.0).timeout
	await _shot(t, out, "1_carved_row")
	for el in ["F|sword", "F|", "W|shield", "W|heart", "W|", "W|", "F|"]:
		for i in f.player.stock.size():
			var st: Dictionary = f.player.stock[i]
			if String(st.el) == el.get_slice("|", 0) and String(st.get("sym", "")) == el.get_slice("|", 1) and not (i in fs.chant_idx):
				fs._add_stock_index(i)
				break
	await t.create_timer(0.8).timeout
	await _shot(t, out, "2_chant_built")
	await fs._on_cast()
	await t.create_timer(1.0).timeout
	print("BL charges: ", f.charges, " hp ", f.player.hp)
	print("BL spark says: ", String(fs._card_for("spark")._rules.text).left(80))
	print("BL knivel desc: ", f.loadout[4].desc, " | model: ", f.m.card(4).text, " | shown: ", fs._card_for("knivels_innocence")._rules.get_parsed_text())
	await _shot(t, out, "5_after_lines")
	await fs._on_card_clicked(fs._card_for("splash"))
	await t.create_timer(1.5).timeout
