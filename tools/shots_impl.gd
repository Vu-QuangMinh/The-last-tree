extends RefCounted
## Renders each screen to PNG for a visual check.
## Usage (windowed): godot --path . --resolution 1920x1080 -s tools/shots.gd -- <out_dir>

var out := "user://shots"


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
	save.use_test_file("user://shots_save.json")
	save.data.codex = ["ashling", "gale_sprite", "stone_knight", "woodcutter", "puddle_slime"]
	save.data.seedlings = 85
	var gd = root.get_node("GameData")
	var run := RunState.new()
	run.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 42)
	run.gain_artifact("ember_charm")
	for id in ["inferno", "miasma", "kindle"]:
		run.learn_spell(id)
	var sh := ShopScreen.new()
	run.amber = 130
	sh.setup(run, run.shop_stock())
	await _shot(sh, "02c_shop")
	var ev := MapEvents.get_event("mushroom_ring")
	var ms := MessageScreen.new()
	ms.title = ev.title
	ms.body = ev.text
	ms.buttons = ev.options.map(func(o): return o.label)
	ms.title_color = Color(0.8, 0.7, 1)
	await _shot(ms, "02b_event")
	var menu := MenuScreen.new()
	await _shot(menu, "01_menu")
	run.move_to(run.choices()[0])
	var m := MapScreen.new()
	m.setup(run)
	await _shot(m, "02_map")
	var l := LoadoutScreen.new()
	l.setup(run, ["stone_knight", "gale_sprite", "echo_wraith"])
	await _shot(l, "03_loadout", true, true)
	var cr: Creature = l.find_children("*", "Creature", true, false)[0]
	var tp := PanelContainer.new()
	tp.add_theme_stylebox_override("panel", UiTheme.get_theme().get_stylebox("panel", "TooltipPanel"))
	tp.add_child(Keywords.make_tooltip(cr.tooltip_text))
	tp.position = cr.global_position + Vector2(60, 150)
	l.add_child(tp)
	await _shot(l, "03b_loadout_hover")
	var f := run.make_fight(["stone_knight", "ashling", "gale_sprite"])
	f.enemies[0].set_armor(1)
	f.enemies[1].burn = 2
	var fs := FightScreen.new()
	fs.setup(run, f)
	root.add_child(fs)
	await tree.process_frame
	f.player.stock.clear()
	for ch in "FFWAFFAW":
		f.player.add_element(ch)
	f.player.stock[7].temp = true
	f.player.silenced["water_wall"] = 2
	for i in [0, 1, 2, 3]:
		fs.chant_idx.append(i)
	fs._refresh_all()
	await _shot(fs, "04_fight_preview", false, true)
	# after the chant: spells alive, arrow out from Fire Ball toward the middle enemy
	fs.phase = "spells"
	f.chant = ["F", "F", "W", "A"]
	f.spoken = true
	fs.chant_idx.clear()
	f.charges = {"fire_ball": 2, "gust": 1}
	fs._refresh_all()
	await _wait(10)
	var card: SpellCard = fs._cards[0]
	fs.aiming = true
	fs.aim_card = card
	fs.aim_from = fs._card_point(card)
	fs.aim_cands = [0, 1, 2]
	fs.aim_i = 1
	fs._prompt.text = "Fire Ball: choose a target  ·  click, or Tab + Enter  ·  right-click to put it back"
	var mid: EnemyView = fs._views[f.enemies[1]]
	Input.warp_mouse(mid.anchor_point())
	fs._refresh_all()
	await _shot(fs, "05_fight_arrow", false, true)
	# moving an element with Gust
	fs.aiming = false
	fs.aim_card = null
	fs._arrow.queue_redraw()
	var v: EnemyView = fs._views[f.enemies[0]]
	fs.move_view = v
	v.move_mode = true
	v.move_pick = 2
	fs._prompt.text = "Now click where it goes (it takes that spot), or ▸ for the end  ·  click it again to put it down"
	fs._refresh_all()
	await _shot(fs, "05b_fight_move", false, true)
	# Gust: choosing which element to remove
	v.move_mode = false
	fs.move_view = null
	fs.pick_view = v
	v.pick_mode = true
	v.pick_i = 0
	fs._prompt.text = "Gust: choose an element of Stone Knight to remove  ·  click it, or Tab + Enter"
	fs._refresh_all()
	await _shot(fs, "05c_fight_pluck", false, true)
	v.pick_mode = false
	fs.pick_view = null
	fs._refresh_all()
	# the Release: element 1 (Fire) flies as a comet into two enemies
	f.charges = {}
	fs.phase = "spells"
	fs._refresh_all()
	await _wait(4)
	fs._release_step({"pos": 0, "hits": [[f.enemies[0], 0], [f.enemies[1], 0]], "chant": "FFWA"})
	await _wait(14)
	await _shot(fs, "05e_release_comets", false, true)
	await _wait(30)
	# tooltips as they render on hover: a card, an enemy, an intent
	var tips := [[fs._cards[0], Vector2(236, 250)], [fs._views[f.enemies[0]].creature, Vector2(1180, 60)]]
	var chip: Control = fs._views[f.enemies[0]]._intent_slot.get_child(0)
	tips.append([chip, Vector2(40, 90)])
	var shown := []
	for tip in tips:
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", UiTheme.get_theme().get_stylebox("panel", "TooltipPanel"))
		panel.add_child(Keywords.make_tooltip(tip[0].tooltip_text))
		panel.position = tip[1]
		panel.z_index = 100
		fs.add_child(panel)
		shown.append(panel)
	await _shot(fs, "05d_tooltips")
	var w := WikiScreen.new()
	await _shot(w, "09_wiki", true, true)
	w._tabs.current_tab = 2
	await _shot(w, "09b_wiki_spells", false, true)
	w._search.text = "burn"
	w._on_search("burn")
	await _shot(w, "09c_wiki_search")
	var c := CodexScreen.new()
	await _shot(c, "06_codex")
	var ch := ChoiceScreen.new()
	ch.title = "Victory"
	ch.subtitle = "Learn a new spell."
	ch.spells = run.spell_offer(3)
	root.add_child(ch)
	await _wait(6)
	var rc: Array = ch.find_children("*", "SpellCard", true, false)
	_hover(rc[1])
	await _shot(ch, "07_reward", false)
	var ch2 := ChoiceScreen.new()
	ch2.title = "Steal spells"
	ch2.subtitle = "Water spells that take elements for your bag."
	ch2.spells = ["tide_thief", "sirens_call", "maelstrom_grasp"].map(func(id): return gd.db.get_spell(id))
	await _shot(ch2, "07b_steal_spells")
	# a crowded run: 9 active spells
	var big := RunState.new()
	big.setup(gd.db, save.unlocked_spells(), save.unlocked_artifacts(), 5)
	for art in ["broken_crown", "spell_pouch", "spell_satchel"]:
		big.gain_artifact(art)
	for id in ["inferno", "miasma", "kindle", "tide_thief", "sirens_call", "glacier", "whirlpool", "tempest", "firestorm"]:
		big.learn_spell(id)
	big.move_to(big.choices()[0])
	var bl := LoadoutScreen.new()
	bl.setup(big, ["stone_knight", "gale_sprite"])
	await _shot(bl, "10_crowded_loadout")
	var bf := big.make_fight(["stone_knight", "ashling"])
	var bfs := FightScreen.new()
	bfs.setup(big, bf)
	await _shot(bfs, "11_crowded_fight", true, true)
	_hover(bfs._cards[3])
	var pin_tip := PanelContainer.new()
	pin_tip.add_theme_stylebox_override("panel", UiTheme.get_theme().get_stylebox("panel", "TooltipPanel"))
	pin_tip.add_child(Keywords.make_tooltip(bfs._views.values()[0].creature.tooltip_text))
	pin_tip.position = Vector2(1250, 90)
	pin_tip.z_index = 100
	bfs.add_child(pin_tip)
	var art_tip := PanelContainer.new()
	art_tip.add_theme_stylebox_override("panel", UiTheme.get_theme().get_stylebox("panel", "TooltipPanel"))
	art_tip.add_child(Keywords.make_tooltip(ArtifactBar.ArtifactChip.make("broken_crown").tooltip_text))
	art_tip.position = Vector2(40, 110)
	art_tip.z_index = 100
	bfs.add_child(art_tip)
	await _wait(12)
	await _shot(bfs, "11b_crowded_hover")
	var fz := FuseScreen.new()
	fz.setup(run)
	root.add_child(fz)
	await _wait(3)
	fz._toggle("water_wall")
	fz._toggle("inferno")
	await _shot(fz, "12_fuse", false)
	var u := UnlockScreen.new()
	await _shot(u, "08_unlocks")
	print("shots saved to ", ProjectSettings.globalize_path(out))
	tree.quit()


func _wait(n: int) -> void:
	for i in n:
		await tree.process_frame


func _shot(c: Control, name: String, add := true, keep := false) -> void:
	if add:
		root.add_child(c)
	for i in 8:
		await tree.process_frame
	var img := root.get_texture().get_image()
	img.save_png(out + "/" + name + ".png")
	if not keep:
		c.queue_free()
	await tree.process_frame


## Hover a card the way a player does: the mouse really sits on it (the card checks that each frame).
func _hover(card: SpellCard) -> void:
	card.get_viewport().warp_mouse(card.get_global_rect().get_center())
	card._on_hover(true)
