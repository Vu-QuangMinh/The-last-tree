extends RefCounted

func run(t: SceneTree) -> void:
	var root: Window = t.root
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://character_panel.png"
	var save = root.get_node("SaveManager")
	save.use_test_file("user://character_panel_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	run.amber = 1234
	var f := run.make_fight(["greenseer", "yin_yang_clone", "rolling_bear"])
	var p = f.player
	p.hp = 37.0
	p.shield = 12.0
	p.lasting = 4.0
	# every status at once: 4 buffs, 10 debuffs
	p.aegis = 2
	p.thorns_turn = 3
	p.ethereal = true
	p.echo_next = true
	p.bleed = 3
	p.confuse_turns = 2
	p.blind_turns = 1
	p.frail_turns = 2
	p.vulnerable = 2
	p.brittle_turns = 2
	p.toll = 4
	p.overload = 1
	p.disarmed_turns = 1
	p.silenced = {"fire_ball": 1}
	# 8 Powers (the most a loadout of 8 can hold)
	for id in ["kindle", "thorn_mantle", "cauterize", "trade_winds", "rising_tide", "ember_crown", "venom_coat", "attunement"]:
		p.used_powers[id] = true
	p.passives["attune_el"] = "W"
	p.passives["attune"] = 1
	# 5 bottles
	var bids: Array = Bottles.ALL.map(func(b): return b.id)
	p.bottles = bids.slice(0, 5)
	# 24 artifacts
	var aids: Array = Artifacts.ALL.map(func(a): return a.id)
	f.artifacts = aids.slice(0, 24)
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await t.create_timer(3.0).timeout
	await t.create_timer(0.3).timeout
	root.get_texture().get_image().save_png(out)
	t.quit()
