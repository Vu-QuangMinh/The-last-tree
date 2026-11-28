extends RefCounted
## See tools/cast_all_test.gd: a fight against one enemy, Spark (Repeatable 2) woken twice, one click.


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var save = root.get_node("SaveManager")
	save.use_test_file("user://cast_all_test.json")
	save.data.settings["theme"] = "puppet"
	var m: Main = load("res://scripts/main.gd").new()
	root.add_child(m)
	await t.create_timer(0.5).timeout
	m.start_run()
	await t.create_timer(0.5).timeout
	m._start_fight(["rolling_bear"])
	await t.create_timer(6.0).timeout
	var fs: FightScreen = m.current
	var br: MarbleBridge = fs.fight
	br.m.foes[0].hp = 99
	br.m.foes[0].max_hp = 99
	br.m.hand.clear()
	br.m.chant.clear()
	for k in 2:
		br.m.chant.append({"c": "F", "sym": "", "src": -1, "uid": 900 + k})
	br.m.do_chant()
	br.m.events.clear()
	br._b_sync()
	fs.phase = "spells"
	fs._h_hud._build_spells()
	fs._h_hud._refresh_all()
	await t.create_timer(0.5).timeout
	var ci := br.m.run.cards.find("spark")
	print("CAST spark charges before: ", br.m.charges.get(ci, 0), "  bear HP ", br.m.foes[0].hp)
	var card: SpellCard = null
	for c in fs._cards:
		if String(c.spell.id).begins_with("spark"):
			card = c
	await fs._h_input._on_card_clicked(card)
	await t.create_timer(0.5).timeout
	print("CAST spark charges after one click: ", br.m.charges.get(ci, 0), "  bear HP ", br.m.foes[0].hp)
