extends RefCounted

const AT := [0.03, 0.07, 0.12, 0.2, 0.35, 0.6]


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://saber_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var rs := RunState.new()
	rs.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	var fs := FightScreen.new()
	fs.test_mode = true
	fs.setup(rs, rs.make_fight(["mob_torch"]))
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	if args.has("real"):  # the real attack: HP is already down 10 (50 -> 40), the cuts must cross in the middle of the part of the bar that was lost
		fs.fight.player.max_hp = 50.0
		fs.fight.player.hp = 30.0
		fs._h_hud._refresh_all()
		var ev := {"enemy": fs.fight.enemies[0], "n": 5, "kind": "attack"}
		fs._h_anim._enemy_attack(ev)
		for i in 5:
			await t.create_timer(0.16).timeout
			root.get_texture().get_image().save_png(out + "/sb_%d.png" % i)
		t.quit()
		return
	var p: Vector2 = fs._hp_bar.get_global_rect().get_center() + Vector2(300.0, -330.0)
	print("AT ", p)
	var fx := SaberSlash.hit(fs._fx, p, args.has("blocked"), 12.0, 50.0)
	fx.set_process(false)  # (stepped by hand, 1/60 s at a time, so every still is the same instant whatever the screenshot costs)
	var now := 0.0
	for i in AT.size():
		while now < float(AT[i]) - 0.001:
			fx._process(1.0 / 60.0)
			now += 1.0 / 60.0
		await t.process_frame
		await t.process_frame
		root.get_texture().get_image().save_png(out + "/sb_%d.png" % i)
	t.quit()
