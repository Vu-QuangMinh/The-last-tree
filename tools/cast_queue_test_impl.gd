extends RefCounted


func run(t: SceneTree) -> void:
	var root: Window = t.root
	var out: String = OS.get_cmdline_user_args()[0]
	var save = root.get_node("SaveManager")
	save.use_test_file("user://encounter_shot_save.json")
	save.data.settings["theme"] = "puppet"
	var gd = root.get_node("GameData")
	var rs := RunState.new()
	rs.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	rs.loadout = ["droplet", "drizzle", "borrowed_breath"]
	rs.player.hp = rs.player.max_hp - 10
	var f := rs.make_fight(["ashling"])
	var fs := FightScreen.new()
	fs.test_mode = true
	fs.setup(rs, f)
	root.add_child(fs)
	await t.create_timer(4.0).timeout
	f.player.stock.clear()
	for ch in "WWA":
		f.player.add_element(ch)
	fs._refresh_all()
	fs.chant_idx = [0, 1, 2]
	await fs._on_cast()
	await t.create_timer(1.0).timeout
	var cards := {}
	for c in fs._cards:
		cards[c.spell.id] = c
	print("charges: ", fs._cards.map(func(c): return [c.spell.id, c.charges]))
	var before := f.lines.size()
	fs._on_card_clicked(cards["borrowed_breath"])  # (resolving now)
	await t.process_frame
	fs._on_card_clicked(cards["drizzle"])
	fs._on_card_clicked(cards["droplet"])
	print("queue: ", fs._cast_queue)
	await t.create_timer(0.15).timeout
	root.get_texture().get_image().save_png(out + "/queue.png")
	await t.create_timer(6.0).timeout
	print("log: ", f.lines.slice(before))
	print("charges after: ", fs._cards.map(func(c): return [c.spell.id, c.charges]))
	t.quit()
