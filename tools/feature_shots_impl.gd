extends RefCounted

var out := "user://feature_shots"
var root: Window
var tree: SceneTree


func run(t: SceneTree) -> void:
	tree = t
	root = t.root
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	var save = root.get_node("SaveManager")
	save.use_test_file("user://feature_save.json")
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 11)
	for id in ["kindling_stone", "echo_shell", "bandolier"]:
		run.gain_artifact(id)
	for id in ["inferno", "miasma", "arcane_barrage", "meteor"]:
		run.learn_spell(id)
	run.seal_spell("fire_ball", 1)
	run.seal_spell("inferno", 0)
	run.seal_spell("inferno", 2)
	# 1. the fight: statuses, bottles, charged artifacts, Burn / Poison marks, seals on cards
	var f := run.make_fight(["stone_knight", "ashling", "gale_sprite"])
	f.enemies[1].burn = 2
	f.enemies[2].poison = 2
	f.enemies[0].burn = 1
	f.enemies[0].poison = 1
	f.player.shield = 5
	f.player.aegis = 1
	f.player.bleed = 2
	f.player.thorns_turn = 2
	f.player.kindling_charged = true
	f.player.echo_casts = 7
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await _wait(20)
	await _shot("01_fight_status_bottles")
	# 2. Grimoire Ink: the spell chooser
	fs._spell_chooser(f.spellbook.filter(func(s): return not f.loadout.has(s)))
	await _wait(10)
	await _shot("02_grimoire_ink")
	fs._spell_chosen.emit(-1)
	await _wait(5)
	# 3. drink a targeted bottle (Liquid Fire) and a Barrage
	f.player.bottles = ["liquid_fire", "prism_draught", "echo_draught"]
	fs._refresh_all()
	await _wait(5)
	fs._bottle_from = fs._bottle_row.get_child(0).get_global_rect().get_center()
	fs.busy = true
	f.use_bottle(0, 1)
	await _wait(18)
	await _shot("03_bottle_liquid_fire")
	await _wait(60)
	fs.busy = false
	fs.queue_free()
	await _wait(3)
	# 4. loadout: dragging a card
	var l := LoadoutScreen.new()
	l.setup(run, ["stone_knight", "ashling"])
	root.add_child(l)
	await _wait(10)
	var cards: Array = l._active_row.get_children().filter(func(c): return c is SpellCard)
	var c0: SpellCard = cards[0]
	var at := c0.get_global_rect().get_center()
	l._press = {"id": run.loadout[0], "at": at, "card": c0}
	l._begin_drag(at)
	for k in 14:
		l._move_drag(at + Vector2(40.0 * k, -20))
		await tree.process_frame
	await _wait(2)
	await _shot("04_loadout_drag")
	for k in 30:
		await tree.process_frame
	await _shot("04b_loadout_drag_settled")
	l.queue_free()
	await _wait(3)
	# 5. the shop with bottles
	var sh := ShopScreen.new()
	run.amber = 200
	sh.setup(run, run.shop_stock())
	root.add_child(sh)
	await _wait(10)
	await _shot("05_shop")
	sh.queue_free()
	await _wait(3)
	# 6. the seal screen, before and after
	var se := SealScreen.new()
	se.setup(run, "meteor")
	root.add_child(se)
	await _wait(10)
	await _shot("06_seal_pick")
	var orbs: Array = se._orbs.get_children()
	se._seal(1, orbs[1])
	await _wait(20)
	await _shot("06b_seal_stamp")
	await _wait(60)
	await _shot("06c_sealed")
	se.queue_free()
	await _wait(3)
	# 7. fusing
	var fu := FuseScreen.new()
	fu.setup(run)
	root.add_child(fu)
	await _wait(5)
	fu._toggle("water_wall")
	fu._toggle("miasma")
	await _wait(10)
	await _shot("07_fuse")
	print("SHOTS DONE")


func _wait(n: int) -> void:
	for i in n:
		await tree.process_frame


func _shot(name: String) -> void:
	await tree.process_frame
	root.get_texture().get_image().save_png(out + "/" + name + ".png")
