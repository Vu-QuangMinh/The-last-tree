extends RefCounted


func _shot(t: SceneTree, out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	t.root.get_texture().get_image().save_png(out + "/gf_%s.png" % name)


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://ghost_focus_shot.json")
	save.data.settings["theme"] = "puppet"
	var rs := RunState.new()
	rs.setup(root.get_node("GameData").db, [], [], 7)
	rs.loadout = ["focus_fire", "spark", "splash"]
	rs.spellbook = rs.loadout.duplicate()
	var f := rs.make_fight(["yellow_slime"]) as MarbleBridge
	f.m.foes[0].hp = 40
	f.m.foes[0].max_hp = 40
	f.m.hand.clear()
	for spec in ["A:ghost", "A", "F", "W"]:
		f.m._uid += 1
		f.m.hand.append({"c": spec.get_slice(":", 0), "sym": spec.get_slice(":", 1) if spec.contains(":") else "", "src": -1, "uid": f.m._uid, "frozen": false, "hidden": false})
	f._b_sync()
	var fs := FightScreen.new()
	fs.setup(rs, f)
	root.add_child(fs)
	var real_anim: Callable = f.anim
	var n := [0]
	f.anim = func(ev: Dictionary) -> void:
		var ty := String(ev.type)
		if ty in ["boost_line", "spell_effect"]:
			n[0] += 1
			var tag := "%02d_%s_%s" % [n[0], ty, String(ev.get("col", ev.get("op", "")))]
			print("GF ", tag)
			for pair in [["a", 0.12], ["b", 0.3], ["c", 0.5], ["d", 0.75]]:
				var suffix: String = pair[0]
				t.create_timer(float(pair[1])).timeout.connect(func(): _shot(t, out, tag + suffix))
		await real_anim.call(ev)
	await t.create_timer(6.0).timeout
	for el in ["A|ghost", "A|", "F|"]:
		for i in f.player.stock.size():
			var st: Dictionary = f.player.stock[i]
			if String(st.el) == el.get_slice("|", 0) and String(st.get("sym", "")) == el.get_slice("|", 1) and not (i in fs.chant_idx):
				fs._add_stock_index(i)
				break
	await t.create_timer(0.8).timeout
	print("GF before chant: ", f.loadout[0].desc)
	await fs._on_cast()
	await t.create_timer(1.0).timeout
	print("GF after chant: ", f.loadout[0].desc, " | dodge ", f.player.aegis, " | bag ", f.m.mrun.bag.size())
	await _shot(t, out, "50_after_chant")
	var hp0 := int(f.m.foes[0].hp)
	fs._on_card_clicked(fs._card_for("focus_fire"))
	await t.create_timer(0.6).timeout
	fs._finish_aim(0)
	await t.create_timer(4.0).timeout
	print("GF focus fire dealt ", hp0 - f.m.foes[0].hp, " expose ", f.m.foes[0].expose)
	await _shot(t, out, "60_after_focus")
